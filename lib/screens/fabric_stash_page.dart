import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/r2_storage_service.dart';
import '../services/theme_controller.dart';
import '../widgets/pattern_app_bar.dart';
import '../main.dart';

/// Model for a fabric entry stored in Firestore.
class FabricEntry {
  final String id;
  final String title;
  final String description;
  final int quantity;
  final String r2Key;
  final DateTime createdAt;

  FabricEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.quantity,
    required this.r2Key,
    required this.createdAt,
  });

  factory FabricEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FabricEntry(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      quantity: data['quantity'] ?? 1,
      r2Key: data['r2Key'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ---------------------------------------------------------------------------
// Standalone image widget — owns its Future so it survives StreamBuilder resets
// ---------------------------------------------------------------------------
class FabricImageWidget extends StatefulWidget {
  final String r2Key;
  final R2StorageService r2Service;
  final Map<String, Future<Uint8List>> imageFutures;
  final Map<String, Uint8List> imageCache;

  const FabricImageWidget({
    super.key,
    required this.r2Key,
    required this.r2Service,
    required this.imageFutures,
    required this.imageCache,
  });

  @override
  State<FabricImageWidget> createState() => _FabricImageWidgetState();
}

class _FabricImageWidgetState extends State<FabricImageWidget> {
  late final Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    final key = widget.r2Key;
    _future = widget.imageFutures.putIfAbsent(key, () => widget.r2Service.getImageBytes(key));
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.r2Key;
    if (widget.imageCache.containsKey(key)) {
      return Image.memory(widget.imageCache[key]!, fit: BoxFit.cover);
    }
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          widget.imageCache[key] = snapshot.data!;
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        if (snapshot.hasError) {
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Text('Unavailable', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Main stash page
// ---------------------------------------------------------------------------
class FabricStashPage extends StatefulWidget {
  const FabricStashPage({super.key});

  @override
  State<FabricStashPage> createState() => _FabricStashPageState();
}

class _FabricStashPageState extends State<FabricStashPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final R2StorageService _r2Service = R2StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  User? _currentUser;
  StreamSubscription<User?>? _authSubscription;

  final Map<String, Future<Uint8List>> _imageFutures = {};
  final Map<String, Uint8List> _imageCache = {};

  Stream<QuerySnapshot>? _fabricsStream;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _updateFabricsStream();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() {
        _currentUser = user;
        _updateFabricsStream();
      });
    });
  }

  void _updateFabricsStream() {
    if (_currentUser == null) {
      _fabricsStream = null;
      return;
    }
    _fabricsStream = _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('fabrics')
        .orderBy('createdAt', descending: true)
        .snapshots();
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
        title: 'My Fabric Stash',
        actions: _currentUser == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add Fabric',
                  onPressed: () => _showAddFabricDialog(),
                ),
              ],
      ),
      body: _currentUser == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Log in to view your stash', style: TextStyle(fontSize: 18)),
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
          : _buildFabricList(),
    );
  }

  Widget _buildFabricList() {
    if (_fabricsStream == null) {
      return const Center(child: Text('Please log in'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _fabricsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          if (snapshot.error.toString().contains('permission-denied')) {
            return _emptyState();
          }
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState();
        }
        final fabrics = snapshot.data!.docs.map((d) => FabricEntry.fromFirestore(d)).toList();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: fabrics.length,
          itemBuilder: (context, index) => _buildFabricCard(fabrics[index]),
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No fabrics in inventory', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Tap the + in the top right to add fabrics', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFabricCard(FabricEntry fabric) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () => _showFabricDetails(fabric),
        onLongPress: () => _confirmDeleteFabric(fabric),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 100, height: 100,
                  child: fabric.r2Key.isNotEmpty
                      ? FabricImageWidget(
                          key: ValueKey(fabric.r2Key),
                          r2Key: fabric.r2Key,
                          r2Service: _r2Service,
                          imageFutures: _imageFutures,
                          imageCache: _imageCache,
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.checkroom, size: 40, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(fabric.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('Qty: ${fabric.quantity}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    if (fabric.description.isNotEmpty)
                      Text(fabric.description,
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showEditFabricDialog(fabric),
                    tooltip: 'Edit',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    onPressed: () => _confirmDeleteFabric(fabric),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, void Function(XFile) onPicked) async {
    final picked = await _imagePicker.pickImage(source: source, imageQuality: 70, maxWidth: 600);
    if (picked != null) onPicked(picked);
  }

  // ─── Add Fabric Dialog ────────────────────────────────────────────────
  Future<void> _showAddFabricDialog() async {
    final titleController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final descriptionController = TextEditingController();
    XFile? pickedImage;

    bool saving = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add New Fabric'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _imagePreviewBox(pickedImage),
                const SizedBox(height: 8),
                _imageSourceRow(setDialogState, (img) => setDialogState(() => pickedImage = img)),
                const SizedBox(height: 16),
                _formField(titleController, 'Title *'),
                const SizedBox(height: 12),
                _formField(quantityController, 'Quantity', keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _formField(descriptionController, 'Description (optional)', maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please enter a title')),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await _uploadAndSaveFabric(titleController.text.trim(),
                            descriptionController.text.trim(),
                            int.tryParse(quantityController.text) ?? 1, pickedImage);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
    if (result == true) setState(() {});
  }

  Widget _imagePreviewBox(XFile? image) {
    return Container(
      height: 150, width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200], borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: image != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(image.path), fit: BoxFit.cover))
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo, size: 40, color: Colors.grey[600]),
                const SizedBox(height: 4),
                Text('No image selected', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
    );
  }

  Widget _imageSourceRow(StateSetter setDialogState, void Function(XFile) onPicked) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.camera, onPicked),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Camera', style: TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.gallery, onPicked),
            icon: const Icon(Icons.photo_library, size: 18),
            label: const Text('Gallery', style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _formField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Future<void> _uploadAndSaveFabric(
      String title, String description, int quantity, XFile? image) async {
    String r2Key = '';
    if (image != null) r2Key = await _r2Service.uploadFile(image.path);
    await _firestore.collection('users').doc(_currentUser!.uid).collection('fabrics').add({
      'title': title, 'description': description, 'quantity': quantity,
      'r2Key': r2Key, 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Edit Fabric Dialog ───────────────────────────────────────────────
  Future<void> _showEditFabricDialog(FabricEntry fabric) async {
    final titleController = TextEditingController(text: fabric.title);
    final quantityController = TextEditingController(text: fabric.quantity.toString());
    final descriptionController = TextEditingController(text: fabric.description);
    XFile? pickedImage;
    bool imageChanged = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Fabric'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 150, width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200], borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: pickedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(pickedImage!.path), fit: BoxFit.cover))
                      : fabric.r2Key.isNotEmpty
                          ? FabricImageWidget(
                              key: ValueKey(fabric.r2Key),
                              r2Key: fabric.r2Key,
                              r2Service: _r2Service,
                              imageFutures: _imageFutures,
                              imageCache: _imageCache,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 40, color: Colors.grey[600]),
                                const SizedBox(height: 4),
                                Text('No image selected',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera, (img) {
                          setDialogState(() { pickedImage = img; imageChanged = true; });
                        }),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Camera', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery, (img) {
                          setDialogState(() { pickedImage = img; imageChanged = true; });
                        }),
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Gallery', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _formField(titleController, 'Title *'),
                const SizedBox(height: 12),
                _formField(quantityController, 'Quantity', keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _formField(descriptionController, 'Description (optional)', maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            TextButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter a title')),
                  );
                  return;
                }
                try {
                  await _updateFabric(fabric, titleController.text.trim(),
                      descriptionController.text.trim(),
                      int.tryParse(quantityController.text) ?? 1, pickedImage);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('UPDATE'),
            ),
          ],
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _updateFabric(
      FabricEntry fabric, String title, String description, int quantity, XFile? newImage) async {
    String r2Key = fabric.r2Key;
    if (newImage != null) {
      r2Key = await _r2Service.uploadFile(newImage.path);
      _imageCache.remove(fabric.r2Key);
    }
    await _firestore.collection('users').doc(_currentUser!.uid)
        .collection('fabrics').doc(fabric.id).update({
      'title': title, 'description': description, 'quantity': quantity, 'r2Key': r2Key,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Detail / Delete ──────────────────────────────────────────────────
  void _showFabricDetails(FabricEntry fabric) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(fabric.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (fabric.r2Key.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _imageCache.containsKey(fabric.r2Key)
                      ? Image.memory(_imageCache[fabric.r2Key]!)
                      : FutureBuilder<Uint8List>(
                          future: _imageFutures.putIfAbsent(
                              fabric.r2Key, () => _r2Service.getImageBytes(fabric.r2Key)),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(height: 200,
                                  child: Center(child: CircularProgressIndicator()));
                            }
                            if (snapshot.hasError || !snapshot.hasData) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(child: Text('Image unavailable')),
                              );
                            }
                            _imageCache[fabric.r2Key] = snapshot.data!;
                            return Image.memory(snapshot.data!);
                          },
                        ),
                ),
              const SizedBox(height: 16),
              _detailRow('Quantity', fabric.quantity.toString()),
              if (fabric.description.isNotEmpty) _detailRow('Description', fabric.description),
              const SizedBox(height: 8),
              Text('Added: ${_formatDate(fabric.createdAt)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            setState(() {});
          }, child: const Text('CLOSE')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value),
      ]),
    );
  }

  Future<void> _confirmDeleteFabric(FabricEntry fabric) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fabric'),
        content: Text('Delete "${fabric.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _firestore.collection('users').doc(_currentUser!.uid)
          .collection('fabrics').doc(fabric.id).delete();
      _imageCache.remove(fabric.r2Key);
      _imageFutures.remove(fabric.r2Key);
      // Best-effort delete from R2 (don't block the UI on failure)
      if (fabric.r2Key.isNotEmpty) {
        try {
          await _r2Service.deleteFile(fabric.r2Key);
        } catch (_) {
          // Image may already be deleted or Worker unavailable — non-critical
        }
      }
      setState(() {});
    }
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';
}