import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Service class for interacting with the Cloudflare R2 storage layer
/// via the Cloudflare Worker API.
///
/// The Worker verifies Firebase Auth tokens and handles direct R2 operations.
/// Uploads send base64-encoded files to the Worker, which stores them in R2.
/// Views retrieve binary image data through the Worker.
class R2StorageService {
  static const String _workerBaseUrl = 'https://craft-stash-r2-worker.craft-stash.workers.dev';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  /// Generates a unique filename for the given extension.
  String generateFileName(String extension) {
    return '${_uuid.v4()}$extension';
  }

  /// Gets the current user's Firebase ID token (required for Worker auth).
  Future<String> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final token = await user.getIdToken();
    if (token == null) {
      throw Exception('Failed to get ID token');
    }
    return token;
  }

  /// Uploads a file to R2 via the Cloudflare Worker (native platforms only).
  ///
  /// [filePath] is the local path to the file to upload.
  /// Returns the R2 object key that can be used to retrieve the file later.
  Future<String> uploadFile(String filePath) async {
    final file = File(filePath);
    final extension = filePath.substring(filePath.lastIndexOf('.'));
    final fileName = generateFileName(extension);
    final contentType = _contentTypeForExtension(extension);

    // Read file bytes and base64-encode
    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);

    // Send to Worker
    final token = await _getIdToken();
    final response = await http.post(
      Uri.parse('$_workerBaseUrl/upload'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'fileName': fileName,
        'contentType': contentType,
        'data': base64Data,
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Upload failed with status ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['key'] as String;
  }

  /// Uploads raw image bytes to R2 (cross-platform, including web).
  ///
  /// [bytes] are the image bytes, [extension] includes the dot (e.g., ".jpg").
  /// Returns the R2 object key.
  Future<String> uploadImageBytes(Uint8List bytes, String extension) async {
    final fileName = generateFileName(extension);
    final contentType = _contentTypeForExtension(extension);
    final base64Data = base64Encode(bytes);

    final token = await _getIdToken();
    final response = await http.post(
      Uri.parse('$_workerBaseUrl/upload'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'fileName': fileName,
        'contentType': contentType,
        'data': base64Data,
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Upload failed with status ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['key'] as String;
  }

  /// Retrieves image bytes for the given R2 key.
  /// Returns the raw image bytes that can be rendered with Image.memory.
  Future<Uint8List> getImageBytes(String key) async {
    final token = await _getIdToken();
    final response = await http.post(
      Uri.parse('$_workerBaseUrl/view-url'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'key': key}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to get image');
    }

    // Response body is the binary image data
    return response.bodyBytes;
  }

  /// Deletes a file from R2 via the Cloudflare Worker.
  Future<void> deleteFile(String key) async {
    final token = await _getIdToken();
    final response = await http.post(
      Uri.parse('$_workerBaseUrl/delete'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'key': key}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Delete failed with status ${response.statusCode}');
    }
  }

  /// Maps file extensions to MIME types.
  String _contentTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }
}