import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  // Change this to your deployed backend URL after hosting.
  static const String baseUrl = 'http://localhost:8080';

  static Future<dynamic> _request(String method, String path, {Map<String, String>? headers, Object? body}) async {
    final token = await AuthService.getIdToken();
    final h = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };
    final uri = Uri.parse('$baseUrl$path');
    late http.Response res;
    switch (method) {
      case 'GET': res = await http.get(uri, headers: h); break;
      case 'POST': res = await http.post(uri, headers: h, body: jsonEncode(body)); break;
      case 'PATCH': res = await http.patch(uri, headers: h, body: jsonEncode(body)); break;
      default: throw Exception('Unsupported method');
    }
    if (res.statusCode >= 400) {
      throw Exception('API error ${res.statusCode}: ${res.body}');
    }
    return res.body.isNotEmpty ? jsonDecode(res.body) : null;
  }

  static Future<List<dynamic>> listEmployees() async => await _request('GET', '/api/users');

  static Future<List<dynamic>> listTasks() async => await _request('GET', '/api/tasks');

  static Future<String> createTask(Map<String, dynamic> payload) async {
    final res = await _request('POST', '/api/tasks', body: payload);
    return res['id'] as String;
  }

  static Future<void> updateTask(String id, Map<String, dynamic> payload) async {
    await _request('PATCH', '/api/tasks/$id', body: payload);
  }

  static Future<void> addTaskUpdate(String id, String message, {String? status}) async {
    await _request('POST', '/api/tasks/$id/updates', body: { 'message': message, if (status != null) 'status': status });
  }
}
