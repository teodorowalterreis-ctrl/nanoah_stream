import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';

class ApiService {
  static Future<dynamic> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) {
        return {"status": "error", "message": "Servidor não retornou resposta."};
      }

      final data = jsonDecode(response.body);

      if (data is Map && data['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        if (data['user'] != null && data['user']['name'] != null) {
          await prefs.setString('user_name', data['user']['name']);
        }
      }

      return data;
    } catch (e) {
      return {"status": "error", "message": "Erro de conexão com o servidor: $e"};
    }
  }

  static Future<dynamic> register(String username, String password, String fullName) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.registerEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
          "full_name": fullName,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) {
        return {"status": "error", "message": "Servidor não retornou resposta."};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Erro de conexão com o servidor: $e"};
    }
  }

  static Future<dynamic> getContent(String type) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.contentEndpoint}?type=$type"),
      ).timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) return [];
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Erro ao carregar conteúdos: $e"};
    }
  }
}