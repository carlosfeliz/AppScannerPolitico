import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Actualizacion de la app fuera de Google Play.
///
/// La app se distribuye como APK, asi que nadie le avisa al usuario cuando hay
/// una version nueva: tiene que hacerlo el propio servidor. En cada arranque,
/// `GET /api/mobile/config/{slug}` devuelve un bloque `app_update` y aqui se
/// compara contra la version instalada.
///
/// Con APK suelto SIEMPRE hay una confirmacion del usuario para instalar; la
/// actualizacion silenciosa solo es posible en telefonos gestionados por una
/// empresa (MDM) o si la app fuera del sistema.
class UpdateService {
  /// Resultado de comparar la version instalada con la del servidor.
  static UpdateInfo? _pending;

  static UpdateInfo? get pending => _pending;

  /// Compara la version instalada contra la que informa el servidor.
  /// Se le pasa el mapa `app_update` tal cual viene de la API.
  static Future<UpdateInfo?> check(Map<String, dynamic>? appUpdate) async {
    if (appUpdate == null) return null;

    final info = await PackageInfo.fromPlatform();
    // buildNumber es el "+N" de pubspec.yaml (version: 1.0.0+1). Se compara ese
    // y no el nombre "1.0.0" porque es un entero: comparar cadenas daria que
    // "1.10.0" es menor que "1.9.0".
    final current = int.tryParse(info.buildNumber) ?? 0;

    final latest = _asInt(appUpdate['latest_version']);
    final min = _asInt(appUpdate['min_version']);
    final url = (appUpdate['apk_url'] ?? '').toString().trim();

    // Sin APK publicado no hay nada que ofrecer, aunque el numero sea mayor.
    if (url.isEmpty || latest <= current) {
      _pending = null;
      return null;
    }

    _pending = UpdateInfo(
      currentVersion: current,
      latestVersion: latest,
      versionName: (appUpdate['version_name'] ?? '').toString(),
      apkUrl: url,
      notes: (appUpdate['notes'] ?? '').toString(),
      // Obligatoria cuando la instalada quedo por debajo del minimo aceptable:
      // ahi el aviso no se puede cerrar.
      mandatory: current < min,
    );
    return _pending;
  }

  static int _asInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  /// Descarga el APK y lo abre con el instalador de Android.
  ///
  /// [onProgress] recibe un valor entre 0 y 1, o null si el servidor no informa
  /// el tamano total (no todos mandan Content-Length).
  static Future<String?> downloadAndInstall(
    UpdateInfo update, {
    void Function(double? progress)? onProgress,
  }) async {
    try {
      final req = http.Request('GET', Uri.parse(update.apkUrl));
      final res = await http.Client().send(req);

      if (res.statusCode != 200) {
        return 'El servidor respondio ${res.statusCode} al descargar la actualizacion.';
      }

      final total = res.contentLength ?? 0;
      final bytes = <int>[];
      var received = 0;

      await for (final chunk in res.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        onProgress?.call(total > 0 ? received / total : null);
      }

      // Carpeta propia de la app: no requiere permisos de almacenamiento.
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/siselect-${update.latestVersion}.apk');
      await file.writeAsBytes(bytes, flush: true);

      // Abre el instalador del sistema. Si el usuario no ha autorizado
      // "instalar apps desconocidas" para esta app, Android le muestra esa
      // pantalla de ajustes en este punto.
      final result = await OpenFilex.open(file.path,
          type: 'application/vnd.android.package-archive');

      if (result.type != ResultType.done) {
        return 'No se pudo abrir el instalador: ${result.message}';
      }
      return null;
    } catch (e) {
      return 'Fallo la descarga: $e';
    }
  }
}

/// Datos de una actualizacion disponible.
class UpdateInfo {
  final int currentVersion;
  final int latestVersion;
  final String versionName;
  final String apkUrl;
  final String notes;

  /// Cuando es true el aviso no se puede cerrar: la version instalada quedo
  /// por debajo del minimo que el servidor acepta.
  final bool mandatory;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.versionName,
    required this.apkUrl,
    required this.notes,
    required this.mandatory,
  });

  String get displayVersion =>
      versionName.isNotEmpty ? versionName : 'build $latestVersion';
}
