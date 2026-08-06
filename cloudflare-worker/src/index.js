/**
 * Cloudflare Worker for R2 Image Storage with Firebase Auth
 *
 * Endpoints:
 *   POST /upload      - Uploads a file to R2 (base64-encoded in JSON body)
 *   POST /view-url    - Generates a presigned S3 download URL
 *
 * Both endpoints require a valid Firebase ID token in the
 * Authorization header: "Bearer <firebase-id-token>"
 *
 * Environment variables:
 *   R2_BUCKET (binding)     - R2 bucket binding set in wrangler.toml
 *   FIREBASE_PROJECT_ID     - Your Firebase project ID
 *   ALLOWED_ORIGINS         - Comma-separated allowed CORS origins (optional)
 */

// ---------------------------------------------------------------------------
// CORS helpers
// ---------------------------------------------------------------------------
const DEFAULT_ALLOWED_ORIGINS = '*';

function corsHeaders(env, methods = 'GET, POST, OPTIONS') {
  const origins = env.ALLOWED_ORIGINS || DEFAULT_ALLOWED_ORIGINS;
  return {
    'Access-Control-Allow-Origin': origins,
    'Access-Control-Allow-Methods': methods,
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  };
}

function corsResponse(body, status, env, extraHeaders = {}) {
  return new Response(body, {
    status,
    headers: { ...corsHeaders(env), 'Content-Type': 'application/json', ...extraHeaders },
  });
}

// ---------------------------------------------------------------------------
// Firebase JWT verification (using JWK endpoint)
// ---------------------------------------------------------------------------
async function verifyFirebaseToken(authHeader, env) {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return { error: 'Missing or malformed Authorization header', status: 401 };
  }

  const token = authHeader.slice(7);
  const projectId = env.FIREBASE_PROJECT_ID;

  try {
    const parts = token.split('.');
    const headerJson = JSON.parse(atob(parts[0]));
    const kid = headerJson.kid;

    const keysRes = await fetch(
      'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'
    );
    const keysData = await keysRes.json();

    const jwkKey = keysData.keys?.find(k => k.kid === kid);
    if (!jwkKey) {
      return { error: 'Invalid signing key', status: 401 };
    }

    const encoder = new TextEncoder();
    const signedData = encoder.encode(parts[0] + '.' + parts[1]);
    const signature = base64UrlToBytes(parts[2]);

    const cryptoKey = await crypto.subtle.importKey(
      'jwk',
      jwkKey,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['verify']
    );

    const valid = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      cryptoKey,
      signature,
      signedData
    );

    if (!valid) {
      return { error: 'Invalid token signature', status: 401 };
    }

    const payload = JSON.parse(atob(parts[1]));

    if (payload.aud !== projectId) {
      return { error: 'Token audience mismatch', status: 401 };
    }
    if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
      return { error: 'Token issuer mismatch', status: 401 };
    }
    if (payload.exp < Math.floor(Date.now() / 1000)) {
      return { error: 'Token expired', status: 401 };
    }

    return { uid: payload.sub, email: payload.email, status: 200 };
  } catch (e) {
    return { error: 'Token verification failed: ' + e.message, status: 401 };
  }
}

function base64UrlToBytes(base64url) {
  const base64 = base64url.replace(/-/g, '+').replace(/_/g, '/');
  const padding = '=='.slice(0, (4 - (base64.length % 4)) % 4);
  const raw = atob(base64 + padding);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) {
    bytes[i] = raw.charCodeAt(i);
  }
  return bytes;
}

function jsonResponse(data, status, env) {
  return corsResponse(JSON.stringify(data), status, env);
}

// ---------------------------------------------------------------------------
// Direct file upload to R2 (no presigned URLs)
// ---------------------------------------------------------------------------
async function handleUpload(request, env) {
  const authHeader = request.headers.get('Authorization');
  const auth = await verifyFirebaseToken(authHeader, env);
  if (auth.error) {
    return jsonResponse({ error: auth.error }, auth.status, env);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, env);
  }

  const { fileName, contentType, data } = body;

  if (!fileName || !data) {
    return jsonResponse({ error: 'fileName and data fields are required' }, 400, env);
  }

  // Validate file extension
  const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
  const ext = fileName.substring(fileName.lastIndexOf('.')).toLowerCase();
  if (!allowedExtensions.includes(ext)) {
    return jsonResponse({ error: `File type ${ext} not allowed` }, 400, env);
  }

  // Decode base64 data
  const binaryStr = atob(data);
  const bytes = new Uint8Array(binaryStr.length);
  for (let i = 0; i < binaryStr.length; i++) {
    bytes[i] = binaryStr.charCodeAt(i);
  }

  // Build object key scoped to the authenticated user
  const key = `users/${auth.uid}/${fileName}`;

  try {
    await env.R2_BUCKET.put(key, bytes, {
      httpMetadata: { contentType: contentType || 'image/jpeg' },
    });
  } catch (e) {
    return jsonResponse({ error: 'R2 upload failed: ' + e.message }, 500, env);
  }

  return jsonResponse({ key: key }, 200, env);
}

// ---------------------------------------------------------------------------
// View URL generation (presigned download)
// ---------------------------------------------------------------------------
async function handleViewUrl(request, env) {
  const authHeader = request.headers.get('Authorization');
  const auth = await verifyFirebaseToken(authHeader, env);
  if (auth.error) {
    return jsonResponse({ error: auth.error }, auth.status, env);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, env);
  }

  const key = body.key;
  if (!key) {
    return jsonResponse({ error: 'key is required' }, 400, env);
  }

  // Verify the key belongs to the requesting user
  if (!key.startsWith(`users/${auth.uid}/`)) {
    return jsonResponse({ error: 'Access denied: key does not belong to this user' }, 403, env);
  }

  // Generate a presigned download URL using R2's built-in support
  // Cloudflare R2 doesn't have a native presigned URL API, so we serve the object directly
  const object = await env.R2_BUCKET.get(key);
  if (!object) {
    return jsonResponse({ error: 'Object not found' }, 404, env);
  }

  // Return the object as a binary response with the correct content type
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('Content-Type', object.httpMetadata?.contentType || 'image/jpeg');
  headers.set('Cache-Control', 'public, max-age=3600');
  // Add CORS headers
  const origins = env.ALLOWED_ORIGINS || DEFAULT_ALLOWED_ORIGINS;
  headers.set('Access-Control-Allow-Origin', origins);

  return new Response(object.body, { headers });
}

// ---------------------------------------------------------------------------
// Delete object
// ---------------------------------------------------------------------------
async function handleDelete(request, env) {
  const authHeader = request.headers.get('Authorization');
  const auth = await verifyFirebaseToken(authHeader, env);
  if (auth.error) {
    return jsonResponse({ error: auth.error }, auth.status, env);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, env);
  }

  const key = body.key;
  if (!key) {
    return jsonResponse({ error: 'key is required' }, 400, env);
  }

  // Verify the key belongs to the requesting user
  if (!key.startsWith(`users/${auth.uid}/`)) {
    return jsonResponse({ error: 'Access denied: key does not belong to this user' }, 403, env);
  }

  try {
    await env.R2_BUCKET.delete(key);
    return jsonResponse({ success: true }, 200, env);
  } catch (e) {
    return jsonResponse({ error: 'R2 delete failed: ' + e.message }, 500, env);
  }
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------
export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(env) });
    }

    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/upload') {
      return handleUpload(request, env);
    }

    if (request.method === 'POST' && url.pathname === '/view-url') {
      return handleViewUrl(request, env);
    }

    if (request.method === 'POST' && url.pathname === '/delete') {
      return handleDelete(request, env);
    }

    return jsonResponse({ error: 'Not found' }, 404, env);
  },
};
