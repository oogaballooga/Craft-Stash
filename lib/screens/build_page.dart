import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/r2_storage_service.dart';
import '../widgets/pattern_app_bar.dart';
import '../main.dart';

class CanvasItem {
  final String instanceId;
  final String firestoreId;
  final String r2Key;
  final String title;
  Offset position;
  double rotation;
  double scale;

  CanvasItem({
    required this.instanceId,
    required this.firestoreId,
    required this.r2Key,
    required this.title,
    this.position = const Offset(20, 20),
    this.rotation = 0.0,
    this.scale = 1.0,
  });
}

class BuildPage extends StatefulWidget {
  const BuildPage({super.key});
  @override
  State<BuildPage> createState() => _BuildPageState();
}

class _BuildPageState extends State<BuildPage> {
  final R2StorageService _r2Service = R2StorageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  StreamSubscription<User?>? _authSubscription;

  final List<CanvasItem> _canvasItems = [];
  final Map<String, Uint8List> _imageCache = {};
  int _idCounter = 0;

  String? _selectedId;
  String? _draggingId;
  Offset? _dragStart;
  Offset? _itemStartPos;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() => _currentUser = user);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PatternAppBar(
        title: 'Build',
        actions: _currentUser == null
            ? null
            : [
                IconButton(icon: const Icon(Icons.add), tooltip: 'Add fabric', onPressed: _openFabricPicker),
                if (_canvasItems.isNotEmpty)
                  IconButton(icon: const Icon(Icons.clear_all), tooltip: 'Clear canvas', onPressed: () => setState(() { _canvasItems.clear(); _selectedId = null; })),
              ],
      ),
      body: _currentUser == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Log in to start building', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Main.switchToProfile(),
                    icon: const Icon(Icons.login),
                    label: const Text('Log In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 69, 148, 214),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                  ),
                ],
              ),
            )
          : _canvasItems.isEmpty
              ? _emptyCanvas()
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selectedId = null),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ..._canvasItems.map(_buildItem),
                      if (_selectedItem != null) _buildSelectedOverlay(_selectedItem!),
                    ],
                  ),
                ),
    );
  }

  Widget _emptyCanvas() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.dashboard_customize_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Build canvas is empty', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text(
            'Tap the + in the top right to add fabrics to the canvas',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  CanvasItem? get _selectedItem {
    final id = _selectedId;
    if (id == null) return null;
    try { return _canvasItems.firstWhere((i) => i.instanceId == id); } catch (_) { return null; }
  }

  // ─── Item widget (touchable area scales with scale) ──────────────────
  Widget _buildItem(CanvasItem item) {
    final sel = _selectedId == item.instanceId;
    const base = 150.0;
    final scaled = base * item.scale;

    // Offset so the image always scales from its centre, preventing shift.
    final centerDx = item.position.dx + base / 2;
    final centerDy = item.position.dy + base / 2;

    return Positioned(
      left: centerDx - scaled / 2,
      top: centerDy - scaled / 2,
      child: GestureDetector(
        onTap: () => setState(() => _selectedId = item.instanceId),
        onLongPress: () => _showOptions(item),
        onPanStart: sel
            ? (d) => setState(() { _draggingId = item.instanceId; _dragStart = d.globalPosition;
                                     _itemStartPos = Offset(centerDx, centerDy); })
            : null,
        onPanUpdate: sel && _draggingId == item.instanceId
            ? (d) { if (_dragStart != null) setState(() {
                     final newCenter = _itemStartPos! + (d.globalPosition - _dragStart!);
                     item.position = newCenter - Offset(base / 2, base / 2);
                   }); }
            : null,
        onPanEnd: sel && _draggingId == item.instanceId ? (_) => setState(() => _draggingId = null) : null,
        child: Transform.rotate(
          angle: item.rotation,
          child: Container(
            width: scaled, height: scaled,
            decoration: BoxDecoration(
              border: Border.all(color: sel ? Colors.blue.withOpacity(0.5) : Colors.transparent, width: sel ? 2 : 0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: _imageCache.containsKey(item.r2Key)
                  ? Image.memory(_imageCache[item.r2Key]!, fit: BoxFit.cover)
                  : FutureBuilder<Uint8List>(
                      future: _r2Service.getImageBytes(item.r2Key),
                      builder: (_, s) {
                        if (s.hasData) { _imageCache[item.r2Key] = s.data!; return Image.memory(s.data!, fit: BoxFit.cover); }
                        if (s.hasError) return Container(color: Colors.grey[300], child: const Center(child: Icon(Icons.broken_image, size: 32, color: Colors.grey)));
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      }),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Overlay bar (bigger buttons, comfortable spacing) ─────────────────
  Widget _buildSelectedOverlay(CanvasItem item) {
    const base = 150.0;
    const barH = 50.0;
    const gap = 8.0;
    const barW = 340.0;

    final centerX = item.position.dx + base / 2;
    final centerY = item.position.dy + base / 2;

    final barX = centerX - barW / 2;
    final scaledTop = centerY - (base * item.scale) / 2;
    final barY = scaledTop - barH - gap;

    return Positioned(
      left: barX,
      top: barY,
      child: SizedBox(width: barW, height: barH, child: _controlBar(item)),
    );
  }

  Widget _controlBar(CanvasItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueAccent, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Rotate drag‑handle — GestureDetector wraps the decorated box
          GestureDetector(
            onHorizontalDragUpdate: (d) => setState(() => item.rotation += d.delta.dx * (pi / 150)),
            child: Container(
              height: 34,
              width: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rotate_right, size: 16, color: Colors.blueAccent),
                  SizedBox(width: 4),
                  Text('Rotate', style: TextStyle(fontSize: 11, color: Colors.blueAccent)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _btn(Icons.remove, () => setState(() => item.scale = (item.scale - 0.1).clamp(0.3, 3.0))),
          const SizedBox(width: 8),
          _btn(Icons.add,    () => setState(() => item.scale = (item.scale + 0.1).clamp(0.3, 3.0))),
          const SizedBox(width: 10),
          _btn(Icons.close,  () => setState(() { _canvasItems.remove(item); _selectedId = null; }), isDestructive: true),
          const SizedBox(width: 10),
          // Title block
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fabric:', style: TextStyle(fontSize: 8, color: Colors.grey)),
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: isDestructive ? Colors.red : Colors.grey[700], shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  void _showOptions(CanvasItem item) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.rotate_right), title: const Text('Rotate 45°'), onTap: () { setState(() => item.rotation += 0.7854); Navigator.pop(ctx); }),
      ListTile(leading: const Icon(Icons.undo), title: const Text('Reset rotation'), onTap: () { setState(() => item.rotation = 0); Navigator.pop(ctx); }),
      ListTile(leading: const Icon(Icons.zoom_in), title: const Text('Scale up'), onTap: () { setState(() => item.scale = (item.scale + 0.2).clamp(0.3, 3.0)); Navigator.pop(ctx); }),
      ListTile(leading: const Icon(Icons.zoom_out), title: const Text('Scale down'), onTap: () { setState(() => item.scale = (item.scale - 0.2).clamp(0.3, 3.0)); Navigator.pop(ctx); }),
      ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Remove', style: TextStyle(color: Colors.red)), onTap: () { setState(() { _canvasItems.remove(item); _selectedId = null; }); Navigator.pop(ctx); }),
    ])));
  }

  void _openFabricPicker() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
        builder: (ctx, sc) {
          if (_currentUser == null) return const Center(child: Text('Not logged in'));
          return StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').doc(_currentUser!.uid).collection('fabrics').orderBy('createdAt', descending: true).snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snap.hasError || !snap.hasData || snap.data!.docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey), const SizedBox(height: 8),
                Text(snap.hasError ? 'Error loading fabrics' : 'No fabrics in your stash', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4), const Text('Add fabrics in the Stash tab first', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ]));
              return ListView.builder(
                controller: sc, padding: const EdgeInsets.all(12), itemCount: snap.data!.docs.length,
                itemBuilder: (_, i) {
                  final d = snap.data!.docs[i].data() as Map<String, dynamic>;
                  final r2Key = (d['r2Key'] as String?) ?? '';
                  final title = (d['title'] as String?) ?? 'Untitled';
                  return ListTile(
                    leading: r2Key.isNotEmpty ? SizedBox(width: 60, height: 60, child: ClipRRect(borderRadius: BorderRadius.circular(6),
                        child: _imageCache.containsKey(r2Key) ? Image.memory(_imageCache[r2Key]!, fit: BoxFit.cover)
                            : FutureBuilder<Uint8List>(future: _r2Service.getImageBytes(r2Key), builder: (_, s) { if (s.hasData) { _imageCache[r2Key] = s.data!; return Image.memory(s.data!, fit: BoxFit.cover); } return const Center(child: CircularProgressIndicator(strokeWidth: 2)); }))) : Container(width: 60, height: 60, color: Colors.grey[300], child: const Icon(Icons.checkroom, size: 24)),
                    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () { Navigator.pop(ctx); _add(r2Key, title); },
                  );
                });
            });
        },
      ),
    );
  }

  void _add(String r2Key, String title) {
    if (r2Key.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This fabric has no image'))); return; }
    final id = 'item_${_idCounter++}';
    setState(() => _canvasItems.add(CanvasItem(instanceId: id, firestoreId: id, r2Key: r2Key, title: title, position: Offset(30 + (_canvasItems.length % 4) * 40, 30 + (_canvasItems.length ~/ 4) * 190))));
  }
}