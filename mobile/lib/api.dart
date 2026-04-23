import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Change this to your Mac's local IP when testing on a real device ──
String kBaseUrl = 'http://100.96.118.115:8000';

class Api {
  static void setBaseUrl(String url) {
    kBaseUrl = url;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('mise_token');
  }

  static Future<void> setSession(String token, Map user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mise_token', token);
    await prefs.setString('mise_user', jsonEncode(user));
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mise_token');
    await prefs.remove('mise_user');
  }

  static Future<Map<String, dynamic>?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('mise_user');
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static const _timeout = Duration(seconds: 10);

  static Future<http.Response> get(String path) async {
    return http.get(Uri.parse('$kBaseUrl$path'), headers: await _headers()).timeout(_timeout);
  }

  static Future<http.Response> post(String path, Map body) async {
    return http.post(
      Uri.parse('$kBaseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(_timeout);
  }

  static Future<http.Response> put(String path, Map body) async {
    return http.put(
      Uri.parse('$kBaseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(_timeout);
  }

  static Future<http.Response> patch(String path) async {
    return http.patch(Uri.parse('$kBaseUrl$path'), headers: await _headers()).timeout(_timeout);
  }

  static Future<http.Response> delete(String path) async {
    return http.delete(Uri.parse('$kBaseUrl$path'), headers: await _headers()).timeout(_timeout);
  }

  static Future<http.Response> deleteWithBody(String path, Map body) async {
    final request = http.Request('DELETE', Uri.parse('$kBaseUrl$path'));
    request.headers.addAll(await _headers());
    request.body = jsonEncode(body);
    final streamed = await request.send().timeout(_timeout);
    return http.Response.fromStream(streamed);
  }

  static Future<http.Response> uploadImage(String path, File file) async {
    final token = await getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$kBaseUrl$path'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

}
