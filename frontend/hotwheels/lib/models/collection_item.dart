class CollectionItem {
  final String id;
  final String tglPembelian;
  final String lokasiBeli;
  final double hargaBeli;
  final String namaKendaraan;
  final String penomoran1;
  final String penomoran2;
  final String kategoriKendaraan;
  final String penomoranKategori1;
  final String penomoranKategori2;
  final String kodeHotwheel;
  final String kendaraan;
  final String jenisKendaraan;
  final int tahunKendaraan;
  final bool trackstar;
  final String specialKategori;
  final bool netflix;
  final bool hotwheelShowdown;
  final String warna1;
  final String? warna2;
  final String? warna3;
  final String foto;
  final int isSynced;
  final String updatedAt;
  final String createdAt; // NEW FIELD
  final String photoUpdatedAt; // NEW FIELD

  CollectionItem({
    required this.id,
    required this.tglPembelian,
    required this.lokasiBeli,
    required this.hargaBeli,
    required this.namaKendaraan,
    required this.penomoran1,
    required this.penomoran2,
    required this.kategoriKendaraan,
    required this.penomoranKategori1,
    required this.penomoranKategori2,
    required this.kodeHotwheel,
    required this.kendaraan,
    required this.jenisKendaraan,
    required this.tahunKendaraan,
    required this.trackstar,
    required this.specialKategori,
    required this.netflix,
    required this.hotwheelShowdown,
    required this.warna1,
    this.warna2,
    this.warna3,
    required this.foto,
    this.isSynced = 0,
    this.updatedAt = '',
    this.createdAt = '',
    this.photoUpdatedAt = '',
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

    String getPenomoran1(Map<String, dynamic> m) {
      if (m.containsKey('penomoran_1')) return m['penomoran_1']?.toString() ?? '';
      if (m.containsKey('penomoran')) {
        String p = m['penomoran']?.toString() ?? '';
        if (p.contains('/')) return p.split('/').first.trim();
        return p;
      }
      return '';
    }

    String getPenomoran2(Map<String, dynamic> m) {
      if (m.containsKey('penomoran_2')) return m['penomoran_2']?.toString() ?? '';
      if (m.containsKey('penomoran')) {
        String p = m['penomoran']?.toString() ?? '';
        if (p.contains('/')) return p.split('/').last.trim();
      }
      return '';
    }

    String getPenomoranKategori1(Map<String, dynamic> m) {
      if (m.containsKey('penomoran_kategori_1')) return m['penomoran_kategori_1']?.toString() ?? '';
      if (m.containsKey('penomoran_kategori')) {
        String p = m['penomoran_kategori']?.toString() ?? '';
        if (p.contains('/')) return p.split('/').first.trim();
        return p;
      }
      return '';
    }

    String getPenomoranKategori2(Map<String, dynamic> m) {
      if (m.containsKey('penomoran_kategori_2')) return m['penomoran_kategori_2']?.toString() ?? '';
      if (m.containsKey('penomoran_kategori')) {
        String p = m['penomoran_kategori']?.toString() ?? '';
        if (p.contains('/')) return p.split('/').last.trim();
      }
      return '';
    }

    return CollectionItem(
      id: map['id']?.toString() ?? '',
      tglPembelian: map['tgl_pembelian']?.toString() ?? '',
      lokasiBeli: map['lokasi_beli']?.toString() ?? '',
      hargaBeli: parseDouble(map['harga_beli']),
      namaKendaraan: map['nama_kendaraan']?.toString() ?? '',
      penomoran1: getPenomoran1(map),
      penomoran2: getPenomoran2(map),
      kategoriKendaraan: map['kategori_kendaraan']?.toString() ?? '',
      penomoranKategori1: getPenomoranKategori1(map),
      penomoranKategori2: getPenomoranKategori2(map),
      kodeHotwheel: map['kode_hotwheel']?.toString() ?? '',
      kendaraan: map['kendaraan']?.toString() ?? 'Mobil',
      jenisKendaraan: map['jenis_kendaraan']?.toString() ?? '',
      tahunKendaraan: parseInt(map['tahun_kendaraan']),
      trackstar: parseInt(map['trackstar']) == 1,
      specialKategori: map['special_kategori']?.toString() ?? '',
      netflix: parseInt(map['netflix']) == 1,
      hotwheelShowdown: parseInt(map['hotwheel_showdown']) == 1,
      warna1: map['warna_1']?.toString() ?? '',
      warna2: map['warna_2']?.toString(),
      warna3: map['warna_3']?.toString(),
      foto: map['foto']?.toString() ?? '',
      isSynced: parseInt(map['is_synced']),
      updatedAt: map['updated_at']?.toString() ?? '',
      createdAt: map['created_at']?.toString() ?? '',
      photoUpdatedAt: map['photo_updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tgl_pembelian': tglPembelian,
      'lokasi_beli': lokasiBeli,
      'harga_beli': hargaBeli,
      'nama_kendaraan': namaKendaraan,
      'penomoran_1': penomoran1,
      'penomoran_2': penomoran2,
      'kategori_kendaraan': kategoriKendaraan,
      'penomoran_kategori_1': penomoranKategori1,
      'penomoran_kategori_2': penomoranKategori2,
      'kode_hotwheel': kodeHotwheel,
      'kendaraan': kendaraan,
      'jenis_kendaraan': jenisKendaraan,
      'tahun_kendaraan': tahunKendaraan,
      'trackstar': trackstar ? 1 : 0,
      'special_kategori': specialKategori,
      'netflix': netflix ? 1 : 0,
      'hotwheel_showdown': hotwheelShowdown ? 1 : 0,
      'warna_1': warna1,
      'warna_2': warna2,
      'warna_3': warna3,
      'foto': foto,
      'is_synced': isSynced,
      'updated_at': updatedAt,
      'created_at': createdAt,
      'photo_updated_at': photoUpdatedAt,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tgl_pembelian': tglPembelian,
      'lokasi_beli': lokasiBeli,
      'harga_beli': hargaBeli,
      'nama_kendaraan': namaKendaraan,
      'penomoran_1': penomoran1,
      'penomoran_2': penomoran2,
      'kategori_kendaraan': kategoriKendaraan,
      'penomoran_kategori_1': penomoranKategori1,
      'penomoran_kategori_2': penomoranKategori2,
      'kode_hotwheel': kodeHotwheel,
      'kendaraan': kendaraan,
      'jenis_kendaraan': jenisKendaraan,
      'tahun_kendaraan': tahunKendaraan,
      'trackstar': trackstar ? 1 : 0,
      'special_kategori': specialKategori,
      'netflix': netflix ? 1 : 0,
      'hotwheel_showdown': hotwheelShowdown ? 1 : 0,
      'warna_1': warna1,
      'warna_2': warna2,
      'warna_3': warna3,
      'foto': foto,
      'updated_at': updatedAt,
      'created_at': createdAt,
      'photo_updated_at': photoUpdatedAt,
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
    String? penomoran1,
    String? penomoran2,
    String? kategoriKendaraan,
    String? penomoranKategori1,
    String? penomoranKategori2,
    String? kodeHotwheel,
    String? kendaraan,
    String? jenisKendaraan,
    int? tahunKendaraan,
    bool? trackstar,
    String? specialKategori,
    bool? netflix,
    bool? hotwheelShowdown,
    String? warna1,
    String? warna2,
    String? warna3,
    String? foto,
    int? isSynced,
    String? updatedAt,
    String? createdAt,
    String? photoUpdatedAt,
  }) {
    return CollectionItem(
      id: id ?? this.id,
      tglPembelian: tglPembelian ?? this.tglPembelian,
      lokasiBeli: lokasiBeli ?? this.lokasiBeli,
      hargaBeli: hargaBeli ?? this.hargaBeli,
      namaKendaraan: namaKendaraan ?? this.namaKendaraan,
      penomoran1: penomoran1 ?? this.penomoran1,
      penomoran2: penomoran2 ?? this.penomoran2,
      kategoriKendaraan: kategoriKendaraan ?? this.kategoriKendaraan,
      penomoranKategori1: penomoranKategori1 ?? this.penomoranKategori1,
      penomoranKategori2: penomoranKategori2 ?? this.penomoranKategori2,
      kodeHotwheel: kodeHotwheel ?? this.kodeHotwheel,
      kendaraan: kendaraan ?? this.kendaraan,
      jenisKendaraan: jenisKendaraan ?? this.jenisKendaraan,
      tahunKendaraan: tahunKendaraan ?? this.tahunKendaraan,
      trackstar: trackstar ?? this.trackstar,
      specialKategori: specialKategori ?? this.specialKategori,
      netflix: netflix ?? this.netflix,
      hotwheelShowdown: hotwheelShowdown ?? this.hotwheelShowdown,
      warna1: warna1 ?? this.warna1,
      warna2: warna2 ?? this.warna2,
      warna3: warna3 ?? this.warna3,
      foto: foto ?? this.foto,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      photoUpdatedAt: photoUpdatedAt ?? this.photoUpdatedAt,
    );
  }
}
