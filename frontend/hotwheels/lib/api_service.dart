import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/collection_item.dart';

class ApiService {
  // Gunakan port 3001 (HTTP) untuk Flutter Web Debug guna menghindari Mixed Content / SSL issues
  static const String _baseUrl = 'https://192.168.0.135:3000';
  static const String _tokenKey = 'auth_token';

  final SharedPreferences _prefs;

  ApiService._(this._prefs);

  static Future<ApiService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ApiService._(prefs);
  }

  String? get token => _prefs.getString(_tokenKey);

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  Future<void> logout() async {
    await _prefs.remove(_tokenKey);
  }

  Future<String> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 201) {
      return 'Register sukses';
    }
    final body = jsonDecode(response.body);
    throw Exception(body['message'] ?? body['error'] ?? 'Register gagal');
  }

  Future<void> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    debugPrint('LOGIN status: ${response.statusCode}');
    debugPrint('LOGIN body: ${response.body}');

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final tokenValue = body['token']?.toString();

      debugPrint('LOGIN token received: ${tokenValue != null && tokenValue.isNotEmpty}');

      if (tokenValue == null || tokenValue.isEmpty) {
        throw Exception('Token tidak diterima dari server');
      }

      final saved = await _prefs.setString(_tokenKey, tokenValue);

      debugPrint('LOGIN token saved: $saved');
      debugPrint('LOGIN token exists after save: ${token != null}');

      return;
    }

    throw Exception(body['message'] ?? body['error'] ?? 'Login gagal');
  }

  Future<void> syncCollections(List<CollectionItem> items) async {
    final authToken = token ?? 'DEBUG_TOKEN';

    final response = await http.post(
      Uri.parse('$_baseUrl/api/sync'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $authToken'},
      body: jsonEncode(items.map((item) => item.toJson()).toList()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? body['error'] ?? 'Sync gagal');
    }
  }

  Future<List<CollectionItem>> fetchCollections() async {
    final authToken = token ?? 'DEBUG_TOKEN';

    final response = await http.get(
      Uri.parse('$_baseUrl/api/collections'),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body.map((json) => CollectionItem.fromJson(json)).toList();
    }
    final body = jsonDecode(response.body);
    throw Exception(body['message'] ?? body['error'] ?? 'Gagal mengambil data dari server');
  }

  Future<void> syncDeletions(List<String> ids) async {
    final authToken = token;
    debugPrint('API: syncDeletions called');
    debugPrint('API: IDs = $ids');
    debugPrint('API: Token exists = ${authToken != null && authToken.isNotEmpty}');
    debugPrint('API: URL = $_baseUrl/api/sync/delete');
    if (authToken == null || authToken.isEmpty) {
      throw Exception('Auth token is missing');
    }
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/sync/delete'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $authToken'},
        body: jsonEncode({'ids': ids}),
      );
      debugPrint('API: Response status = ${response.statusCode}');
      debugPrint('API: Response body = ${response.body}');
      if (response.statusCode != 200) {
        String message = 'Gagal sinkronisasi penghapusan';
        try {
          final body = jsonDecode(response.body);
          message = body['message'] ?? message;
        } catch (_) {
          message = response.body.isNotEmpty ? response.body : message;
        }
        throw Exception('HTTP ${response.statusCode}: $message');
      }
      debugPrint('API: Delete sync successful');
    } catch (e, stackTrace) {
      debugPrint('API: syncDeletions exception: $e');
      debugPrint('API: StackTrace: $stackTrace');
      rethrow;
    }
  }

  // FITUR BARU: Ambil saran kata dari server
  Future<List<String>> fetchSuggestions(String column) async {
    // BYPASS TOKEN IN DEBUG MODE (Handled by server logic)
    final authToken = token ?? 'DEBUG_TOKEN';

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/suggestions/$column'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return body.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return []; // Jika offline, diam saja (fallback ke lokal)
    }
  }
}
