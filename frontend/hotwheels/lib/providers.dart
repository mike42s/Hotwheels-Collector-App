import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'api_service.dart';
import 'database_helper.dart';
import 'models/collection_item.dart';

final apiServiceProvider = FutureProvider<ApiService>((ref) async {
  return ApiService.create();
});

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

class AuthState {
  final bool loggedIn;
  final String message;
  const AuthState({this.loggedIn = false, this.message = ''});
  AuthState copyWith({bool? loggedIn, String? message}) {
    return AuthState(loggedIn: loggedIn ?? this.loggedIn, message: message ?? this.message);
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this.ref) : super(const AuthState()) {
    _initialize();
  }
  final Ref ref;
  Future<void> _initialize() async {
    final api = await ref.read(apiServiceProvider.future);
    state = state.copyWith(loggedIn: api.isLoggedIn);
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(message: '');
    try {
      final api = await ref.read(apiServiceProvider.future);
      await api.login(username, password);
      state = state.copyWith(loggedIn: true, message: 'Login berhasil');
    } catch (error) {
      state = state.copyWith(loggedIn: false, message: error.toString());
    }
  }

  Future<void> logout() async {
    final api = await ref.read(apiServiceProvider.future);
    await api.logout();
    state = state.copyWith(loggedIn: false, message: 'Logout berhasil');
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));

class CollectionListState {
  final List<CollectionItem> items;
  final int totalCount;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String searchQuery;
  final String sortBy;
  final bool sortAsc;

  CollectionListState({
    this.items = const [],
    this.totalCount = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.searchQuery = '',
    this.sortBy = 'tgl_pembelian',
    this.sortAsc = false,
  });

  CollectionListState copyWith({
    List<CollectionItem>? items,
    int? totalCount,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? searchQuery,
    String? sortBy,
    bool? sortAsc,
  }) {
    return CollectionListState(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortAsc: sortAsc ?? this.sortAsc,
    );
  }
}

class CollectionListNotifier extends StateNotifier<CollectionListState> {
  CollectionListNotifier(this.ref) : super(CollectionListState());
  final Ref ref;
  static const int _pageSize = 24;
  DatabaseHelper get _db => ref.read(databaseHelperProvider);

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true);
    final count = await _db.getItemCount();
    final items = await _db.getPagedItems(
      _pageSize,
      0,
      search: state.searchQuery,
      sortBy: state.sortBy,
      asc: state.sortAsc,
    );
    state = state.copyWith(items: items, totalCount: count, isLoading: false, hasMore: items.length < count);
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    final items = await _db.getPagedItems(
      _pageSize,
      state.items.length,
      search: state.searchQuery,
      sortBy: state.sortBy,
      asc: state.sortAsc,
    );
    state = state.copyWith(
      items: [...state.items, ...items],
      isLoadingMore: false,
      hasMore: (state.items.length + items.length) < state.totalCount,
    );
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    loadInitial();
  }

  void setSort(String field, bool asc) {
    state = state.copyWith(sortBy: field, sortAsc: asc);
    loadInitial();
  }

  Future<void> syncData() async {
    final api = await ref.read(apiServiceProvider.future);

    // 1. Sinkronisasi Penghapusan (Kirim ID yang dihapus lokal ke server)
    final deletedIds = await _db.getDeletedIds();
    if (deletedIds.isNotEmpty) {
      await api.syncDeletions(deletedIds);
      await _db.clearDeletedIds(deletedIds);
    }

    // 2. Upload Unsynced (Baru/Update)
    final unsynced = await _db.getUnsyncedItems();
    if (unsynced.isNotEmpty) {
      await api.syncCollections(unsynced);
      await _db.markItemsAsSynced(unsynced.map((i) => i.id).toList());
    }

    // 3. Download Remote
    final remote = await api.fetchCollections();
    for (final item in remote) {
      await _db.insertItem(item.copyWith(isSynced: 1));
    }

    await loadInitial();
  }

  Future<void> clearAll() async {
    await _db.clearAll();
    await loadInitial();
  }

  Future<void> deleteItem(String id) async {
    await _db.deleteItem(id);
    await loadInitial();
  }

  Future<List<String>> getSuggestions(String column) async {
    try {
      // 1. Ambil data dari Database Lokal
      final localData = await _db.getUniqueValues(column);

      // 2. Ambil data dari Server melalui ApiService
      final api = await ref.read(apiServiceProvider.future);
      final remoteData = await api.fetchSuggestions(column);

      // 3. Gabungkan keduanya, hapus duplikat (menggunakan Set), dan urutkan
      final combined = <String>{...localData, ...remoteData}.toList();
      combined.sort();

      return combined;
    } catch (e) {
      debugPrint('Error getting suggestions: $e');
      // Fallback ke data lokal jika server bermasalah
      return await _db.getUniqueValues(column);
    }
  }

  Future<void> importItems(List<CollectionItem> items) async {
    for (final item in items) {
      await _db.insertItem(item.copyWith(isSynced: 0));
    }
    await loadInitial();
  }

  Future<void> generateDummyData() async {
    final r = Random();
    final names = ['Bone Shaker', 'Twin Mill', 'Deora II', 'Muscle Tone', 'Rodger Dodger', 'Rip Rod', 'Night Shifter'];
    final locations = ['Alfamart', 'Indomaret', 'Toys Kingdom', 'Kidz Station', 'Online Shop'];
    final categories = ['Mainline', 'Premium', 'Treasure Hunt', 'Super Treasure Hunt'];
    final colors = ['Red', 'Blue', 'Green', 'Black', 'White', 'Yellow', 'Silver', 'Gold'];

    for (int i = 0; i < 50; i++) {
      final item = CollectionItem(
        id: const Uuid().v4(),
        tglPembelian:
            '2024-${(r.nextInt(12) + 1).toString().padLeft(2, '0')}-${(r.nextInt(28) + 1).toString().padLeft(2, '0')}',
        lokasiBeli: locations[r.nextInt(locations.length)],
        hargaBeli: ((r.nextInt(100) + 30) * 1000).toDouble(),
        namaKendaraan: names[r.nextInt(names.length)],
        // penomoran: '${r.nextInt(250)}/250',
        kategoriKendaraan: categories[r.nextInt(categories.length)],
        // penomoranKategori: '${r.nextInt(10)}/10',
        kodeHotwheel: 'HKX${r.nextInt(999)}',
        kendaraan: r.nextBool() ? 'Mobil' : 'Motor',
        tahunKendaraan: 2020 + r.nextInt(5),
        trackstar: r.nextBool(),
        specialKategori: r.nextBool() ? 'HW Turbo' : '',
        netflix: r.nextBool(),
        hotwheelShowdown: r.nextBool(),
        warna1: colors[r.nextInt(colors.length)],
        warna2: r.nextBool() ? colors[r.nextInt(colors.length)] : null,
        foto: '',
        isSynced: 0,
        penomoran1: '',
        penomoran2: '',
        penomoranKategori1: '',
        penomoranKategori2: '',
        jenisKendaraan: '',
      );
      await _db.insertItem(item);
    }
    await loadInitial();
  }
}

final collectionListProvider = StateNotifierProvider<CollectionListNotifier, CollectionListState>(
  (ref) => CollectionListNotifier(ref),
);
