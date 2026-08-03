import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../database_helper.dart';
import '../models/collection_item.dart';
import '../providers.dart';

class CollectionForm extends ConsumerStatefulWidget {
  final CollectionItem? item;
  const CollectionForm({super.key, this.item});

  @override
  ConsumerState<CollectionForm> createState() => _CollectionFormState();
}

class _CollectionFormState extends ConsumerState<CollectionForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tglPembelianController;
  late TextEditingController _lokasiBeliController;
  late TextEditingController _hargaBeliController;
  late TextEditingController _namaKendaraanController;
  late TextEditingController _penomoranController;
  late TextEditingController _kategoriKendaraanController;
  late TextEditingController _penomoranKategoriController;
  late TextEditingController _kodeHotwheelController;
  late TextEditingController _tahunKendaraanController;
  late TextEditingController _specialKategoriController;
  late TextEditingController _warna1Controller;
  late TextEditingController _warna2Controller;

  late String _kendaraan;
  late bool _trackstar;
  late bool _netflix;
  late bool _hotwheelShowdown;
  late String _fotoBase64;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _tglPembelianController = TextEditingController(text: item?.tglPembelian ?? '');
    _lokasiBeliController = TextEditingController(text: item?.lokasiBeli ?? '');
    _hargaBeliController = TextEditingController(text: item?.hargaBeli.toString() ?? '');
    _namaKendaraanController = TextEditingController(text: item?.namaKendaraan ?? '');
    _penomoranController = TextEditingController(text: item?.penomoran ?? '');
    _kategoriKendaraanController = TextEditingController(text: item?.kategoriKendaraan ?? '');
    _penomoranKategoriController = TextEditingController(text: item?.penomoranKategori ?? '');
    _kodeHotwheelController = TextEditingController(text: item?.kodeHotwheel ?? '');
    _tahunKendaraanController = TextEditingController(text: item?.tahunKendaraan.toString() ?? '');
    _specialKategoriController = TextEditingController(text: item?.specialKategori ?? '');
    _warna1Controller = TextEditingController(text: item?.warna1 ?? '');
    _warna2Controller = TextEditingController(text: item?.warna2 ?? '');

    _kendaraan = item?.kendaraan ?? 'Mobil';
    _trackstar = item?.trackstar ?? false;
    _netflix = item?.netflix ?? false;
    _hotwheelShowdown = item?.hotwheelShowdown ?? false;
    _fotoBase64 = item?.foto ?? '';
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source, maxWidth: 600, maxHeight: 600, imageQuality: 50);
    if (pickedFile == null) return;
    final bytes = await pickedFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    final resized = img.copyResize(decoded, width: 400);
    final jpeg = img.encodeJpg(resized, quality: 50);
    setState(() => _fotoBase64 = base64Encode(jpeg));
  }

  void _randomizeFields() {
    final r = Random();
    final names = ['Bone Shaker', 'Twin Mill', 'Deora II', 'Muscle Tone', 'Rodger Dodger', 'Rip Rod', 'Night Shifter'];
    final locations = ['Alfamart', 'Indomaret', 'Toys Kingdom', 'Kidz Station', 'Online Shop'];
    final categories = ['Mainline', 'Premium', 'Treasure Hunt', 'Super Treasure Hunt'];
    final colors = ['Red', 'Blue', 'Green', 'Black', 'White', 'Yellow', 'Silver', 'Gold'];

    setState(() {
      _tglPembelianController.text = '2024-${(r.nextInt(12)+1).toString().padLeft(2, '0')}-${(r.nextInt(28)+1).toString().padLeft(2, '0')}';
      _lokasiBeliController.text = locations[r.nextInt(locations.length)];
      _hargaBeliController.text = ((r.nextInt(100) + 30) * 1000).toString();
      _namaKendaraanController.text = names[r.nextInt(names.length)];
      _penomoranController.text = '${r.nextInt(250)}/250';
      _kategoriKendaraanController.text = categories[r.nextInt(categories.length)];
      _penomoranKategoriController.text = '${r.nextInt(10)}/10';
      _kodeHotwheelController.text = 'HKX${r.nextInt(999)}';
      _kendaraan = r.nextBool() ? 'Mobil' : 'Motor';
      _tahunKendaraanController.text = (2020 + r.nextInt(5)).toString();
      _trackstar = r.nextBool();
      _specialKategoriController.text = r.nextBool() ? 'HW Turbo' : '';
      _netflix = r.nextBool();
      _hotwheelShowdown = r.nextBool();
      _warna1Controller.text = colors[r.nextInt(colors.length)];
      _warna2Controller.text = r.nextBool() ? colors[r.nextInt(colors.length)] : '';
    });
  }

  Future<void> _deleteData() async {
    if (widget.item == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Item?'),
        content: Text('Apakah Anda yakin ingin menghapus "${widget.item!.namaKendaraan}" dari koleksi lokal?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Hapus', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _saving = true);
      try {
        await ref.read(collectionListProvider.notifier).deleteItem(widget.item!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item berhasil dihapus')));
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final item = CollectionItem(
        id: widget.item?.id ?? const Uuid().v4(),
        tglPembelian: _tglPembelianController.text,
        lokasiBeli: _lokasiBeliController.text,
        hargaBeli: double.tryParse(_hargaBeliController.text) ?? 0.0,
        namaKendaraan: _namaKendaraanController.text,
        penomoran: _penomoranController.text,
        kategoriKendaraan: _kategoriKendaraanController.text,
        penomoranKategori: _penomoranKategoriController.text,
        kodeHotwheel: _kodeHotwheelController.text,
        kendaraan: _kendaraan,
        tahunKendaraan: int.tryParse(_tahunKendaraanController.text) ?? 0,
        trackstar: _trackstar,
        specialKategori: _specialKategoriController.text,
        netflix: _netflix,
        hotwheelShowdown: _hotwheelShowdown,
        warna1: _warna1Controller.text,
        warna2: _warna2Controller.text,
        foto: _fotoBase64,
        isSynced: 0,
      );
      if (widget.item == null) { await DatabaseHelper.instance.insertItem(item); }
      else { await DatabaseHelper.instance.updateItem(item); }
      if (mounted) Navigator.pop(context, true);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'))); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final isEdit = widget.item != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Koleksi' : 'Tambah Koleksi'),
        actions: [
          if (isEdit) 
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
              tooltip: 'Hapus Data',
              onPressed: _deleteData
            ),
          IconButton(icon: const Icon(Icons.shuffle), tooltip: 'Isi Data Acak', onPressed: _randomizeFields)
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => _pickImage(ImageSource.gallery),
                  child: Container(
                    width: 250, height: 250,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: _fotoBase64.isNotEmpty
                        ? ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.memory(base64Decode(_fotoBase64), fit: BoxFit.cover))
                        : const Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (isDesktop) 
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildFields1()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildFields2()),
                  ],
                )
              else ...[
                _buildFields1(),
                _buildFields2(),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving ? const CircularProgressIndicator() : const Text('SIMPAN DATA', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFields1() {
    return Column(
      children: [
        _inputField(_namaKendaraanController, 'Nama Kendaraan', Icons.drive_file_rename_outline, required: true),
        _inputField(_tglPembelianController, 'Tanggal Beli (YYYY-MM-DD)', Icons.calendar_today, readOnly: true, onTap: () async {
          final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100));
          if (d != null) setState(() => _tglPembelianController.text = d.toIso8601String().split('T').first);
        }),
        _inputField(_hargaBeliController, 'Harga Beli', Icons.money, keyboardType: TextInputType.number),
        _inputField(_lokasiBeliController, 'Lokasi Beli', Icons.location_on_outlined),
        _inputField(_kategoriKendaraanController, 'Kategori', Icons.category_outlined),
        _inputField(_penomoranKategoriController, 'Penomoran Kategori', Icons.tag),
      ],
    );
  }

  Widget _buildFields2() {
    return Column(
      children: [
        _inputField(_warna1Controller, 'Warna 1', Icons.color_lens_outlined, required: true),
        _inputField(_warna2Controller, 'Warna 2', Icons.color_lens),
        _inputField(_tahunKendaraanController, 'Tahun', Icons.date_range, keyboardType: TextInputType.number),
        _inputField(_kodeHotwheelController, 'Kode Hotwheel', Icons.qr_code_2),
        _inputField(_penomoranController, 'Penomoran', Icons.numbers),
        _inputField(_specialKategoriController, 'Special Kategori', Icons.stars_outlined),
        _buildSwitches(),
      ],
    );
  }

  Widget _buildSwitches() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          SwitchListTile(title: const Text('Trackstar'), value: _trackstar, onChanged: (v) => setState(() => _trackstar = v)),
          SwitchListTile(title: const Text('Netflix'), value: _netflix, onChanged: (v) => setState(() => _netflix = v)),
          SwitchListTile(title: const Text('Hot Wheels Showdown'), value: _hotwheelShowdown, onChanged: (v) => setState(() => _hotwheelShowdown = v)),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String label, IconData icon, {bool required = false, bool readOnly = false, VoidCallback? onTap, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        validator: required ? (v) => v == null || v.isEmpty ? 'Wajib diisi' : null : null,
      ),
    );
  }
}
