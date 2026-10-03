import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Thin wrapper around package:http that every provider goes through.
/// Handles the base URL, attaches the saved JWT automatically, and turns
/// non-2xx responses into a catchable ApiException with the backend's own
/// error message (FastAPI returns `{"detail": "..."}`).
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _tokenKey = 'auth_token';
  String? _cachedToken;

  Future<String?> get token async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Uri _uri(String path) => Uri.parse('${AppConstants.apiBaseUrl}$path');

  Future<Map<String, String>> _headers({bool auth = true, bool json = true}) async {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (auth) {
      final t = await token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  Future<dynamic> get(String path, {bool auth = true}) async {
    final res = await http.get(_uri(path), headers: await _headers(auth: auth, json: false));
    return _handle(res);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body, bool auth = true}) async {
    final res = await http.post(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body ?? {}));
    return _handle(res);
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final res = await http.delete(_uri(path), headers: await _headers(auth: auth, json: false));
    return _handle(res);
  }

  /// Multipart upload for document files. `bytes` should come from
  /// file_picker with `withData: true` so this works on web too, not just
  /// mobile/desktop where a file path is available.
  Future<dynamic> uploadFile(String path, {required List<int> bytes, required String filename, bool auth = true}) async {
    final request = http.MultipartRequest('POST', _uri(path));
    if (auth) {
      final t = await token;
      if (t != null) request.headers['Authorization'] = 'Bearer $t';
    }
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    String message = 'Request failed (${res.statusCode}). Is the backend running?';
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map && decoded['detail'] != null) message = decoded['detail'].toString();
    } catch (_) {
      // response wasn't JSON — keep the generic message
    }
    throw ApiException(message, res.statusCode);
  }
}
