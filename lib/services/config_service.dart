import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Configuracion multi-tenant en runtime.
///
/// La app es UNA sola app generica: no trae ningun tenant "clavado". El usuario
/// elige su organizacion (slug) en la pantalla de Organizacion, y la app baja la
/// config real desde `GET /api/mobile/config/{slug}` (base URL, branding, padron).
/// Asi, al guardar votantes se guardan EXACTAMENTE en el tenant correcto.
class ConfigService {
  static const String _keyBaseUrl = 'api_base_url';
  static const String _keyPadronUrl = 'padron_base_url';
  static const String _keyTenantSlug = 'tenant_slug';
  static const String _keyTenantName = 'tenant_name';
  static const String _keyLogoUrl = 'logo_url';
  static const String _keyPrimaryColor = 'primary_color';
  static const String _keyButtonColor = 'button_color';

  /// Dominio principal de la plataforma. Con el slug se arma el subdominio del
  /// tenant: `https://{slug}.siselecto.com`.
  ///
  /// Se define al COMPILAR, no en tiempo de ejecucion, para que la app de
  /// pruebas y la de produccion sean binarios distintos:
  ///
  ///   produccion: flutter build apk --release
  ///   pruebas:    flutter build apk --release --flavor staging \
  ///                 --dart-define=MAIN_DOMAIN=staging.siselecto.com
  ///
  /// A proposito NO es un ajuste que el usuario pueda cambiar dentro de la app:
  /// si un capturista lo tocara por error, pasaria el dia registrando votantes
  /// reales contra la base de pruebas sin que nadie lo note.
  static const String mainDomain = String.fromEnvironment(
    'MAIN_DOMAIN',
    defaultValue: 'siselecto.com',
  );

  /// Fallback neutro de marca (azul plataforma) cuando aun no hay tenant.
  static const Color fallbackPrimary = Color(0xFF002855);
  static const Color fallbackButton = Color(0xFF007BFF);
  static const String defaultPadronUrl =
      'https://padron-api-production-5296.up.railway.app/api/consulta';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Migracion: limpiar cualquier rastro de las URLs viejas hardcodeadas
    // (Gilber / Sanz Lovaton) para forzar el flujo multi-tenant nuevo.
    final currentUrl = _prefs?.getString(_keyBaseUrl);
    // OJO: no incluir 'siselect' aqui — todas las URLs de produccion son
    // {slug}.siselecto.com y borrarian la sesion en cada arranque. Solo se
    // limpian las URLs viejas hardcodeadas (Gilber / Sanz Lovaton).
    if (currentUrl != null &&
        (currentUrl.contains('sanzlovaton') ||
            currentUrl.contains('gilbergomez') ||
            currentUrl.contains('gilbergomes'))) {
      await clearTenant();
    }
  }

  // ── Estado del tenant ──────────────────────────────────────────────────────

  static bool hasTenant() => getBaseUrl().isNotEmpty;

  static String getBaseUrl() {
    var url = _prefs?.getString(_keyBaseUrl) ?? '';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  static String getPadronUrl() =>
      _prefs?.getString(_keyPadronUrl) ?? defaultPadronUrl;

  static String getTenantSlug() => _prefs?.getString(_keyTenantSlug) ?? '';

  static String getTenantName() => _prefs?.getString(_keyTenantName) ?? '';

  static String getLogoUrl() => _prefs?.getString(_keyLogoUrl) ?? '';

  static Color getPrimaryColor() =>
      _parseColor(_prefs?.getString(_keyPrimaryColor), fallbackPrimary);

  static Color getButtonColor() =>
      _parseColor(_prefs?.getString(_keyButtonColor), fallbackButton);

  /// Color secundario derivado: una version mas oscura del primario para los
  /// degradados de fondo.
  static Color getSecondaryColor() {
    final p = getPrimaryColor();
    return Color.lerp(p, Colors.black, 0.35) ?? p;
  }

  // ── Aplicar la config de /mobile/config ────────────────────────────────────

  /// Guarda la respuesta de `GET /api/mobile/config/{slug}` como tenant activo.
  static Future<void> applyMobileConfig(
    String slug,
    Map<String, dynamic> data,
  ) async {
    final p = _prefs;
    if (p == null) return;

    await p.setString(_keyTenantSlug, slug);
    // La baseUrl se arma desde el slug (no se confia en el host que devuelve el
    // servidor detras del proxy, que puede salir mal). Fallback al api_base_url.
    final baseUrl = slug.isNotEmpty
        ? 'https://$slug.$mainDomain/api'
        : (data['api_base_url'] ?? '').toString();
    await p.setString(_keyBaseUrl, baseUrl);
    await p.setString(
        _keyPadronUrl, (data['padron_url'] ?? defaultPadronUrl).toString());
    await p.setString(_keyTenantName, (data['tenant_name'] ?? '').toString());
    await p.setString(_keyLogoUrl, (data['logo'] ?? '').toString());

    final colors = data['colors'];
    if (colors is Map) {
      await p.setString(
          _keyPrimaryColor, (colors['login_color'] ?? '').toString());
      await p.setString(
          _keyButtonColor,
          (colors['button_primary_color'] ?? colors['accent_color'] ?? '')
              .toString());
    }
  }

  static Future<void> clearTenant() async {
    final p = _prefs;
    if (p == null) return;
    for (final k in [
      _keyBaseUrl,
      _keyPadronUrl,
      _keyTenantSlug,
      _keyTenantName,
      _keyLogoUrl,
      _keyPrimaryColor,
      _keyButtonColor,
    ]) {
      await p.remove(k);
    }
  }

  // ── Setters usados por la pantalla de admin (override manual) ───────────────

  static Future<void> setBaseUrl(String url) async =>
      _prefs?.setString(_keyBaseUrl, url);
  static Future<void> setPadronUrl(String url) async =>
      _prefs?.setString(_keyPadronUrl, url);

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Acepta '#RRGGBB', 'RRGGBB', '0xFFRRGGBB' o '0xAARRGGBB'.
  static Color _parseColor(String? raw, Color fallback) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    var s = raw.trim();
    try {
      if (s.startsWith('#')) s = s.substring(1);
      if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
      if (s.length == 6) s = 'FF$s';
      return Color(int.parse(s, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  // Super admin (override manual de configuracion).
  static bool isSuperAdmin(String username) => username == '00114865355';
}
