import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../models/collection_item.dart';
import '../providers.dart';
import 'collection_form.dart';

class ImportPreviewScreen extends ConsumerStatefulWidget {
  final List<CollectionItem> previewItems;

  const ImportPreviewScreen({super.key, required this.previewItems});

  @override
  ConsumerState<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends ConsumerState<ImportPreviewScreen> {
  late List<CollectionItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.previewItems);
  }

  void _editItem(int index) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CollectionForm(item: _items[index])),
    );
    // Note: Since this is preview mode, we don't save to DB yet.
    // In a real staging scenario, we might want to update the local _items list.
    // For now, if the user edits and saves, it saves to DB.
    // To make it better, we'll just allow the user to see the list and
    // maybe delete or add photo directly here.
  }

  Future<void> _changePhoto(int index) async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 40,
    );
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;

    final resized = img.copyResize(decoded, width: 250);
    final jpeg = img.encodeJpg(resized, quality: 40);
    final base64String = base64Encode(jpeg);

    setState(() {
      _items[index] = _items[index].copyWith(foto: base64String);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  // WIDGET UNTUK MENAMPILKAN GAMBAR SECARA AMAN (SILENT ERROR)
  Widget _safePreviewImage(String base64String) {
    if (base64String.isEmpty) {
      return const Icon(Icons.directions_car, color: Colors.grey);
    }
    try {
      final cleaned = base64String.trim().replaceAll('\n', '').replaceAll('\r', '');
      // Validasi kelipatan 4 untuk Base64
      String validBase64 = cleaned;
      if (validBase64.length % 4 != 0) {
        validBase64 = validBase64.padRight(validBase64.length + (4 - validBase64.length % 4), '=');
      }
      return Image.memory(
        base64Decode(validBase64),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.orange),
      );
    } catch (e) {
      return const Icon(Icons.broken_image, color: Colors.orange);
    }
  }

  void _handleConfirmImport() async {
    if (_items.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Import'),
        content: Text('Anda akan mengimpor ${_items.length} item. Hapus data lokal lama?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'YA, GANTI SEMUA',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(margin: EdgeInsets.all(24), child: CircularProgressIndicator()),
        ),
      );

      try {
        await ref.read(collectionListProvider.notifier).clearAll();
        await ref.read(collectionListProvider.notifier).importItems(_items);

        if (mounted) {
          Navigator.pop(context); // Close loading
          Navigator.pop(context); // Back to Home
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import Berhasil!')));
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Data Excel'),
        actions: [
          ElevatedButton.icon(
            onPressed: _items.isEmpty ? null : _handleConfirmImport,
            icon: const Icon(Icons.cloud_upload),
            label: const Text('SUBMIT DATA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.orange.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ditemukan ${_items.length} item. Anda bisa mengubah foto atau menghapus baris yang salah sebelum submit.',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () => _changePhoto(index),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _safePreviewImage(item.foto),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                child: const Icon(Icons.add_a_photo, size: 12, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    title: Text(
                      item.namaKendaraan.isEmpty ? '(Tanpa Nama)' : item.namaKendaraan,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${item.kategoriKendaraan} • ${item.warna1}\n${item.kodeHotwheel}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeItem(index),
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
