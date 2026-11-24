import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../app_navigator.dart';
import '../screens/login_screen.dart';
import 'config_service.dart';

class AuthService {
  static String get baseUrl => ConfigService.getBaseUrl();
  static const storage = FlutterSecureStorage();

  static const String sessionExpiredMessage =
      'Sesión expirada. Inicie sesión nuevamente.';
  static const String _keyTokenSavedAt = 'token_saved_at';

  /// Pasado este tiempo desde que se guardo el token, se pide uno nuevo al
  /// abrir la app. Asi, mientras el usuario entre al menos una vez dentro de la
  /// vigencia del token (30 dias), la sesion nunca se corta.
  static const Duration _refreshAfter = Duration(days: 1);

  static bool _handlingUnauthorized = false;

  /// El servidor rechazo el token (401): se borra la sesion local, se avisa y se
  /// lleva al usuario al login. Es idempotente: varias llamadas fallando a la
  /// vez solo disparan una navegacion. NO borra la cola offline, para que las
  /// capturas pendientes se envien al volver a iniciar sesion.
  static Future<void> handleUnauthorized() async {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    Future.delayed(const Duration(seconds: 3), () => _handlingUnauthorized = false);

    await clearLocalSession();
    _showSessionExpired();
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  static void _showSessionExpired() {
    appMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(sessionExpiredMessage)));
  }

  /// Renueva el token si ya tiene mas de un dia. Devuelve false SOLO si el
  /// servidor confirma que la sesion no es valida (401); ante cualquier fallo
  /// de red devuelve true para no bloquear el trabajo sin conexion.
  static Future<bool> refreshTokenIfNeeded() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return false;

      final savedRaw = await storage.read(key: _keyTokenSavedAt);
      final saved = savedRaw == null ? null : DateTime.tryParse(savedRaw);
      if (saved != null && DateTime.now().difference(saved) < _refreshAfter) {
        return true;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final newToken = jsonDecode(response.body)['token'];
        if (newToken is String && newToken.isNotEmpty) {
          await storage.write(key: 'token', value: newToken);
          await storage.write(
              key: _keyTokenSavedAt, value: DateTime.now().toIso8601String());
        }
        return true;
      }
      if (response.statusCode == 401) {
        await clearLocalSession();
        _showSessionExpired();
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

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
          'client_type': 'mobile-app',
          'tenant_slug': ConfigService.getTenantSlug(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await storage.write(key: 'token', value: data['token']);
        await storage.write(
            key: _keyTokenSavedAt, value: DateTime.now().toIso8601String());
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
        ).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      print('Error en logout: $e');
    } finally {
      await clearLocalSession();
    }
  }

  /// Borra token y usuario del dispositivo SIN llamar al servidor.
  ///
  /// Se usa al cambiar de organizacion: un token guardado de un tenant
  /// anterior es la causa de que la app "herede" el alcance de otra cuenta
  /// aunque ya se haya elegido un tenant distinto.
  static Future<void> clearLocalSession() async {
    await storage.delete(key: 'token');
    await storage.delete(key: _keyTokenSavedAt);
    await storage.delete(key: 'user');
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