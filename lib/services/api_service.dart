import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'config_service.dart';

class ApiService {
  static String get baseUrl => ConfigService.getBaseUrl();
  static String get padronUrl => ConfigService.getPadronUrl();

  /// Consulta la config publica de arranque de un tenant por su codigo (slug)
  /// + su clave de acceso. Arma el subdominio `https://{slug}.siselecto.com`
  /// y pega a /mobile/config, pasando la clave como query param.
  static Future<Map<String, dynamic>> fetchMobileConfig(
      String slug, String key) async {
    final clean = slug.trim().toLowerCase();
    if (clean.isEmpty) {
      return {'success': false, 'message': 'Ingrese el codigo de su organizacion'};
    }
    final url = Uri.parse(
            'https://$clean.${ConfigService.mainDomain}/api/mobile/config/$clean')
        .replace(queryParameters: {'key': key.trim()});
    try {
      final response = await http.get(url, headers: {'Accept': 'application/json'});
      final isJson =
          response.headers['content-type']?.contains('application/json') ?? false;

      if (response.statusCode == 200 && isJson) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return {'success': true, 'data': Map<String, dynamic>.from(body['data'])};
        }
      }

      if (isJson) {
        final body = jsonDecode(response.body);
        final result = <String, dynamic>{
          'success': false,
          'message': body['error'] ?? body['message'] ?? 'No se pudo conectar con la organizacion (${response.statusCode})',
        };
        if (body['app_update'] is Map) {
          result['app_update'] = body['app_update'];
        }
        return result;
      }

      if (response.statusCode == 404) {
        return {'success': false, 'message': 'Organizacion no encontrada'};
      }
      return {
        'success': false,
        'message': 'No se pudo conectar con la organizacion (${response.statusCode})'
      };
    } catch (e) {
      return {'success': false, 'message': 'Error de red: revise su conexion'};
    }
  }

  // Headers autenticados
  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // Consultar padrón electoral externo
  static Future<Map<String, dynamic>> consultarPadron(String cedula) async {
    try {
      final url = Uri.parse('$padronUrl?cedula=$cedula');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        if (response.headers['content-type']?.contains('application/json') ?? false) {
          return jsonDecode(response.body);
        }
      }
      return {'success': false, 'message': 'El padrón no respondió con datos válidos (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Error de red o formato: $e'};
    }
  }

  // Validar cédula (algoritmo de Luhn - JCE)
  static bool validarCedulaLuhn(String cedula) {
    if (cedula.length != 11) return false;
    
    try {
      final digits = cedula.split('').map(int.parse).toList();
      int sum = 0;
      
      for (int i = 0; i < 10; i++) {
        int digit = digits[i];
        if (i % 2 == 0) {
          digit *= 2;
          if (digit > 9) digit -= 9;
        }
        sum += digit;
      }
      
      int checkDigit = (10 - (sum % 10)) % 10;
      return checkDigit == digits[10];
    } catch (e) {
      return false;
    }
  }

  // Crear votante
  static Future<Map<String, dynamic>> crearVotante(
    Map<String, dynamic> voterData,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/voters'),
        headers: headers,
        body: jsonEncode(voterData),
      );

      final isJson = response.headers['content-type']?.contains('application/json') ?? false;
      
      if (!isJson) {
        return {'success': false, 'message': 'El servidor no devolvió una respuesta válida (Código: ${response.statusCode})'};
      }

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': responseData};
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Sin permisos',
          'error_type': 'permission_denied'
        };
      } else if (response.statusCode == 422) {
        return {
          'success': false,
          'message': 'Errores de validación',
          'errors': responseData['errors']
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Error desconocido del servidor (${response.statusCode})'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión o formato: $e'};
    }
  }

  // Buscar votante registrado
  static Future<Map<String, dynamic>> buscarVotante(String cedula) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/voters/buscar/$cedula'),
        headers: headers,
      );

      if (response.statusCode == 200 && (response.headers['content-type']?.contains('application/json') ?? false)) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Respuesta no válida del servidor (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión o formato: $e'};
    }
  }

  // Obtener datos de referencia (provincias, municipios, etc.)
  static Future<Map<String, dynamic>> getReferenceData() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/voters/reference-data'),
        headers: headers,
      );

      if (response.statusCode == 200 && (response.headers['content-type']?.contains('application/json') ?? false)) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Error al obtener datos (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión o formato: $e'};
    }
  }
}