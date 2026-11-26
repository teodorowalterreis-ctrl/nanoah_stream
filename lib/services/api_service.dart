import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';

class ApiService {
  static Future<dynamic> login(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.loginEndpoint),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "username": username,
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) {
        return {
          "status": "error",
          "message": "Servidor não retornou resposta."
        };
      }

      final data = jsonDecode(response.body);

      if (data is Map && data['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);

        final dynamic serverName =
            data['user'] is Map ? data['user']['name'] : null;
        final String resolvedName =
            (serverName != null && serverName.toString().trim().isNotEmpty)
                ? serverName.toString().trim()
                : username;

        await prefs.setString('user_name', resolvedName);
      }

      return data;
    } catch (e) {
      return {
        "status": "error",
        "message": "Erro de conexão com o servidor: $e"
      };
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('user_name');
  }

  static Future<dynamic> register(
      String username, String password, String fullName) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.registerEndpoint),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "username": username,
              "password": password,
              "full_name": fullName,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) {
        return {
          "status": "error",
          "message": "Servidor não retornou resposta."
        };
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {
        "status": "error",
        "message": "Erro de conexão com o servidor: $e"
      };
    }
  }

  static Future<dynamic> getContent(String type) async {
    try {
      final response = await http
          .get(
            Uri.parse("${ApiConfig.contentEndpoint}?type=$type"),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) return [];
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Erro ao carregar conteúdos: $e"};
    }
  }

  static String _resolveEndpoint(String fileName, {String? customUrl}) {
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      return customUrl.trim();
    }
    return ApiConfig.contentEndpoint.replaceFirst(
      RegExp(r'[^/]+(\?.*)?$'),
      fileName,
    );
  }

  static Future<dynamic> getSaimoLive({String? customUrl}) async {
    try {
      final String endpoint =
          _resolveEndpoint('saimo_live.php', customUrl: customUrl);

      final response = await http
          .get(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) {
        return {
          "status": "error",
          "message": "Servidor não retornou resposta.",
          "data": []
        };
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {
        "status": "error",
        "message": "Erro ao carregar canais Saimo: $e",
        "data": []
      };
    }
  }

  static Future<dynamic> getSaimoVod({String? customUrl}) async {
    try {
      final String endpoint =
          _resolveEndpoint('saimo_vod.php', customUrl: customUrl);

      final response = await http
          .get(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) {
        return {
          "status": "error",
          "message": "Servidor não retornou resposta.",
          "data": []
        };
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {
        "status": "error",
        "message": "Erro ao carregar catálogo Saimo: $e",
        "data": []
      };
    }
  }
}