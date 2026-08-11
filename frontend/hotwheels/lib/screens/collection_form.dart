import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../database_helper.dart';
import '../models/collection_item.dart';
import '../providers.dart';

class CollectionForm extends ConsumerStatefulWidget {
  final CollectionItem? item;
  final bool isStaging;

  const CollectionForm({super.key, this.item, this.isStaging = false});

  @override
  ConsumerState<CollectionForm> createState() => _CollectionFormState();
}

class _CollectionFormState extends ConsumerState<CollectionForm> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _tglPembelianController;
  late TextEditingController _lokasiBeliController;
  late TextEditingController _hargaBeliController;
  late TextEditingController _namaKendaraanController;
  late TextEditingController _penomoran1Controller;
  late TextEditingController _penomoran2Controller;
  late TextEditingController _kategoriKendaraanController;
  late TextEditingController _penomoranKategori1Controller;
  late TextEditingController _penomoranKategori2Controller;
  late TextEditingController _kodeHotwheelController;
  late TextEditingController _tahunKendaraanController;
  late TextEditingController _specialKategoriController;
  late TextEditingController _warna1Controller;
  late TextEditingController _warna2Controller;
  late TextEditingController _warna3Controller;
  late TextEditingController _jenisKendaraanController;

  final FocusNode _warna1Focus = FocusNode();
  final FocusNode _warna2Focus = FocusNode();
  final FocusNode _warna3Focus = FocusNode();
  final FocusNode _kategoriFocus = FocusNode();
  final FocusNode _jenisFocus = FocusNode();
  final FocusNode _specialFocus = FocusNode();
  final FocusNode _lokasiFocus = FocusNode();

  late String _kendaraan;
  late bool _trackstar;
  late bool _netflix;
  late bool _hotwheelShowdown;
  late String _fotoBase64;
  late String _originalFotoBase64;
  bool _saving = false;

  final NumberFormat _currencyFormat = NumberFormat.decimalPattern('id_ID');

  @override
  void initState() {
    super.initState();
    final item = widget.item;

    _tglPembelianController = TextEditingController(
      text: item?.tglPembelian ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _lokasiBeliController = TextEditingController(text: item?.lokasiBeli ?? '-');

    double initialHarga = item?.hargaBeli ?? 20000.0;
    _hargaBeliController = TextEditingController(text: _currencyFormat.format(initialHarga.toInt()));

    _namaKendaraanController = TextEditingController(text: item?.namaKendaraan ?? '');
    _penomoran1Controller = TextEditingController(text: item?.penomoran1 ?? '');
    _penomoran2Controller = TextEditingController(text: item?.penomoran2 ?? '');
    _kategoriKendaraanController = TextEditingController(text: item?.kategoriKendaraan ?? '');
    _penomoranKategori1Controller = TextEditingController(text: item?.penomoranKategori1 ?? '');
    _penomoranKategori2Controller = TextEditingController(text: item?.penomoranKategori2 ?? '');
    _kodeHotwheelController = TextEditingController(text: item?.kodeHotwheel ?? '');
    _tahunKendaraanController = TextEditingController(
      text: (item?.tahunKendaraan == 0 || item?.tahunKendaraan == null) ? '' : item!.tahunKendaraan.toString(),
    );
    _specialKategoriController = TextEditingController(text: item?.specialKategori ?? '');
    _warna1Controller = TextEditingController(text: item?.warna1 ?? '');
    _warna2Controller = TextEditingController(text: item?.warna2 ?? '');
    _warna3Controller = TextEditingController(text: item?.warna3 ?? '');
    _jenisKendaraanController = TextEditingController(text: item?.jenisKendaraan ?? '');

    _kendaraan = item?.kendaraan ?? 'Mobil';
    _trackstar = item?.trackstar ?? false;
    _netflix = item?.netflix ?? false;
    _hotwheelShowdown = item?.hotwheelShowdown ?? false;
    _fotoBase64 = item?.foto ?? '';
    _originalFotoBase64 = _fotoBase64;
  }

  @override
  void dispose() {
    _tglPembelianController.dispose();
    _lokasiBeliController.dispose();
    _hargaBeliController.dispose();
    _namaKendaraanController.dispose();
    _penomoran1Controller.dispose();
    _penomoran2Controller.dispose();
    _kategoriKendaraanController.dispose();
    _penomoranKategori1Controller.dispose();
    _penomoranKategori2Controller.dispose();
    _kodeHotwheelController.dispose();
    _tahunKendaraanController.dispose();
    _specialKategoriController.dispose();
    _warna1Controller.dispose();
    _warna2Controller.dispose();
    _warna3Controller.dispose();
    _jenisKendaraanController.dispose();
    _warna1Focus.dispose();
    _warna2Focus.dispose();
    _warna3Focus.dispose();
    _kategoriFocus.dispose();
    _jenisFocus.dispose();
    _specialFocus.dispose();
    _lokasiFocus.dispose();
    super.dispose();
  }

  Future<void> _showImagePickerSource() async {
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
    if (source != null) _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: source, maxWidth: 400, maxHeight: 400, imageQuality: 40);
      if (pickedFile == null) return;
      final bytes = await pickedFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      final resized = img.copyResize(decoded, width: 250);
      final jpeg = img.encodeJpg(resized, quality: 40);
      setState(() => _fotoBase64 = base64Encode(jpeg));
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showZoomImage() {
    if (_fotoBase64.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(base64Decode(_fotoBase64), fit: BoxFit.contain),
                ),
                IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: Icon(Icons.close, color: Colors.white),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _randomizeFields() {
    final r = Random();
    final names = ['BONE SHAKER', 'TWIN MILL', 'DEORA II', 'MUSCLE TONE', 'RODGER DODGER', 'RIP ROD', 'NIGHT SHIFTER'];
    final locations = ['ALFAMART', 'INDOMARET', 'TOYS KINGDOM', 'KIDZ STATION', 'ONLINE SHOP'];
    final categories = ['MAINLINE', 'PREMIUM', 'TREASURE HUNT', 'SUPER TREASURE HUNT'];
    final colors = ['RED', 'BLUE', 'GREEN', 'BLACK', 'WHITE', 'YELLOW', 'SILVER', 'GOLD'];
    final types = ['CITY CAR', 'OFF-ROAD', 'SPORTS', 'FANTASY', 'TRUCK'];

    setState(() {
      _tglPembelianController.text =
          '2024-${(r.nextInt(12) + 1).toString().padLeft(2, '0')}-${(r.nextInt(28) + 1).toString().padLeft(2, '0')}';
      _lokasiBeliController.text = locations[r.nextInt(locations.length)];
      double randHarga = (r.nextInt(100) + 30) * 1000.0;
      _hargaBeliController.text = _currencyFormat.format(randHarga.toInt());
      _namaKendaraanController.text = names[r.nextInt(names.length)];
      _penomoran1Controller.text = r.nextInt(250).toString();
      _penomoran2Controller.text = '250';
      _kategoriKendaraanController.text = categories[r.nextInt(categories.length)];
      _penomoranKategori1Controller.text = (r.nextInt(10) + 1).toString();
      _penomoranKategori2Controller.text = '10';
      _kodeHotwheelController.text = 'HKX${r.nextInt(999)}';
      _kendaraan = r.nextBool() ? 'Mobil' : 'Motor';
      _jenisKendaraanController.text = types[r.nextInt(types.length)];
      _tahunKendaraanController.text = (2020 + r.nextInt(5)).toString();
      _trackstar = r.nextBool();
      _specialKategoriController.text = r.nextBool() ? 'HW TURBO' : '';
      _netflix = r.nextBool();
      _hotwheelShowdown = r.nextBool();
      _warna1Controller.text = colors[r.nextInt(colors.length)];
      _warna2Controller.text = r.nextBool() ? colors[r.nextInt(colors.length)] : '';
      _warna3Controller.text = r.nextBool() ? colors[r.nextInt(colors.length)] : '';
    });
  }

  Future<void> _deleteData() async {
    debugPrint('CollectionForm: Triggered _deleteData');
    if (widget.item == null) {
      debugPrint('CollectionForm: Item is null, cannot delete.');
      return;
    }

    if (widget.isStaging) {
      debugPrint('CollectionForm: Staging mode, popping "DELETED"');
      Navigator.pop(context, "DELETED");
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('HAPUS DATA?'),
        content: Text('Anda yakin ingin menghapus "${widget.item!.namaKendaraan}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('BATAL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'HAPUS',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      debugPrint('CollectionForm: User confirmed delete for ID: ${widget.item!.id}');
      setState(() => _saving = true);
      try {
        // Panggil notifier untuk proses delete (lokal + server)
        await ref.read(collectionListProvider.notifier).deleteItem(widget.item!.id);
        debugPrint('CollectionForm: deleteItem execution finished successfully.');
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        debugPrint('CollectionForm: ERROR during deleteItem: $e');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    } else {
      debugPrint('CollectionForm: Delete cancelled by user.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lengkapi field wajib bertanda *')));
      return;
    }
    setState(() => _saving = true);
    double parsedHarga = 20000.0;
    try {
      String cleanVal = _hargaBeliController.text.replaceAll('.', '').replaceAll(',', '');
      parsedHarga = double.parse(cleanVal);
    } catch (_) {}

    final nowStr = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());

    try {
      final item = CollectionItem(
        id: widget.item?.id ?? const Uuid().v4(),
        tglPembelian: _tglPembelianController.text,
        lokasiBeli: _lokasiBeliController.text.toUpperCase(),
        hargaBeli: parsedHarga,
        namaKendaraan: _namaKendaraanController.text.toUpperCase(),
        penomoran1: _penomoran1Controller.text,
        penomoran2: _penomoran2Controller.text,
        kategoriKendaraan: _kategoriKendaraanController.text.toUpperCase(),
        penomoranKategori1: _penomoranKategori1Controller.text,
        penomoranKategori2: _penomoranKategori2Controller.text,
        kodeHotwheel: _kodeHotwheelController.text.toUpperCase(),
        kendaraan: _kendaraan,
        jenisKendaraan: _jenisKendaraanController.text.toUpperCase(),
        tahunKendaraan: int.tryParse(_tahunKendaraanController.text) ?? 0,
        trackstar: _trackstar,
        specialKategori: _specialKategoriController.text.toUpperCase(),
        netflix: _netflix,
        hotwheelShowdown: _hotwheelShowdown,
        warna1: _warna1Controller.text.toUpperCase(),
        warna2: _warna2Controller.text.isEmpty ? null : _warna2Controller.text.toUpperCase(),
        warna3: _warna3Controller.text.isEmpty ? null : _warna3Controller.text.toUpperCase(),
        foto: _fotoBase64,
        isSynced: 0,
        createdAt: widget.item?.createdAt ?? nowStr,
        updatedAt: nowStr,
        photoUpdatedAt: _fotoBase64 != _originalFotoBase64 ? nowStr : (widget.item?.photoUpdatedAt ?? ''),
      );

      if (widget.isStaging) {
        if (mounted) Navigator.pop(context, item);
        return;
      }
      if (widget.item == null) {
        await DatabaseHelper.instance.insertItem(item);
      } else {
        await DatabaseHelper.instance.updateItem(item);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final isEdit = widget.item != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'EDIT KOLEKSI' : 'TAMBAH KOLEKSI'),
        actions: [
          // TOMBOL HAPUS DI ATAS (Jika Edit)
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Hapus Koleksi',
              onPressed: _deleteData,
            ),
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save, color: Colors.white),
            tooltip: 'Simpan',
          ),
          IconButton(icon: const Icon(Icons.shuffle), onPressed: _randomizeFields),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildPhotoPicker(),
              const SizedBox(height: 24),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildLeftFields()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildRightFields()),
                  ],
                )
              else ...[
                _buildLeftFields(),
                _buildRightFields(),
              ],
              const SizedBox(height: 32),
              _buildTimestampInfo(),
              const SizedBox(height: 16),

              // TOMBOL SIMPAN BAWAH
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('SIMPAN DATA', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              // TOMBOL HAPUS BAWAH (Jika Edit)
              if (isEdit) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _deleteData,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('HAPUS KOLEKSI PERMANEN'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimestampInfo() {
    if (widget.item == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoText('Dibuat pada', widget.item!.createdAt),
          _infoText('Update terakhir', widget.item!.updatedAt),
          if (widget.item!.photoUpdatedAt.isNotEmpty) _infoText('Foto diupload', widget.item!.photoUpdatedAt),
        ],
      ),
    );
  }

  Widget _infoText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          GestureDetector(
            onTap: _showZoomImage,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
              ),
              child: _fotoBase64.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.memory(base64Decode(_fotoBase64), fit: BoxFit.cover),
                    )
                  : const Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FloatingActionButton.small(onPressed: _showImagePickerSource, child: const Icon(Icons.camera_alt)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftFields() {
    return Column(
      children: [
        _inputField(_namaKendaraanController, 'NAMA KENDARAAN *', Icons.drive_file_rename_outline, required: true),
        _inputField(
          _tglPembelianController,
          'TANGGAL BELI (YYYY-MM-DD)',
          Icons.calendar_today,
          readOnly: true,
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (d != null) setState(() => _tglPembelianController.text = d.toIso8601String().split('T').first);
          },
        ),
        _currencyField(_hargaBeliController, 'HARGA BELI', Icons.money),
        _suggestionField(_lokasiBeliController, _lokasiFocus, 'LOKASI BELI', 'lokasi_beli', Icons.location_on_outlined),
        _suggestionField(
          _kategoriKendaraanController,
          _kategoriFocus,
          'KATEGORI *',
          'kategori_kendaraan',
          Icons.category_outlined,
          required: true,
        ),
        _suggestionField(_jenisKendaraanController, _jenisFocus, 'JENIS KENDARAAN', 'jenis_kendaraan', Icons.commute),
        _buildDoubleInput('PENOMORAN', _penomoran1Controller, _penomoran2Controller, Icons.numbers, isNumeric: true),
      ],
    );
  }

  Widget _buildRightFields() {
    return Column(
      children: [
        _fixedColorField(_warna1Controller, _warna1Focus, 'WARNA 1 *', Icons.color_lens_outlined, required: true),
        _fixedColorField(_warna2Controller, _warna2Focus, 'WARNA 2', Icons.color_lens),
        _fixedColorField(_warna3Controller, _warna3Focus, 'WARNA 3', Icons.color_lens),
        _inputField(
          _tahunKendaraanController,
          'TAHUN',
          Icons.date_range,
          keyboardType: TextInputType.number,
          isNumeric: true,
        ),
        _inputField(_kodeHotwheelController, 'KODE HOTWHEEL *', Icons.qr_code_2, required: true),
        _suggestionField(
          _specialKategoriController,
          _specialFocus,
          'SPECIAL KATEGORI',
          'special_kategori',
          Icons.stars_outlined,
        ),
        _buildDoubleInput(
          'PENOMORAN KATEGORI *',
          _penomoranKategori1Controller,
          _penomoranKategori2Controller,
          Icons.tag,
          required: true,
          isNumeric: true,
        ),
        _buildSwitches(),
      ],
    );
  }

  Widget _buildDoubleInput(
    String label,
    TextEditingController c1,
    TextEditingController c2,
    IconData icon, {
    bool required = false,
    bool isNumeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: _inputField(c1, label, icon, required: required, isNumeric: isNumeric),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Text('/', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 1,
            child: _inputField(c2, 'Total', null, required: required, isNumeric: isNumeric),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitches() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('TRACKSTAR'),
            value: _trackstar,
            onChanged: (v) => setState(() => _trackstar = v),
          ),
          SwitchListTile(title: const Text('NETFLIX'), value: _netflix, onChanged: (v) => setState(() => _netflix = v)),
          SwitchListTile(
            title: const Text('SHOWDOWN'),
            value: _hotwheelShowdown,
            onChanged: (v) => setState(() => _hotwheelShowdown = v),
          ),
        ],
      ),
    );
  }

  Widget _inputField(
    TextEditingController controller,
    String label,
    IconData? icon, {
    bool required = false,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    bool isNumeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: isNumeric ? TextInputType.number : keyboardType,
        inputFormatters: [if (isNumeric) FilteringTextInputFormatter.digitsOnly, UpperCaseTextFormatter()],
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        validator: required ? (v) => v == null || v.isEmpty ? 'Wajib diisi' : null : null,
      ),
    );
  }

  Widget _currencyField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          prefixText: 'Rp ',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _fixedColorField(
    TextEditingController controller,
    FocusNode focusNode,
    String label,
    IconData icon, {
    bool required = false,
  }) {
    final List<String> masterColors = [
      'RED',
      'BLUE',
      'GREEN',
      'BLACK',
      'WHITE',
      'YELLOW',
      'SILVER',
      'GOLD',
      'ORANGE',
      'PURPLE',
      'PINK',
      'BROWN',
      'GREY',
      'CYAN',
      'MAGENTA',
      'LIME',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) => RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: focusNode,
          optionsBuilder: (TextEditingValue textEditingValue) {
            return masterColors.where((String option) => option.contains(textEditingValue.text.toUpperCase()));
          },
          fieldViewBuilder: (context, controller, node, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: node,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: required ? (v) => v == null || v.isEmpty ? 'Wajib diisi' : null : null,
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(title: Text(option), onTap: () => onSelected(option));
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _suggestionField(
    TextEditingController controller,
    FocusNode focusNode,
    String label,
    String column,
    IconData icon, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) => RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: focusNode,
          optionsBuilder: (TextEditingValue textEditingValue) async {
            final suggestions = await ref.read(collectionListProvider.notifier).getSuggestions(column);
            if (textEditingValue.text.isEmpty) return suggestions;
            return suggestions.where(
              (String option) => option.toUpperCase().contains(textEditingValue.text.toUpperCase()),
            );
          },
          fieldViewBuilder: (context, controller, node, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: node,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: required ? (v) => v == null || v.isEmpty ? 'Wajib diisi' : null : null,
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(title: Text(option), onTap: () => onSelected(option));
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    try {
      double value = double.parse(newValue.text.replaceAll('.', '').replaceAll(',', ''));
      final formatter = NumberFormat.decimalPattern('id_ID');
      String newText = formatter.format(value.toInt());
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    } catch (e) {
      return oldValue;
    }
  }
}
