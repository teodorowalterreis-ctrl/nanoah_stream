import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';

class ApiService {
  // Função para fazer o login
  static Future> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        // Guarda os dados do utilizador localmente no telemóvel/TV Box
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_name', data['user']['name']);
      }

      return data;
    } catch (e) {
      return {"status": "error", "message": "Erro de conexão com o servidor: $e"};
    }
  }

  // Função para registar uma nova conta
  static Future> register(String username, String password, String fullName) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.registerEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
          "full_name": fullName,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Erro de conexão com o servidor: $e"};
    }
  }

  // Função para buscar as listas de canais e filmes
  static Future<dynamic> getContent(String type) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.contentEndpoint}?type=$type"),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Erro ao carregar conteúdos: $e"};
    }
  }
}