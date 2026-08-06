import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'models/collection_item.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    DatabaseFactory factory;
    String path;

    if (kIsWeb) {
      factory = databaseFactoryFfiWeb;
      path = 'hotwheels_collection_web.db';
    } else {
      factory = databaseFactory;
      final databasesPath = await getDatabasesPath();
      path = join(databasesPath, 'hotwheels_collection.db');
    }

    try {
      return await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3, // Increment version for new columns
          onCreate: (db, version) async {
            await _onCreate(db, version);
            await _createDeletedTable(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await _createDeletedTable(db);
            }
            if (oldVersion < 3) {
              // Migration to version 3
              await db.execute('ALTER TABLE collection ADD warna_3 TEXT');
              await db.execute('ALTER TABLE collection ADD penomoran_1 TEXT');
              await db.execute('ALTER TABLE collection ADD penomoran_2 TEXT');
              await db.execute('ALTER TABLE collection ADD penomoran_kategori_1 TEXT');
              await db.execute('ALTER TABLE collection ADD penomoran_kategori_2 TEXT');
              await db.execute('ALTER TABLE collection ADD jenis_kendaraan TEXT');
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('Error initializing database: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE collection (
        id TEXT PRIMARY KEY,
        tgl_pembelian TEXT,
        lokasi_beli TEXT,
        harga_beli REAL,
        nama_kendaraan TEXT,
        penomoran_1 TEXT,
        penomoran_2 TEXT,
        kategori_kendaraan TEXT,
        penomoran_kategori_1 TEXT,
        penomoran_kategori_2 TEXT,
        kode_hotwheel TEXT,
        kendaraan TEXT,
        jenis_kendaraan TEXT,
        tahun_kendaraan INTEGER,
        trackstar INTEGER,
        special_kategori TEXT,
        netflix INTEGER,
        hotwheel_showdown INTEGER,
        warna_1 TEXT NOT NULL,
        warna_2 TEXT,
        warna_3 TEXT,
        foto TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _createDeletedTable(Database db) async {
    await db.execute('''
      CREATE TABLE deleted_items (
        id TEXT PRIMARY KEY
      )
    ''');
  }

  Future<int> insertItem(CollectionItem item) async {
    final db = await database;
    return await db.insert('collection', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CollectionItem>> getPagedItems(int limit, int offset, {String search = '', String sortBy = 'tgl_pembelian', bool asc = false}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    
    if (search.isNotEmpty) {
      where = 'nama_kendaraan LIKE ? OR kategori_kendaraan LIKE ? OR warna_1 LIKE ? OR jenis_kendaraan LIKE ?';
      whereArgs = ['%$search%', '%$search%', '%$search%', '%$search%'];
    }

    final rows = await db.query(
      'collection',
      where: where,
      whereArgs: whereArgs,
      orderBy: '$sortBy ${asc ? 'ASC' : 'DESC'}',
      limit: limit,
      offset: offset,
    );
    return rows.map((row) => CollectionItem.fromMap(row)).toList();
  }

  Future<int> getItemCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM collection');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<CollectionItem>> getUnsyncedItems() async {
    final db = await database;
    final rows = await db.query('collection', where: 'is_synced = ?', whereArgs: [0]);
    return rows.map((row) => CollectionItem.fromMap(row)).toList();
  }

  Future<int> markItemsAsSynced(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(', ');
    return await db.rawUpdate('UPDATE collection SET is_synced = 1 WHERE id IN ($placeholders)', ids);
  }

  Future<int> clearAll() async {
    final db = await database;
    await db.delete('deleted_items'); 
    return await db.delete('collection');
  }

  Future<int> updateItem(CollectionItem item) async {
    final db = await database;
    return await db.update('collection', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteItem(String id) async {
    final db = await database;
    final item = await db.query('collection', where: 'id = ?', whereArgs: [id]);
    if (item.isNotEmpty && item.first['is_synced'] == 1) {
      await db.insert('deleted_items', {'id': id}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    return await db.delete('collection', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<String>> getDeletedIds() async {
    final db = await database;
    final rows = await db.query('deleted_items');
    return rows.map((row) => row['id'].toString()).toList();
  }

  Future<void> clearDeletedIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(', ');
    await db.delete('deleted_items', where: "id IN ($placeholders)", whereArgs: ids);
  }

  // FITUR BARU: Ambil nilai unik untuk auto-suggestion
  Future<List<String>> getUniqueValues(String column) async {
    final db = await database;
    // PENTING: Gunakan tanda kutip tunggal ('') untuk string literal di SQLite
    final rows = await db.rawQuery("SELECT DISTINCT $column FROM collection WHERE $column IS NOT NULL AND $column != ''");
    return rows.map((row) => row[column].toString()).toList();
  }
}
