import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final String baseUrl = "https://api.ludtanza.my.id/kroscek/api";
  final storage = const FlutterSecureStorage();

  Future<String?> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await storage.write(key: 'token', value: data['token']);
      return data['token'];
    } else {
      return null;
    }
  }

  Future<bool> register(String username, String password, String role) async {
    final url = Uri.parse('$baseUrl/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password, 'role': role}),
    );

    print('Register response status: ${response.statusCode}');
    print('Register response body: ${response.body}');

    return response.statusCode == 201;
  }

  Future<void> createVegetative(Map<String, dynamic> data) async {
    final token = await storage.read(key: 'token');
    final url = Uri.parse('$baseUrl/vegetative');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'data': data}),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create vegetative record');
    }
  }

  Future<List<dynamic>> getVegetative() async {
    final token = await storage.read(key: 'token');
    final url = Uri.parse('$baseUrl/vegetative');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load vegetative records');
    }
  }

// Tambahkan metode untuk `generative`, `preharvest`, `harvest`, `training`, `absenlog`, dan `issue`
}
