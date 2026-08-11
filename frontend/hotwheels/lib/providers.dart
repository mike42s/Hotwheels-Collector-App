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
    try {
      debugPrint('Sync: Memulai proses sinkronisasi...');
      final api = await ref.read(apiServiceProvider.future);

      // 1. Sinkronisasi Penghapusan (Kirim ID yang dihapus lokal ke server)
      final deletedIds = await _db.getDeletedIds();
      if (deletedIds.isNotEmpty) {
        debugPrint('Sync: Mengirim ${deletedIds.length} ID untuk dihapus di server...');
        await api.syncDeletions(deletedIds);
        await _db.clearDeletedIds(deletedIds);
        debugPrint('Sync: Penghapusan berhasil.');
      }

      // 2. Upload Unsynced (Baru/Update)
      final unsynced = await _db.getUnsyncedItems();
      if (unsynced.isNotEmpty) {
        debugPrint('Sync: Mengunggah ${unsynced.length} item baru/update ke server...');
        await api.syncCollections(unsynced);
        await _db.markItemsAsSynced(unsynced.map((i) => i.id).toList());
        debugPrint('Sync: Upload berhasil.');
      }

      // 3. Download Remote
      debugPrint('Sync: Mengunduh data terbaru dari server...');
      final remote = await api.fetchCollections();
      debugPrint('Sync: Berhasil mengunduh ${remote.length} item dari server.');

      for (final item in remote) {
        // Gunakan replace logic agar data lokal selalu terupdate dengan data server
        await _db.insertItem(item.copyWith(isSynced: 1));
      }
      debugPrint('Sync: Sinkronisasi database lokal selesai.');

      await loadInitial();
      debugPrint('Sync: Proses selesai sepenuhnya.');
    } catch (e, stack) {
      debugPrint('Sync Error: $e');
      debugPrint('Stacktrace: $stack');
      rethrow; // Teruskan agar bisa ditangkap oleh UI
    }
  }

  Future<void> clearAll() async {
    await _db.clearAll();
    await loadInitial();
  }

  Future<void> deleteItem(String id) async {
    debugPrint('Notifier: Attempting to delete ID: $id');
    final api = await ref.read(apiServiceProvider.future);
    try {
      debugPrint('Notifier: Calling API syncDeletions for $id');
      await api.syncDeletions([id]);
      debugPrint('Notifier: Immediate server delete successful.');
    } catch (e, stackTrace) {
      debugPrint('Notifier: Server delete failed!');
      debugPrint('Notifier: Error: $e');
      debugPrint('Notifier: StackTrace: $stackTrace');
    }
    debugPrint('Notifier: Calling local DB deleteItem for $id');
    await _db.deleteItem(id);
    debugPrint('Notifier: Local DB delete successful for $id');
    await loadInitial();
    debugPrint('Notifier: Delete process completed for $id');
  }

  Future<List<String>> getSuggestions(String column) async {
    try {
      final localData = await _db.getUniqueValues(column);
      final api = await ref.read(apiServiceProvider.future);
      final remoteData = await api.fetchSuggestions(column);
      final combined = <String>{...localData, ...remoteData}.toList();
      combined.sort();
      return combined;
    } catch (e) {
      debugPrint('Error getting suggestions: $e');
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
        kategoriKendaraan: categories[r.nextInt(categories.length)],
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
        penomoran1: r.nextInt(250).toString(),
        penomoran2: '250',
        penomoranKategori1: (r.nextInt(10) + 1).toString(),
        penomoranKategori2: '10',
        jenisKendaraan: 'City Car',
        createdAt: '09-08-2026 21:00',
        updatedAt: '09-08-2026 21:00',
        photoUpdatedAt: '',
      );
      await _db.insertItem(item);
    }
    await loadInitial();
  }
}

final collectionListProvider = StateNotifierProvider<CollectionListNotifier, CollectionListState>(
  (ref) => CollectionListNotifier(ref),
);
