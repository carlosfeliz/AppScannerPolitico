import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class ConfigService {
  static const String _keyBaseUrl = 'api_base_url';
  static const String _keyPadronUrl = 'padron_base_url';
  static const String _keyPrimaryColor = 'primary_color';
  static const String _keySecondaryColor = 'secondary_color';
  static const String _keyLogoPath = 'logo_path';

  // URLs de Gilber Gomez
  static const String defaultBaseUrl = 'https://gilbergomez.siselecto.com/api';
  static const String defaultPadronUrl = 'https://padron-api-production-5296.up.railway.app/api/consulta';
  
  // Branding de Gilber Gomez
  static const String defaultPrimaryColor = '0xFF00264C'; // Azul Gilber
  static const String defaultSecondaryColor = '0xFF00264C';
  static const String defaultLogoPath = 'assets/images/IMG_8950.PNG';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Migración total: Si detectamos rastro de Sanz Lovaton o la URL vieja de Gilber,
    // limpiamos todo para forzar los nuevos colores (#00264C) y logos.
    String? currentUrl = _prefs?.getString(_keyBaseUrl);
    if (currentUrl != null && 
        (currentUrl.contains('sanzlovaton') || currentUrl.contains('gilbergomes.com'))) {
      await _prefs?.clear();
    }
  }

  static String getBaseUrl() {
    String url = _prefs?.getString(_keyBaseUrl) ?? defaultBaseUrl;
    // Asegurar que no termine en /
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static Future<void> setBaseUrl(String url) async {
    await _prefs?.setString(_keyBaseUrl, url);
  }

  static String getPadronUrl() {
    return _prefs?.getString(_keyPadronUrl) ?? defaultPadronUrl;
  }

  static Future<void> setPadronUrl(String url) async {
    await _prefs?.setString(_keyPadronUrl, url);
  }

  static Color getPrimaryColor() {
    final hex = _prefs?.getString(_keyPrimaryColor) ?? defaultPrimaryColor;
    try {
      return Color(int.parse(hex));
    } catch (e) {
      return Color(int.parse(defaultPrimaryColor));
    }
  }

  static Future<void> setPrimaryColor(String hex) async {
    await _prefs?.setString(_keyPrimaryColor, hex);
  }

  static Color getSecondaryColor() {
    final hex = _prefs?.getString(_keySecondaryColor) ?? defaultSecondaryColor;
    try {
      return Color(int.parse(hex));
    } catch (e) {
      return Color(int.parse(defaultSecondaryColor));
    }
  }

  static Future<void> setSecondaryColor(String hex) async {
    await _prefs?.setString(_keySecondaryColor, hex);
  }

  static String getLogoPath() {
    return _prefs?.getString(_keyLogoPath) ?? defaultLogoPath;
  }

  static Future<void> setLogoPath(String path) async {
    await _prefs?.setString(_keyLogoPath, path);
  }

  // Verificar si es el usuario super admin
  static bool isSuperAdmin(String username) {
    return username == '00114865355';
  }
}
