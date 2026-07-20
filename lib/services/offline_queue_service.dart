import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'config_service.dart';

/// Cola de votantes pendientes de enviar cuando no hay conexion.
///
/// Diseno aditivo: el guardado online normal NO cambia. Solo cuando el POST a
/// /voters falla por red, el votante se guarda aqui y se reintenta luego
/// (al reconectar, al abrir la app, o manualmente). Persistencia en
/// SharedPreferences como lista JSON (sin dependencias nativas nuevas).
class OfflineQueueService {
  static const String _key = 'pending_voters';

  static Future<List<Map<String, dynamic>>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items));
  }

  static Future<int> count() async => (await _load()).length;

  /// Guarda un votante para envio posterior. Registra la base_url del tenant
  /// activo para enviarlo al lugar correcto aunque luego se cambie de org.
  static Future<void> enqueue(Map<String, dynamic> payload) async {
    final items = await _load();
    items.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'base_url': ConfigService.getBaseUrl(),
      'tenant_slug': ConfigService.getTenantSlug(),
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
    await _save(items);
  }

  /// Intenta enviar todos los pendientes. Devuelve {'sent', 'remaining'}.
  /// Los 201 se eliminan; los errores de red/servidor se conservan para
  /// reintentar; los rechazos permanentes de datos (422/409) se mueven a un
  /// registro de fallidos para no atascar la cola ni perder la captura.
  static Future<Map<String, int>> syncAll() async {
    final items = await _load();
    if (items.isEmpty) return {'sent': 0, 'remaining': 0};

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      return {'sent': 0, 'remaining': items.length};
    }

    final remaining = <Map<String, dynamic>>[];
    final failed = <Map<String, dynamic>>[];
    int sent = 0;

    for (final item in items) {
      final baseUrl =
          (item['base_url'] ?? ConfigService.getBaseUrl()).toString();
      final payload = Map<String, dynamic>.from(item['payload'] ?? {});

      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/voters'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 201) {
          sent++;
        } else if (response.statusCode == 422 || response.statusCode == 409) {
          // Rechazo permanente (validacion / duplicado): no reintentar.
          item['last_error'] = response.body;
          failed.add(item);
        } else {
          // 401/403/429/5xx u otros: reintentar despues.
          item['attempts'] = (item['attempts'] ?? 0) + 1;
          remaining.add(item);
        }
      } catch (_) {
        // Sin conexion / timeout: conservar para reintentar.
        item['attempts'] = (item['attempts'] ?? 0) + 1;
        remaining.add(item);
      }
    }

    await _save(remaining);
    if (failed.isNotEmpty) await _appendFailed(failed);

    return {'sent': sent, 'remaining': remaining.length};
  }

  // ── Registro de fallidos permanentes (para revision, no se pierden) ─────────

  static const String _failedKey = 'failed_voters';

  static Future<void> _appendFailed(List<Map<String, dynamic>> newFailed) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_failedKey);
    final current = <dynamic>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        current.addAll(jsonDecode(raw) as List);
      } catch (_) {}
    }
    current.addAll(newFailed);
    await prefs.setString(_failedKey, jsonEncode(current));
  }

  static Future<int> failedCount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_failedKey);
    if (raw == null || raw.isEmpty) return 0;
    try {
      return (jsonDecode(raw) as List).length;
    } catch (_) {
      return 0;
    }
  }
}
