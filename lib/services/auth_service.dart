import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config_service.dart';

class AuthService {
  static String get baseUrl => ConfigService.getBaseUrl();
  static const storage = FlutterSecureStorage();

  // Login
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json', // Importante para Laravel APIs
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await storage.write(key: 'token', value: data['token']);
        await storage.write(key: 'user', value: jsonEncode(data['user']));
        return {'success': true, 'data': data};
      } else {
        await storage.delete(key: 'token');
        await storage.delete(key: 'user');
        
        // Si no es JSON (ej. HTML de error 404/500), no intentamos parsear
        if (response.headers['content-type']?.contains('application/json') ?? false) {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['error'] ?? error['message'] ?? 'Error del servidor (${response.statusCode})'
          };
        } else {
          return {
            'success': false,
            'message': 'Error del servidor: código ${response.statusCode}. Verifique la configuración de la API.'
          };
        }
      }
    } catch (e) {
      await storage.delete(key: 'token');
      await storage.delete(key: 'user');
      return {'success': false, 'message': 'Error inesperado: $e'};
    }
  }

  // Logout
  static Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
      }
    } catch (e) {
      print('Error en logout: $e');
    } finally {
      await storage.delete(key: 'token');
      await storage.delete(key: 'user');
    }
  }

  // Obtener token
  static Future<String?> getToken() async {
    return await storage.read(key: 'token');
  }

  // Obtener usuario
  static Future<Map<String, dynamic>?> getUser() async {
    final userStr = await storage.read(key: 'user');
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  // Verificar si está autenticado
  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}