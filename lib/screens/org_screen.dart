import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import 'login_screen.dart';

/// Pantalla de seleccion de organizacion (tenant). El usuario escribe el codigo
/// que le dio su administrador; la app baja la config real y la deja activa.
class OrgScreen extends StatefulWidget {
  const OrgScreen({Key? key}) : super(key: key);

  @override
  State<OrgScreen> createState() => _OrgScreenState();
}

class _OrgScreenState extends State<OrgScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _keyController = TextEditingController();
  bool _isLoading = false;

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _keyController.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final code = _codeController.text.trim().toLowerCase();
    final key = _keyController.text.trim();
    if (code.isEmpty) {
      _snack('Ingrese el codigo de su organizacion');
      return;
    }
    if (key.isEmpty) {
      _snack('Ingrese la clave de acceso');
      return;
    }

    setState(() => _isLoading = true);
    final result = await ApiService.fetchMobileConfig(code, key);
    if (!mounted) return;

    // El bloque app_update viene en TODAS las respuestas, incluidos los errores,
    // porque una app vieja puede estar fallando justamente por estar vencida.
    // Por eso se revisa antes de decidir si la respuesta fue exitosa.
    await _checkForUpdate(result);
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() => _isLoading = false);
      _snack(result['message'] ?? 'No se pudo conectar');
      return;
    }

    final data = Map<String, dynamic>.from(result['data']);
    if (data['mobile_enabled'] != true) {
      setState(() => _isLoading = false);
      _snack('La app movil no esta habilitada para esta organizacion');
      return;
    }

    await ConfigService.applyMobileConfig(code, data);
    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  /// Busca el bloque `app_update` en la respuesta (esta dentro de `data` cuando
  /// todo va bien, y en la raiz cuando el servidor devolvio un error) y muestra
  /// el aviso si hay una version mas nueva publicada.
  Future<void> _checkForUpdate(Map<String, dynamic> result) async {
    try {
      final raw = result['app_update'] ??
          (result['data'] is Map ? result['data']['app_update'] : null);
      if (raw is! Map) return;

      final update =
          await UpdateService.check(Map<String, dynamic>.from(raw));
      if (update == null || !mounted) return;

      await UpdateDialog.show(context, update);
    } catch (_) {
      // Nunca bloquear el ingreso por un fallo del chequeo de version.
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF334155),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = ConfigService.fallbackPrimary;
    final secondary = Color.lerp(primary, Colors.black, 0.35)!;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primary, secondary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3), width: 2),
                        ),
                        child: const Icon(Icons.apartment_rounded,
                            size: 48, color: Colors.white),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Tu organizacion',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Ingresa el codigo que te dio tu administrador para conectar la app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 36),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _codeController,
                              autocorrect: false,
                              textInputAction: TextInputAction.go,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9\-]')),
                              ],
                              onSubmitted: (_) => _connect(),
                              decoration: InputDecoration(
                                labelText: 'Codigo de organizacion',
                                hintText: 'ej. siselect',
                                prefixIcon: const Icon(Icons.tag_rounded),
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _keyController,
                              autocorrect: false,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.go,
                              onSubmitted: (_) => _connect(),
                              decoration: InputDecoration(
                                labelText: 'Clave de acceso',
                                hintText: 'ej. MOV-7X4K2',
                                prefixIcon: const Icon(Icons.key_rounded),
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _connect,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'CONECTAR',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
