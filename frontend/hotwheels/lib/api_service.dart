import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/collection_item.dart';

class ApiService {
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

    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final tokenValue = body['token']?.toString();
      if (tokenValue == null || tokenValue.isEmpty) {
        throw Exception('Token tidak diterima');
      }
      await _prefs.setString(_tokenKey, tokenValue);
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

  // FITUR BARU: Sinkronisasi penghapusan ke server
  Future<void> syncDeletions(List<String> ids) async {
    final authToken = token;
    if (authToken == null || authToken.isEmpty) return;

    final response = await http.post(
      Uri.parse('$_baseUrl/api/sync/delete'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $authToken'},
      body: jsonEncode({'ids': ids}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Gagal sinkronisasi penghapusan');
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
