import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Lee el codigo QR que la organizacion genera desde su panel y devuelve el
/// slug y la clave, para que el capturista no tenga que escribirlos.
///
/// El contenido del QR es `siselect://config?slug=xxx&key=yyy`, generado por
/// `MobileAppRelease::qrPayload()` en el backend.
class QrConfigScannerScreen extends StatefulWidget {
  const QrConfigScannerScreen({Key? key}) : super(key: key);

  @override
  State<QrConfigScannerScreen> createState() => _QrConfigScannerScreenState();
}

class _QrConfigScannerScreenState extends State<QrConfigScannerScreen> {
  CameraController? _camera;
  final _scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);

  bool _procesando = false;
  bool _listo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _iniciarCamara();
  }

  Future<void> _iniciarCamara() async {
    try {
      final camaras = await availableCameras();
      final trasera = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );

      final ctrl = CameraController(
        trasera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await ctrl.initialize();
      if (!mounted) return;

      setState(() {
        _camera = ctrl;
        _listo = true;
      });

      await ctrl.startImageStream(_procesarFotograma);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir la camara: $e');
    }
  }

  Future<void> _procesarFotograma(CameraImage imagen) async {
    // Un solo fotograma a la vez: el analisis tarda mas que la captura y sin
    // este candado se encolarian decenas de imagenes y la camara se congelaria.
    if (_procesando || !mounted) return;
    _procesando = true;

    try {
      final input = _convertir(imagen);
      if (input == null) return;

      final codigos = await _scanner.processImage(input);
      for (final c in codigos) {
        final datos = _interpretar(c.rawValue);
        if (datos != null && mounted) {
          await _camera?.stopImageStream();
          if (mounted) Navigator.of(context).pop(datos);
          return;
        }
      }
    } catch (_) {
      // Un fotograma ilegible es normal; se sigue con el siguiente.
    } finally {
      _procesando = false;
    }
  }

  InputImage? _convertir(CameraImage imagen) {
    final camara = _camera;
    if (camara == null) return null;

    final bytes = imagen.planes.first.bytes;
    final formato = InputImageFormatValue.fromRawValue(imagen.format.raw);
    if (formato == null) return null;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(imagen.width.toDouble(), imagen.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(
                camara.description.sensorOrientation) ??
            InputImageRotation.rotation0deg,
        format: formato,
        bytesPerRow: imagen.planes.first.bytesPerRow,
      ),
    );
  }

  /// Extrae slug y clave del contenido del QR. Devuelve null si el codigo no
  /// es de configuracion (el usuario pudo apuntar a cualquier otro QR).
  Map<String, String>? _interpretar(String? valor) {
    if (valor == null || valor.isEmpty) return null;

    final uri = Uri.tryParse(valor);
    if (uri == null || uri.scheme != 'siselect' || uri.host != 'config') {
      return null;
    }

    final slug = uri.queryParameters['slug']?.trim() ?? '';
    final key = uri.queryParameters['key']?.trim() ?? '';
    if (slug.isEmpty || key.isEmpty) return null;

    return {'slug': slug, 'key': key};
  }

  @override
  void dispose() {
    _camera?.dispose();
    _scanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear codigo'),
        elevation: 0,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          : !_listo || _camera == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    CameraPreview(_camera!),
                    // Marco guia: ayuda a encuadrar y deja claro que se espera
                    // un codigo, no una foto.
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    Positioned(
                      bottom: 48,
                      left: 28,
                      right: 28,
                      child: Text(
                        'Apunte al codigo QR que aparece en el panel de su organizacion',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
