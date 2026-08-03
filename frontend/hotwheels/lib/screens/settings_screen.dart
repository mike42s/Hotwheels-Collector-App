import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Tools'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Database Tools', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.add_box_outlined, color: Colors.green),
                  title: const Text('Generate Dummy Data (50)'),
                  subtitle: const Text('Tambah 50 data acak ke database lokal'),
                  onTap: () async {
                    await ref.read(collectionListProvider.notifier).generateDummyData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('50 Dummy data berhasil ditambahkan'))
                      );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                  title: const Text('Hapus Semua Data Lokal'),
                  subtitle: const Text('Membersihkan seluruh isi database lokal'),
                  onTap: () => _confirmClear(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.orange),
              title: const Text('Logout'),
              subtitle: const Text('Keluar dari sesi akun saat ini'),
              onTap: () => ref.read(authStateProvider.notifier).logout(),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Semua Data?'),
        content: const Text('Tindakan ini akan menghapus SELURUH data lokal Anda. Pastikan sudah sinkron atau backup ke Excel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('YA, HAPUS SEMUA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(collectionListProvider.notifier).clearAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database lokal berhasil dikosongkan'))
        );
      }
    }
  }
}
