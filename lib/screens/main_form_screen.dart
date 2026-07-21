import 'dart:async';
import 'dart:convert';
import 'package:capturas/screens/cedula_scanner_screen.dart';
import 'package:capturas/screens/admin_settings_screen.dart';
import 'package:capturas/services/config_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/offline_queue_service.dart';
import 'login_screen.dart';
import 'package:flutter/services.dart';

class MainFormScreen extends StatefulWidget {
  const MainFormScreen({Key? key}) : super(key: key);

  @override
  State<MainFormScreen> createState() => _MainFormScreenState();
}

class _MainFormScreenState extends State<MainFormScreen> {
  // Campo de texto reutilizable
  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        enabled: enabled,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: ConfigService.getPrimaryColor().withOpacity(0.7)),
          labelText: label,
          border: InputBorder.none,
        ),
      ),
    );
  }

  // Encabezado de seccion con barra de acento del color del tenant
  Widget _sectionHeader(String title, IconData icon) {
    final primary = ConfigService.getPrimaryColor();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 20, color: primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }

  // Normaliza PascalCase del API externo a snake_case que usa el backend
  Map<String, dynamic> _normalizarDatosPadron(Map<String, dynamic> raw) {
    final normalized = Map<String, dynamic>.from(raw);

    const pascalToSnake = {
      'IdProvincia': 'id_provincia',
      'IdMunicipio': 'id_municipio',
      'CodigoCircunscripcion': 'codigo_circunscripcion',
      'CodigoRecinto': 'codigo_recinto',
      'CodigoColegio': 'codigo_colegio',
      'FechaNacimiento': 'fecha_nacimiento',
      'IdSexo': 'sexo',
      'IdEstadoCivil': 'id_estado_civil',
      'IdNacionalidad': 'id_nacionalidad',
      'IdSectorParaje': 'id_sector_paraje',
      'IDSectorParaje': 'id_sector_paraje',
      'SectorParaje': 'sector_paraje',
      'IdCategoria': 'id_categoria',
      'IdCausaCancelacion': 'id_causa_cancelacion',
      'IdMunicipioOrigen': 'id_municipio_origen',
      'IdRecintoOrigen': 'id_recinto_origen',
      'CodigoRecintoOrigen': 'codigo_recinto_origen',
      'IdColegioOrigen': 'id_colegio_origen',
      'ColegioOrigen': 'colegio_origen',
      'PosPagina': 'pos_pagina',
      'LugarVotacion': 'lugar_votacion',
      'IdMunicipioExterior': 'id_municipio_exterior',
      'IDRecintoExterior': 'id_recinto_exterior',
      'IDColegioExterior': 'id_colegio_exterior',
      'CodigoRecintoExterior': 'codigo_recinto_exterior',
      'ColegioExterior': 'colegio_exterior',
      'PosPaginaExterior': 'pos_pagina_exterior',
      'NombresPlastico': 'nombres_plastico',
      'ApellidosPlastico': 'apellidos_plastico',
    };

    for (final entry in pascalToSnake.entries) {
      if (raw.containsKey(entry.key) && raw[entry.key] != null) {
        normalized[entry.value] = raw[entry.key];
      }
    }

    // Truncar fechas a solo YYYY-MM-DD (el API externo envía "1981-02-18 00:00:00")
    for (final key in ['fecha_nacimiento', 'FechaNacimiento', 'birth_date']) {
      if (normalized[key] is String && (normalized[key] as String).length > 10) {
        normalized[key] = (normalized[key] as String).substring(0, 10);
      }
    }

    return normalized;
  }

  // Consulta al padrón
  Future<void> _consultarPadron(String cedulaSinGuiones) async {
    if (cedulaSinGuiones.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cédula debe tener 11 dígitos')),
      );
      return;
    }

    setState(() {
      _isConsulting = true;
    });

    try {
      final url = Uri.parse('$_baseUrl?cedula=$cedulaSinGuiones');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 404) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final raw = Map<String, dynamic>.from(data['data']);
          final ciudadano = _normalizarDatosPadron(raw);
          setState(() {
            _nombresController.text = ciudadano['nombres'] ?? '';
            _primerApellidoController.text = ciudadano['apellido1'] ?? '';
            _segundoApellidoController.text = ciudadano['apellido2'] ?? '';
            _fotoBase64 = ciudadano['foto_data']?['Imagen'];
            _datosPadron = ciudadano;
          });
        } else {
          _clearCiudadanoData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Ciudadano no encontrado en el padrón'),
            ),
          );
        }
      } else {
        _clearCiudadanoData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Error al consultar el padrón')),
        );
      }
    } catch (e) {
      _clearCiudadanoData();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('🔴 Error de red: $e')));
    } finally {
      setState(() {
        _isConsulting = false;
      });
    }
  }

  void _clearCiudadanoData() {
    _nombresController.clear();
    _primerApellidoController.clear();
    _segundoApellidoController.clear();
    _fotoBase64 = null;
    _datosPadron = null;
  }
  Map<String, dynamic>? _datosPadron;
  Map<String, dynamic>? _datosEnlace;
  final TextEditingController _cedulaController = TextEditingController();
  final TextEditingController _nombresController = TextEditingController();
  final TextEditingController _primerApellidoController =
      TextEditingController();
  final TextEditingController _segundoApellidoController =
      TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cedulaEnlaceController = TextEditingController();
  final TextEditingController _nombreEnlaceController = TextEditingController();

  bool _isSuperAdmin = false;

  // ── Cola offline ──────────────────────────────────────────────────────────
  int _pendingCount = 0;
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    _cedulaEnlaceController.addListener(_onCedulaEnlaceChanged);
    _checkSuperAdmin();
    _refreshPending();
    // Intento inicial + auto-sincronizacion al recuperar conexion.
    _syncPending(silent: true);
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) _syncPending(silent: true);
    });
  }

  Future<void> _refreshPending() async {
    final c = await OfflineQueueService.count();
    if (mounted) setState(() => _pendingCount = c);
  }

  Future<void> _syncPending({bool silent = false}) async {
    if (_isSyncing) return;
    final pending = await OfflineQueueService.count();
    if (pending == 0) {
      if (mounted) setState(() => _pendingCount = 0);
      return;
    }
    if (mounted) setState(() => _isSyncing = true);
    final result = await OfflineQueueService.syncAll();
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _pendingCount = result['remaining'] ?? 0;
    });
    if (!silent || (result['sent'] ?? 0) > 0) {
      final sent = result['sent'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sent > 0
              ? '$sent votante(s) sincronizado(s). Pendientes: ${result['remaining']}'
              : 'Sin conexion. Pendientes: ${result['remaining']}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _checkSuperAdmin() async {
    final user = await AuthService.getUser();
    if (user != null) {
      // El usuario proporcionó el ID 00114865355 como super admin
      if (user['username'] == '00114865355') {
        setState(() {
          _isSuperAdmin = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _cedulaEnlaceController.removeListener(_onCedulaEnlaceChanged);
    _connSub?.cancel();
    super.dispose();
  }

  void _onCedulaEnlaceChanged() async {
    final cedula = _cedulaEnlaceController.text.replaceAll('-', '');
    if (cedula.length == 11) {
      try {
        final url = Uri.parse('$_baseUrl?cedula=$cedula');
        final response = await http.get(url);
        if (response.statusCode == 200 || response.statusCode == 404) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null) {
            final ciudadano = data['data'];
            setState(() {
              _nombreEnlaceController.text = ((ciudadano['nombres'] ?? '') + ' ' + (ciudadano['apellido1'] ?? '') + ' ' + (ciudadano['apellido2'] ?? '')).trim();
              _datosEnlace = ciudadano;
            });
          } else {
            setState(() {
              _nombreEnlaceController.text = '';
              _datosEnlace = null;
            });
          }
        }
      } catch (e) {
        setState(() {
          _nombreEnlaceController.text = '';
          _datosEnlace = null;
        });
      }
    } else {
      setState(() {
        _nombreEnlaceController.text = '';
        _datosEnlace = null;
      });
    }
  }

  bool _isLoading = false;
  bool _isConsulting = false;
  String? _fotoBase64;

  String get _baseUrl => ConfigService.getPadronUrl();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Datos del Ciudadano'),
        backgroundColor: ConfigService.getPrimaryColor(),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // Indicador de votantes pendientes por sincronizar (offline)
          if (_pendingCount > 0 || _isSyncing)
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Tooltip(
                message: 'Pendientes por enviar: $_pendingCount',
                child: InkWell(
                  onTap: _isSyncing ? null : () => _syncPending(),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isSyncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined,
                                color: Colors.white, size: 22),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_pendingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_isSuperAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminSettingsScreen()),
                  ).then((_) => setState(() {}));
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.logout,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              onPressed: () async {
                final bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => Dialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 10,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.exit_to_app_rounded, size: 50, color: Colors.red.shade700),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '¿Cerrar Sesión?',
                            style: TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B), // Navy blue oscuro para contraste
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '¿Estás seguro de que deseas salir del sistema?\nSe cerrará tu sesión actual.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF64748B), // Gris pizarra legible
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(color: Colors.grey.shade300),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancelar', 
                                    style: TextStyle(
                                      color: Color(0xFF475569), // Gris oscuro muy legible
                                      fontSize: 16, 
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444), // Rojo vibrante (SweetAlert style)
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  ),
                                  child: const Text(
                                    'Sí, salir', 
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                if (confirm == true) {
                  await AuthService.logout();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 24),
                    child: child,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Mostrar foto de la cédula si está disponible (posición original)
                    if (_fotoBase64 != null && _fotoBase64!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Center(
                          child: CircleAvatar(
                            radius: 60,
                            backgroundImage: MemoryImage(base64Decode(_fotoBase64!)),
                            backgroundColor: Colors.grey[200],
                          ),
                        ),
                      ),
                // Campo Cédula con botón de escáner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cédula',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.credit_card, color: Colors.blue[300]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _cedulaController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                hintText: '00000000000',
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                suffixIcon: _isConsulting 
                                    ? Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
                                          ),
                                        ),
                                      )
                                    : GestureDetector(
                                        onTap: () async {
                                          await Navigator.push<String?>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CedulaScannerScreen(
                                                onCedulaScanned: (cedula) {
                                                  if (cedula != null) {
                                                    setState(() {
                                                      _cedulaController.text = cedula;
                                                    });
                                                    // ✅ CONSULTA AUTOMÁTICA al escanear
                                                    _consultarPadron(cedula);
                                                  }
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.qr_code_scanner,
                                            color: Colors.teal.shade700,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                              ),
                              onChanged: (value) {
                                if (value.length == 11) {
                                  _consultarPadron(value);
                                }
                              },
                            ),
                          ),
                        ],
                      ), // <-- cierra Row
                    ],   // <-- cierra lista de hijos del Column
                  ),   // <-- cierra Column (del Container)
                  ),     // <-- cierra Container
                const SizedBox(height: 20),

                // === Información Personal ===
                _buildTextField('Nombres', Icons.person, _nombresController),
                const SizedBox(height: 14),
                _buildTextField('Primer Apellido', Icons.person_outline, _primerApellidoController),
                const SizedBox(height: 14),
                _buildTextField('Segundo Apellido', Icons.person_outline, _segundoApellidoController),
                const SizedBox(height: 20),

                // === Contacto ===
                _sectionHeader('Contacto', Icons.contact_phone_rounded),
                const SizedBox(height: 16),
                _buildTextField('Teléfono *', Icons.phone, _telefonoController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 14),
                _buildTextField('Correo (opcional)', Icons.email, _emailController),
                const SizedBox(height: 20),

                // === Información del Enlace ===
                _sectionHeader('Información del Enlace', Icons.link_rounded),
                const SizedBox(height: 16),
                _buildTextField(
                  'Cédula del Enlace (Opcional)',
                  Icons.credit_card,
                  _cedulaEnlaceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _nombreEnlaceController,
                    enabled: false,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person, color: Colors.blue[300]),
                      labelText: 'Nombre del Enlace',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                // Mostrar foto de la cédula si está disponible
                if (_fotoBase64 != null && _fotoBase64!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundImage: MemoryImage(base64Decode(_fotoBase64!)),
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Botón Probar Conectividad (con tus estilos)
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Conexión establecida')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: BorderSide(color: Colors.blue.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Center(
                    child: Text(
                      'Probar Conectividad',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Botón Guardar Datos (con tus estilos)
                ElevatedButton(
                  onPressed: _isLoading ? null : _guardarVotante,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Center(
                          child: Text(
                            'Guardar',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                ],
                  ),
                ),
              ),
            ),
          ),
        // Overlay de Carga (Identidad) en el CENTRO
        if (_isConsulting)
          Container(
            color: Colors.white.withOpacity(0.85),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          strokeWidth: 5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                        ),
                      ),
                      Icon(
                        Icons.fingerprint,
                        size: 70,
                        color: Colors.blue.shade800,
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Text(
                    'VERIFICANDO IDENTIDAD...',
                    style: TextStyle(
                      color: Colors.blue.shade900,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Por favor, espere un momento',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      ),
    );
  }
  // MÉTODOS DE GUARDADO Y LIMPIEZA
  Future<void> _guardarVotante() async {
    if (_cedulaController.text.isEmpty ||
        _telefonoController.text.isEmpty ||
        _nombresController.text.isEmpty ||
        _primerApellidoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete los campos obligatorios'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Construir el mapa solo con los campos que tengan valor
    Map<String, dynamic> voterData = {};
    void addField(String key, dynamic value) {
      if (value != null && value.toString().isNotEmpty) {
        voterData[key] = value;
      }
    }

    addField('cedula', _cedulaController.text.replaceAll('-', ''));
    addField('first_name', _nombresController.text);
    addField('last_name', (_primerApellidoController.text + ' ' + _segundoApellidoController.text).trim());
    addField('phone', _telefonoController.text);
    addField('email', _emailController.text);

    // Foto en formato base64 con prefijo
    if (_fotoBase64 != null && _fotoBase64!.isNotEmpty) {
      addField('photo_path', 'data:image/jpeg;base64,${_fotoBase64!}');
    }

    // Datos del padrón (si existen)
    if (_datosPadron != null) {
      // Mapear campos relevantes del padrón al formato backend
      final padron = _datosPadron!;
      addField('province', padron['provincia']);
      addField('municipio', padron['municipio']);
      addField('birth_date', padron['fecha_nacimiento']);
      addField('sex', padron['sexo']);
      addField('id_provincia', padron['id_provincia']);
      addField('id_municipio', padron['id_municipio']);
      addField('id_estado_civil', padron['id_estado_civil']);
      addField('id_nacionalidad', padron['id_nacionalidad']);
      addField('id_sector_paraje', padron['id_sector_paraje']);
      addField('id_colegio_origen', padron['id_colegio_origen']);
      addField('id_categoria', padron['id_categoria']);
      addField('id_causa_cancelacion', padron['id_causa_cancelacion']);
      addField('id_municipio_origen', padron['id_municipio_origen']);
      addField('id_recinto_origen', padron['id_recinto_origen']);
      addField('id_municipio_exterior', padron['id_municipio_exterior']);
      addField('id_recinto_exterior', padron['id_recinto_exterior']);
      addField('id_colegio_exterior', padron['id_colegio_exterior']);
      addField('categoria', padron['categoria']);
      addField('causa_cancelacion', padron['causa_cancelacion']);
      addField('municipio_origen', padron['municipio_origen']);
      addField('recinto_origen', padron['recinto_origen']);
      addField('codigo_recinto_origen', padron['codigo_recinto_origen']);
      addField('municipio_exterior', padron['municipio_exterior']);
      addField('recinto_exterior', padron['recinto_exterior']);
      addField('colegio_exterior', padron['colegio_exterior']);
      addField('codigo_recinto_exterior', padron['codigo_recinto_exterior']);
      addField('pos_pagina_exterior', padron['pos_pagina_exterior']);
      addField('codigo_circunscripcion', padron['codigo_circunscripcion']);
      addField('codigo_recinto', padron['codigo_recinto']);
      addField('codigo_colegio', padron['codigo_colegio']);
      addField('nombres_plastico', padron['nombres_plastico']);
      addField('apellidos_plastico', padron['apellidos_plastico']);
      addField('sector_paraje', padron['sector_paraje']);
      addField('nacionalidad', padron['nacionalidad']);
      addField('estado_civil', padron['estado_civil']);
      addField('colegio_origen', padron['colegio_origen']);
      addField('pos_pagina', padron['pos_pagina']);
      addField('lugar_votacion', padron['lugar_votacion']);
    }

    // Datos del enlace (si existen)
    if (_cedulaEnlaceController.text.isNotEmpty && _datosEnlace != null) {
      addField('enlace_id', _cedulaEnlaceController.text.replaceAll('-', ''));
      addField('enlace_nombre', _nombreEnlaceController.text);
    }

    try {
      // Obtener token de AuthService
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay sesión activa. Inicie sesión nuevamente.')),
        );
        setState(() { _isLoading = false; });
        return;
      }
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await http.post(
        Uri.parse('${ConfigService.getBaseUrl()}/voters'),
        headers: headers,
        body: jsonEncode(voterData),
      ).timeout(const Duration(seconds: 20));
      final contentType = response.headers['content-type'] ?? '';
      if (response.statusCode == 201 && contentType.contains('application/json')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Votante guardado exitosamente')),
        );
        _limpiarFormulario();
      } else {
        String errorMsg = 'Error desconocido';
        try {
          if (contentType.contains('application/json')) {
            final responseData = jsonDecode(response.body);
            errorMsg = responseData['message'] ?? errorMsg;
            if (responseData['errors'] != null) {
              errorMsg += '\n' + responseData['errors'].toString();
            }
          } else {
            // Mostrar status code y body si no es JSON
            errorMsg = 'Respuesta inesperada del servidor (Status ${response.statusCode}):\n${response.body}';
          }
        } catch (e) {
          errorMsg = 'Respuesta inesperada del servidor (Status ${response.statusCode}):\n${response.body}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $errorMsg')),
        );
      }
    } catch (e) {
      // Fallo de conexion/timeout: guardar offline para enviar al reconectar.
      await OfflineQueueService.enqueue(voterData);
      await _refreshPending();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '📴 Sin conexion: guardado en el telefono. Se enviara al reconectar.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _limpiarFormulario();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _limpiarFormulario() {
    _cedulaController.clear();
    _nombresController.clear();
    _primerApellidoController.clear();
    _segundoApellidoController.clear();
    _telefonoController.clear();
    _emailController.clear();
    _cedulaEnlaceController.clear();
    _nombreEnlaceController.clear();
    setState(() {
      _fotoBase64 = null;
      _datosPadron = null;
      _datosEnlace = null;
    });
  }
}
