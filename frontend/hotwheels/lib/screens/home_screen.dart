import 'dart:convert';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../models/collection_item.dart';
import '../providers.dart';
import 'collection_form.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  String _sortBy = 'tgl_pembelian';
  bool _sortAsc = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(collectionListProvider.notifier).loadInitial();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(collectionListProvider.notifier).loadMore();
    }
  }

  void _handleSearch(String value) {
    ref.read(collectionListProvider.notifier).setSearch(value);
  }

  void _handleSort(String field) {
    setState(() {
      if (_sortBy == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortBy = field;
        _sortAsc = true;
      }
    });
    ref.read(collectionListProvider.notifier).setSort(field, _sortAsc);
  }

  Future<void> _exportToExcelWithImages() async {
    try {
      final state = ref.read(collectionListProvider);
      if (state.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data untuk diexport')));
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Menghasilkan Excel dengan Gambar..."),
              ],
            ),
          ),
        ),
      );

      final xlsio.Workbook workbook = xlsio.Workbook();
      final xlsio.Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'HotWheels_Gallery';

      final headers = [
        'ID', 'Nama', 'Tgl Beli', 'Lokasi', 'Harga', 'Penomoran', 
        'Kategori', 'Kode', 'Warna 1', 'Tahun', 'FOTO'
      ];
      
      for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
        sheet.getRangeByIndex(1, i + 1).cellStyle.bold = true;
        sheet.getRangeByIndex(1, i + 1).cellStyle.backColor = '#E3F2FD';
      }

      for (int i = 0; i < state.items.length; i++) {
        final item = state.items[i];
        final row = i + 2;
        
        sheet.getRangeByIndex(row, 1).setText(item.id);
        sheet.getRangeByIndex(row, 2).setText(item.namaKendaraan);
        sheet.getRangeByIndex(row, 3).setText(item.tglPembelian);
        sheet.getRangeByIndex(row, 4).setText(item.lokasiBeli);
        sheet.getRangeByIndex(row, 5).setNumber(item.hargaBeli);
        sheet.getRangeByIndex(row, 6).setText(item.penomoran);
        sheet.getRangeByIndex(row, 7).setText(item.kategoriKendaraan);
        sheet.getRangeByIndex(row, 8).setText(item.kodeHotwheel);
        sheet.getRangeByIndex(row, 9).setText(item.warna1);
        sheet.getRangeByIndex(row, 10).setText(item.tahunKendaraan.toString());

        sheet.setRowHeightInPixels(row, 80);

        if (item.foto.isNotEmpty) {
          try {
            final List<int> imageBytes = base64Decode(item.foto);
            sheet.pictures.addStream(row, 11, imageBytes);
          } catch (e) {
            debugPrint('Error inserting image: $e');
          }
        }
      }

      sheet.setColumnWidthInPixels(11, 100);

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "HotWheels_Gallery_Report.xlsx")
          ..click();
        html.Url.revokeObjectUrl(url);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export Berhasil!')));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export Gagal: $e')));
    }
  }

  Future<void> _importFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
      if (result == null) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      final excel = excel_lib.Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;

      final List<CollectionItem> importedItems = [];
      for (var i = 1; i < sheet.maxRows; i++) {
        final row = sheet.rows[i];
        if (row.length < 2) continue;

        importedItems.add(CollectionItem(
          id: row[0]?.value.toString() ?? '',
          namaKendaraan: row[1]?.value.toString() ?? '',
          tglPembelian: row[2]?.value.toString() ?? '',
          lokasiBeli: row[3]?.value.toString() ?? '',
          hargaBeli: double.tryParse(row[4]?.value.toString() ?? '0') ?? 0.0,
          penomoran: row[5]?.value.toString() ?? '',
          kategoriKendaraan: row[6]?.value.toString() ?? '',
          penomoranKategori: row[7]?.value.toString() ?? '',
          kodeHotwheel: row[8]?.value.toString() ?? '',
          kendaraan: row[9]?.value.toString() ?? 'Mobil',
          tahunKendaraan: int.tryParse(row[10]?.value.toString() ?? '0') ?? 0,
          trackstar: row[11]?.value.toString() == '1',
          specialKategori: row[12]?.value.toString() ?? '',
          netflix: row[13]?.value.toString() == '1',
          hotwheelShowdown: row[14]?.value.toString() == '1',
          warna1: row[15]?.value.toString() ?? '',
          warna2: row[16]?.value.toString(),
          foto: '', 
          isSynced: 0,
        ));
      }
      await ref.read(collectionListProvider.notifier).importItems(importedItems);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil import ${importedItems.length} item')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import Gagal: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionListProvider);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      body: Row(
        children: [
          if (!isMobile) _buildSideNav(),
          Expanded(child: _selectedIndex == 0 ? _buildDashboard(state, size.width, isMobile) : const SettingsScreen()),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _navigateForm(null),
              icon: const Icon(Icons.add),
              label: const Text('Koleksi Baru'),
            )
          : null,
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (i) => setState(() => _selectedIndex = i),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
              ],
            )
          : null,
    );
  }

  Widget _buildDashboard(CollectionListState state, double width, bool isMobile) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        _buildAppBar(isMobile),
        SliverToBoxAdapter(child: _buildReportingSection()),
        SliverToBoxAdapter(child: _buildFilterSection()),
        if (state.isLoading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (state.items.isEmpty)
          const SliverFillRemaining(child: Center(child: Text('Data tidak ditemukan')))
        else
          _buildGrid(state.items, width),
        if (state.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildSideNav() {
    return NavigationRail(
      extended: MediaQuery.of(context).size.width > 900,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      leading: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Icon(Icons.directions_car_filled, color: Theme.of(context).colorScheme.primary, size: 40),
      ),
    );
  }

  Widget _buildAppBar(bool isMobile) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      expandedHeight: 120,
      title: const Text('HW Collector Pro', style: TextStyle(fontWeight: FontWeight.bold)),
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 8),
          child: SearchBar(
            controller: _searchController,
            hintText: 'Cari nama, kategori, atau warna...',
            onChanged: _handleSearch,
            leading: const Icon(Icons.search),
          ),
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.file_download_outlined), tooltip: 'Export Excel (dengan Gambar)', onPressed: _exportToExcelWithImages),
        IconButton(icon: const Icon(Icons.file_upload_outlined), tooltip: 'Import', onPressed: _importFromExcel),
        IconButton(
          icon: _isSyncing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync),
          onPressed: () async {
            setState(() => _isSyncing = true);
            await ref.read(collectionListProvider.notifier).syncData();
            setState(() => _isSyncing = false);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync Berhasil')));
          },
        ),
      ],
    );
  }

  Widget _buildReportingSection() {
    final state = ref.watch(collectionListProvider);
    final synced = state.items.where((i) => i.isSynced == 1).length;
    final local = state.items.where((i) => i.isSynced == 0).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildStatCard('Total Data', '${state.totalCount}', Icons.inventory_2, Colors.blue),
          _buildStatCard('Online Sync', '$synced', Icons.cloud_done, Colors.green),
          _buildStatCard('Local Only', '$local', Icons.cloud_off, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          Text(
            val,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Urutkan:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          FilterChip(
            label: Text('Tanggal ${_sortBy == 'tgl_pembelian' ? (_sortAsc ? '↑' : '↓') : ''}'),
            selected: _sortBy == 'tgl_pembelian',
            onSelected: (_) => _handleSort('tgl_pembelian'),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('Nama ${_sortBy == 'nama_kendaraan' ? (_sortAsc ? '↑' : '↓') : ''}'),
            selected: _sortBy == 'nama_kendaraan',
            onSelected: (_) => _handleSort('nama_kendaraan'),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<CollectionItem> items, double width) {
    int crossAxisCount = (width / 220).floor().clamp(2, 6);
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildGridItem(items[index]),
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildGridItem(CollectionItem item) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateForm(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: item.foto.isNotEmpty
                    ? Image.memory(base64Decode(item.foto), fit: BoxFit.cover)
                    : const Icon(Icons.directions_car, size: 50, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.namaKendaraan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(item.kategoriKendaraan, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.warna1, style: const TextStyle(fontSize: 11)),
                      Icon(
                        item.isSynced == 1 ? Icons.cloud_done : Icons.cloud_off,
                        size: 14,
                        color: item.isSynced == 1 ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateForm(CollectionItem? item) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionForm(item: item)));
    if (result == true) ref.read(collectionListProvider.notifier).loadInitial();
  }
}
