import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../models/collection_item.dart';
import '../providers.dart';
import 'collection_form.dart';
import 'settings_screen.dart';
import 'import_preview_screen.dart';

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

  Widget _safeImage(String base64String, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (base64String.isEmpty) {
      return Icon(Icons.directions_car, size: width != null ? width * 0.5 : 50, color: Colors.grey);
    }
    try {
      final cleanedString = base64String.trim().replaceAll('\n', '').replaceAll('\r', '');
      String validBase64 = cleanedString;
      if (validBase64.length % 4 != 0) {
        validBase64 = validBase64.padRight(validBase64.length + (4 - validBase64.length % 4), '=');
      }
      return Image.memory(
        base64Decode(validBase64),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red),
      );
    } catch (e) {
      return const Icon(Icons.broken_image, color: Colors.red);
    }
  }

  Future<void> _quickAddPhoto(CollectionItem item) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await ImagePicker().pickImage(source: source, maxWidth: 400, maxHeight: 400, imageQuality: 40);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    final resized = img.copyResize(decoded, width: 250);
    final jpeg = img.encodeJpg(resized, quality: 40);
    final base64String = base64Encode(jpeg);

    final updatedItem = item.copyWith(
      foto: base64String,
      isSynced: 0,
      photoUpdatedAt: DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()),
    );
    await ref.read(databaseHelperProvider).updateItem(updatedItem);
    ref.read(collectionListProvider.notifier).loadInitial();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto berhasil ditambahkan!')));
    }
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
            margin: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Menghasilkan Excel Pro...")],
            ),
          ),
        ),
      );

      final xlsio.Workbook workbook = xlsio.Workbook();
      final xlsio.Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'HotWheels_Gallery';

      // TOTAL HEADERS: 25 (0 to 24)
      final headers = [
        'ID',
        'Nama',
        'Tgl Beli',
        'Lokasi',
        'Harga',
        'Penomoran 1',
        'Penomoran 2',
        'Kategori',
        'Penomoran Kat 1',
        'Penomoran Kat 2',
        'Kode',
        'Kendaraan',
        'Jenis Kendaraan',
        'Tahun',
        'Trackstar',
        'Special',
        'Netflix',
        'Showdown',
        'Warna 1',
        'Warna 2',
        'Warna 3',
        'CreatedAt',
        'UpdatedAt',
        'PhotoUpdatedAt',
        'FotoBase64',
      ];

      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.getRangeByIndex(1, i + 1);
        cell.setText(headers[i]);
        cell.cellStyle.bold = true;
        cell.cellStyle.backColor = '#1E88E5';
        cell.cellStyle.fontColor = '#FFFFFF';
        cell.cellStyle.vAlign = xlsio.VAlignType.center;
        cell.cellStyle.hAlign = xlsio.HAlignType.center;
      }

      for (int i = 0; i < state.items.length; i++) {
        final item = state.items[i];
        final row = i + 2;
        sheet.setRowHeightInPixels(row, 100);

        sheet.getRangeByIndex(row, 1).setText(item.id);
        sheet.getRangeByIndex(row, 2).setText(item.namaKendaraan);
        sheet.getRangeByIndex(row, 3).setText(item.tglPembelian);
        sheet.getRangeByIndex(row, 4).setText(item.lokasiBeli);
        sheet.getRangeByIndex(row, 5).setNumber(item.hargaBeli);
        sheet.getRangeByIndex(row, 6).setText(item.penomoran1);
        sheet.getRangeByIndex(row, 7).setText(item.penomoran2);
        sheet.getRangeByIndex(row, 8).setText(item.kategoriKendaraan);
        sheet.getRangeByIndex(row, 9).setText(item.penomoranKategori1);
        sheet.getRangeByIndex(row, 10).setText(item.penomoranKategori2);
        sheet.getRangeByIndex(row, 11).setText(item.kodeHotwheel);
        sheet.getRangeByIndex(row, 12).setText(item.kendaraan);
        sheet.getRangeByIndex(row, 13).setText(item.jenisKendaraan);
        sheet.getRangeByIndex(row, 14).setText(item.tahunKendaraan.toString());
        sheet.getRangeByIndex(row, 15).setText(item.trackstar ? '1' : '0');
        sheet.getRangeByIndex(row, 16).setText(item.specialKategori);
        sheet.getRangeByIndex(row, 17).setText(item.netflix ? '1' : '0');
        sheet.getRangeByIndex(row, 18).setText(item.hotwheelShowdown ? '1' : '0');
        sheet.getRangeByIndex(row, 19).setText(item.warna1);
        sheet.getRangeByIndex(row, 20).setText(item.warna2 ?? '');
        sheet.getRangeByIndex(row, 21).setText(item.warna3 ?? '');
        sheet.getRangeByIndex(row, 22).setText(item.createdAt);
        sheet.getRangeByIndex(row, 23).setText(item.updatedAt);
        sheet.getRangeByIndex(row, 24).setText(item.photoUpdatedAt);

        // FotoBase64 di kolom ke-25 (Index 24)
        String photoData = item.foto;
        if (photoData.length > 32700) photoData = photoData.substring(0, 32700);
        sheet.getRangeByIndex(row, 25).setText(photoData);

        if (item.foto.isNotEmpty) {
          try {
            final List<int> imageBytes = base64Decode(item.foto);
            final xlsio.Picture picture = sheet.pictures.addStream(row, 25, imageBytes);
            picture.lastRow = row;
            picture.lastColumn = 25;
            picture.height = 95;
            picture.width = 95;
          } catch (_) {}
        }
      }

      sheet.setColumnWidthInPixels(25, 110);
      sheet.getRangeByName('A1:X1').autoFitColumns();
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "HW_Gallery_Pro_Export.xlsx")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // MOBILE EXPORT LOGIC
        if (Platform.isAndroid) {
          await Permission.storage.request();
          await Permission.photos.request();
        }
        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) directory = await getExternalStorageDirectory();
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory == null) throw Exception("Direktori tidak ditemukan");

        final String fileName = "HW_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx";
        final String path = "${directory.path}/$fileName";
        final File file = File(path);
        await file.writeAsBytes(bytes, flush: true);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File disimpan di: $fileName'),
              action: SnackBarAction(label: 'BUKA', onPressed: () => OpenFilex.open(path)),
              duration: const Duration(seconds: 10),
            ),
          );
        }
        return;
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export Gagal: $e')));
    }
  }

  Future<void> _importFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) return;
      final excel = excel_lib.Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;
      final List<CollectionItem> importedItems = [];

      for (var i = 1; i < sheet.maxRows; i++) {
        final row = sheet.rows[i];
        if (row.length < 2) continue;

        // HELPER FUNGSI UNTUK AMBIL DATA SESUAI INDEX (0-24)
        String getVal(int index) => row.length > index ? (row[index]?.value?.toString() ?? '') : '';

        importedItems.add(
          CollectionItem(
            id: getVal(0),
            namaKendaraan: getVal(1),
            tglPembelian: getVal(2),
            lokasiBeli: getVal(3),
            hargaBeli: double.tryParse(getVal(4)) ?? 0.0,
            penomoran1: getVal(5),
            penomoran2: getVal(6),
            kategoriKendaraan: getVal(7),
            penomoranKategori1: getVal(8),
            penomoranKategori2: getVal(9),
            kodeHotwheel: getVal(10),
            kendaraan: getVal(11).isEmpty ? 'Mobil' : getVal(11),
            jenisKendaraan: getVal(12),
            tahunKendaraan: int.tryParse(getVal(13)) ?? 0,
            trackstar: getVal(14) == '1',
            specialKategori: getVal(15),
            netflix: getVal(16) == '1',
            hotwheelShowdown: getVal(17) == '1',
            warna1: getVal(18),
            warna2: getVal(19),
            warna3: getVal(20),
            createdAt: getVal(21),
            updatedAt: getVal(22),
            photoUpdatedAt: getVal(23),
            foto: getVal(24), // FOTO SEKARANG DI INDEX 24 (Kolom 25)
            isSynced: 0,
          ),
        );
      }
      if (mounted)
        Navigator.push(context, MaterialPageRoute(builder: (_) => ImportPreviewScreen(previewItems: importedItems)));
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
      pinned: true,
      floating: true,
      expandedHeight: 120,
      title: const Text("HW Collector Pro"),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SearchBar(
            controller: _searchController,
            hintText: 'Cari nama, kategori, atau warna...',
            onChanged: _handleSearch,
            leading: const Icon(Icons.search),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: 'Export',
          onPressed: _exportToExcelWithImages,
        ),
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: _safeImage(item.foto)),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue.withOpacity(0.8),
                      child: IconButton(
                        icon: const Icon(Icons.add_a_photo, size: 16, color: Colors.white),
                        onPressed: () => _quickAddPhoto(item),
                      ),
                    ),
                  ),
                ],
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
