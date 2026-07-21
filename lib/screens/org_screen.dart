import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import 'login_screen.dart';
import 'qr_config_scanner_screen.dart';

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

  /// Normaliza la clave de acceso antes de mandarla.
  ///
  /// Las claves se reparten escritas como MOV-RVSNZ2, y el capturista la copia
  /// de un papel o de un WhatsApp. Escribirla sin guion, con un espacio o en
  /// minusculas es lo normal, y antes cualquiera de esas tres cosas devolvia
  /// "clave incorrecta" sin explicar por que.
  ///
  /// Se quita todo lo que no sea letra o numero y se pasa a mayusculas, asi
  /// que MOV-RVSNZ2, movrvsnz2 y "mov rvsnz2" acaban siendo la misma clave.
  static String _normalizarClave(String valor) {
    return valor.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  /// Pone el guion solo, en mayusculas, mientras se escribe.
  ///
  /// Las claves se reparten como MOV-RVSNZ2, con el prefijo fijo del tipo de
  /// organizacion. Pedirle al capturista que teclee el guion es pedirle que se
  /// equivoque: si no lo ponia, la clave era rechazada sin mas explicacion.
  /// Ahora escribe MOVRVSNZ2 y el campo lo va colocando en su sitio.
  ///
  /// Se recoloca el cursor al final a proposito: al insertar un caracter que
  /// el usuario no tecleo, el cursor se quedaria una posicion atras y el
  /// siguiente digito acabaria dentro del prefijo.
  static TextEditingValue _formatearClave(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    final limpio = nuevo.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

    // Sin al menos las tres letras del prefijo no hay donde poner el guion, y
    // forzarlo mientras escribe la primera letra seria molesto.
    final texto = limpio.length > 3
        ? '${limpio.substring(0, 3)}-${limpio.substring(3)}'
        : limpio;

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }

  Future<void> _connect() async {
    final code = _codeController.text.trim().toLowerCase();
    final key = _normalizarClave(_keyController.text);
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

  /// Abre el lector de QR y, si devuelve datos, rellena los campos y conecta.
  /// El QR lo genera la organizacion desde su panel, asi el capturista no
  /// tiene que escribir el codigo ni la clave a mano.
  Future<void> _escanear() async {
    final datos = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(builder: (_) => const QrConfigScannerScreen()),
    );
    if (datos == null || !mounted) return;

    _codeController.text = datos['slug'] ?? '';
    _keyController.text = datos['key'] ?? '';
    await _connect();
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
                        child: Image.asset(
                          'assets/images/SiselectSolo.png',
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                        ),
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
                              inputFormatters: [
                                // La clave siempre es MOV-XXXXXX en mayusculas.
                                // textCapitalization solo sugiere al teclado: si
                                // se escribe en minuscula o se PEGA, el texto
                                // quedaria tal cual.
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9\-]')),
                                TextInputFormatter.withFunction(_formatearClave),
                              ],
                              onSubmitted: (_) => _connect(),
                              decoration: InputDecoration(
                                labelText: 'Clave de acceso',
                                hintText: 'ej. MOV-K7P2QX',
                                prefixIcon: const Icon(Icons.key_rounded),
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Atajo: leer el QR del panel evita escribir el
                            // codigo y una clave de 10 caracteres en un telefono.
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _escanear,
                                icon: const Icon(Icons.qr_code_scanner_rounded),
                                label: const Text(
                                  'ESCANEAR CODIGO QR',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primary,
                                  side: BorderSide(color: primary, width: 1.6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
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
