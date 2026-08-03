import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/collection_item.dart';
import '../providers.dart';

class ImportPreviewScreen extends ConsumerWidget {
  final List<CollectionItem> previewItems;

  const ImportPreviewScreen({super.key, required this.previewItems});

  void _handleConfirmImport(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Import'),
        content: Text(
          'Tindakan ini akan MENGHAPUS SEMUA data lokal saat ini dan menggantinya dengan ${previewItems.length} item dari Excel. Lanjutkan?',
        ),
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
          child: Card(
            margin: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Memproses Data...")],
            ),
          ),
        ),
      );

      try {
        await ref.read(collectionListProvider.notifier).clearAll();
        await ref.read(collectionListProvider.notifier).importItems(previewItems);

        if (context.mounted) {
          Navigator.pop(context); // Close loading
          Navigator.pop(context); // Back to Home
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Berhasil mengimpor ${previewItems.length} data baru')));
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Import Excel'),
        actions: [
          TextButton.icon(
            onPressed: () => _handleConfirmImport(context, ref),
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            label: const Text(
              'SUBMIT IMPORT',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withOpacity(0.1),
            child: Text(
              'Menemukan ${previewItems.length} data di file Excel. Silakan periksa sebelum melakukan submit.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: previewItems.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = previewItems[index];
                return ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                    child: item.foto.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.memory(base64Decode(item.foto), fit: BoxFit.cover),
                          )
                        : const Icon(Icons.directions_car, color: Colors.grey),
                  ),
                  title: Text(item.namaKendaraan, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${item.kategoriKendaraan} • ${item.warna1}\n${item.kodeHotwheel}'),
                  isThreeLine: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
