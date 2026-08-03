class CollectionItem {
  final String id;
  final String tglPembelian;
  final String lokasiBeli;
  final double hargaBeli;
  final String namaKendaraan;
  final String penomoran;
  final String kategoriKendaraan;
  final String penomoranKategori;
  final String kodeHotwheel;
  final String kendaraan;
  final int tahunKendaraan;
  final bool trackstar;
  final String specialKategori;
  final bool netflix;
  final bool hotwheelShowdown;
  final String warna1;
  final String? warna2;
  final String foto;
  final int isSynced;

  CollectionItem({
    required this.id,
    required this.tglPembelian,
    required this.lokasiBeli,
    required this.hargaBeli,
    required this.namaKendaraan,
    required this.penomoran,
    required this.kategoriKendaraan,
    required this.penomoranKategori,
    required this.kodeHotwheel,
    required this.kendaraan,
    required this.tahunKendaraan,
    required this.trackstar,
    required this.specialKategori,
    required this.netflix,
    required this.hotwheelShowdown,
    required this.warna1,
    this.warna2,
    required this.foto,
    this.isSynced = 0,
  });

  factory CollectionItem.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is bool) return value ? 1 : 0;
      return int.tryParse(value.toString()) ?? 0;
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    return CollectionItem(
      id: map['id']?.toString() ?? '',
      tglPembelian: map['tgl_pembelian']?.toString() ?? '',
      lokasiBeli: map['lokasi_beli']?.toString() ?? '',
      hargaBeli: parseDouble(map['harga_beli']),
      namaKendaraan: map['nama_kendaraan']?.toString() ?? '',
      penomoran: map['penomoran']?.toString() ?? '',
      kategoriKendaraan: map['kategori_kendaraan']?.toString() ?? '',
      penomoranKategori: map['penomoran_kategori']?.toString() ?? '',
      kodeHotwheel: map['kode_hotwheel']?.toString() ?? '',
      kendaraan: map['kendaraan']?.toString() ?? '',
      tahunKendaraan: parseInt(map['tahun_kendaraan']),
      trackstar: parseInt(map['trackstar']) == 1,
      specialKategori: map['special_kategori']?.toString() ?? '',
      netflix: parseInt(map['netflix']) == 1,
      hotwheelShowdown: parseInt(map['hotwheel_showdown']) == 1,
      warna1: map['warna_1']?.toString() ?? '',
      warna2: map['warna_2']?.toString(),
      foto: map['foto']?.toString() ?? '',
      isSynced: parseInt(map['is_synced']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tgl_pembelian': tglPembelian,
      'lokasi_beli': lokasiBeli,
      'harga_beli': hargaBeli,
      'nama_kendaraan': namaKendaraan,
      'penomoran': penomoran,
      'kategori_kendaraan': kategoriKendaraan,
      'penomoran_kategori': penomoranKategori,
      'kode_hotwheel': kodeHotwheel,
      'kendaraan': kendaraan,
      'tahun_kendaraan': tahunKendaraan,
      'trackstar': trackstar ? 1 : 0,
      'special_kategori': specialKategori,
      'netflix': netflix ? 1 : 0,
      'hotwheel_showdown': hotwheelShowdown ? 1 : 0,
      'warna_1': warna1,
      'warna_2': warna2,
      'foto': foto,
      'is_synced': isSynced,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tgl_pembelian': tglPembelian,
      'lokasi_beli': lokasiBeli,
      'harga_beli': hargaBeli,
      'nama_kendaraan': namaKendaraan,
      'penomoran': penomoran,
      'kategori_kendaraan': kategoriKendaraan,
      'penomoran_kategori': penomoranKategori,
      'kode_hotwheel': kodeHotwheel,
      'kendaraan': kendaraan,
      'tahun_kendaraan': tahunKendaraan,
      'trackstar': trackstar ? 1 : 0,
      'special_kategori': specialKategori,
      'netflix': netflix ? 1 : 0,
      'hotwheel_showdown': hotwheelShowdown ? 1 : 0,
      'warna_1': warna1,
      'warna_2': warna2,
      'foto': foto,
    };
  }

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem.fromMap(json);
  }

  CollectionItem copyWith({
    String? id,
    String? tglPembelian,
    String? lokasiBeli,
    double? hargaBeli,
    String? namaKendaraan,
    String? penomoran,
    String? kategoriKendaraan,
    String? penomoranKategori,
    String? kodeHotwheel,
    String? kendaraan,
    int? tahunKendaraan,
    bool? trackstar,
    String? specialKategori,
    bool? netflix,
    bool? hotwheelShowdown,
    String? warna1,
    String? warna2,
    String? foto,
    int? isSynced,
  }) {
    return CollectionItem(
      id: id ?? this.id,
      tglPembelian: tglPembelian ?? this.tglPembelian,
      lokasiBeli: lokasiBeli ?? this.lokasiBeli,
      hargaBeli: hargaBeli ?? this.hargaBeli,
      namaKendaraan: namaKendaraan ?? this.namaKendaraan,
      penomoran: penomoran ?? this.penomoran,
      kategoriKendaraan: kategoriKendaraan ?? this.kategoriKendaraan,
      penomoranKategori: penomoranKategori ?? this.penomoranKategori,
      kodeHotwheel: kodeHotwheel ?? this.kodeHotwheel,
      kendaraan: kendaraan ?? this.kendaraan,
      tahunKendaraan: tahunKendaraan ?? this.tahunKendaraan,
      trackstar: trackstar ?? this.trackstar,
      specialKategori: specialKategori ?? this.specialKategori,
      netflix: netflix ?? this.netflix,
      hotwheelShowdown: hotwheelShowdown ?? this.hotwheelShowdown,
      warna1: warna1 ?? this.warna1,
      warna2: warna2 ?? this.warna2,
      foto: foto ?? this.foto,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
