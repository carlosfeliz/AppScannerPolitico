import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vibration/vibration.dart';

class CedulaScannerScreen extends StatefulWidget {
  final Function(String? cedula) onCedulaScanned;

  const CedulaScannerScreen({super.key, required this.onCedulaScanned});

  @override
  State<CedulaScannerScreen> createState() => _CedulaScannerScreenState();
}

class _CedulaScannerScreenState extends State<CedulaScannerScreen> {
  CameraController? _controller;
  late final TextRecognizer _textRecognizer;
  late final BarcodeScanner _barcodeScanner;
  bool _isScanning = false;
  bool _isProcessing = false;
  Timer? _scanTimer;
  Color _frameColor = Colors.red;
  double _frameWidth = 4.0;

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _barcodeScanner = BarcodeScanner(formats: [
      BarcodeFormat.pdf417,
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
    ]);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        Fluttertoast.showToast(msg: 'No se encontró cámara');
        if (mounted) Navigator.pop(context);
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras[0],
      );
      _controller = CameraController(
        camera,
        ResolutionPreset.max, // texto chico/gris de la cédula nueva necesita píxeles
        enableAudio: false,
      );
      await _controller!.initialize();
      try {
        await _controller!.setFlashMode(FlashMode.off);
        await _controller!.setFocusMode(FocusMode.auto);
        await _controller!.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      if (!mounted) return;
      setState(() {});
      Future.delayed(const Duration(seconds: 1), _startAutoScan);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error al iniciar cámara: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  void _startAutoScan() {
    if (_isScanning) return;
    _isScanning = true;
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isTakingPicture || _isProcessing) return;
      await _scanTextAndBarcode();
    });
  }


  /// Convierte a gris, normaliza y sube el contraste. Ayuda con el número
  /// gris sobre fondo lila claro de la cédula nueva. Corre en un isolate.
  static String? _enhanceInIsolate(String path) {
    try {
      final bytes = File(path).readAsBytesSync();
      var image = img.decodeImage(bytes);
      if (image == null) return null;
      image = img.bakeOrientation(image);
      if (image.width > 2200) image = img.copyResize(image, width: 2200);
      image = img.grayscale(image);
      image = img.normalize(image, min: 0, max: 255);
      image = img.adjustColor(image, contrast: 1.7);
      final out = '$path.enh.jpg';
      File(out).writeAsBytesSync(img.encodeJpg(image, quality: 92));
      return out;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _extractFrom(InputImage input) async {
    final barcodes = await _barcodeScanner.processImage(input);
    for (final b in barcodes) {
      final c = _extractCedulaFromText(b.rawValue ?? '');
      if (c != null) return c;
    }
    final text = await _textRecognizer.processImage(input);
    return _extractCedulaFromText(text.text);
  }

  Future<void> _scanTextAndBarcode() async {
    if (_isProcessing) return;
    _isProcessing = true;
    String? enhancedPath;
    try {
      final file = await _controller!.takePicture();

      // 1. Imagen original: PDF417 (reverso) y OCR (cédula vieja, número grande).
      String? cedula = await _extractFrom(InputImage.fromFilePath(file.path));

      // 2. Si no salió, versión con contraste reforzado (cédula nueva, gris).
      if (cedula == null) {
        enhancedPath = await compute(_enhanceInIsolate, file.path);
        if (enhancedPath != null) {
          cedula = await _extractFrom(InputImage.fromFilePath(enhancedPath));
        }
      }

      if (cedula != null) {
        _isScanning = false;
        await _showSuccessEffect(cedula);
        return;
      }
    } catch (e) {
      debugPrint('Scanner error: $e');
    } finally {
      _isProcessing = false;
      if (enhancedPath != null) {
        try { File(enhancedPath).deleteSync(); } catch (_) {}
      }
    }
  }

  String? _lastCandidate;
  int _candidateHits = 0;

  /// Extrae una cédula (formato 001-0000000-9) de un texto OCR/PDF417.
  /// Sirve para la cédula vieja y la nueva (ambas imprimen 3-7-1 dígitos).
  /// - Si pasa el dígito verificador: se acepta de inmediato.
  /// - Si no pasa (hay cédulas reales que no lo cumplen o el OCR erró un
  ///   dígito): solo se acepta si trae guiones y se lee igual 2 veces seguidas.
  String? _extractCedulaFromText(String rawText) {
    if (rawText.isEmpty) return null;

    // Permite letras que el OCR confunde con dígitos SOLO dentro del número.
    final re = RegExp(
      r'(?<![0-9A-Za-z])([0-9OoIl|]{3})([\s.\-]{0,2})([0-9OoIl|]{7})([\s.\-]{0,2})([0-9OoIl])(?![0-9A-Za-z])',
    );

    String? formattedFallback;
    for (final m in re.allMatches(rawText)) {
      final digits = (m.group(1)! + m.group(3)! + m.group(5)!)
          .replaceAll(RegExp(r'[Oo]'), '0')
          .replaceAll(RegExp(r'[Il|]'), '1');
      if (digits.length != 11) continue;
      if (_validateCedula(digits)) {
        _lastCandidate = null;
        _candidateHits = 0;
        return digits;
      }
      final hasDashes = m.group(2)!.contains('-') && m.group(4)!.contains('-');
      if (hasDashes && !RegExp(r'^(\d)\1{10}$').hasMatch(digits)) {
        formattedFallback ??= digits;
      }
    }

    if (formattedFallback != null) {
      if (_lastCandidate == formattedFallback) {
        _candidateHits++;
      } else {
        _lastCandidate = formattedFallback;
        _candidateHits = 1;
      }
      if (_candidateHits >= 2) {
        _lastCandidate = null;
        _candidateHits = 0;
        return formattedFallback;
      }
    }
    return null;
  }

  // Dígito verificador JCE: pesos 1,2,1,2,... sobre los primeros 10 dígitos.
  bool _validateCedula(String cedula) {
    if (cedula.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cedula)) return false;
    final digits = cedula.split('').map(int.tryParse).toList();
    if (digits.any((d) => d == null)) return false;
    int sum = 0;
    for (int i = 0; i < 10; i++) {
      int v = digits[i]! * (i % 2 == 0 ? 1 : 2);
      if (v > 9) v -= 9;
      sum += v;
    }
    return (10 - (sum % 10)) % 10 == digits[10];
  }

  Future<void> _showSuccessEffect(String cedula) async {
    _scanTimer?.cancel();
    if (mounted) {
      setState(() {
        _frameColor = Colors.green;
        _frameWidth = 6.0;
      });
    }

    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 300);
      }
    } catch (_) {}

    Fluttertoast.showToast(
      msg: '✅ Cédula detectada: $cedula',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      textColor: Colors.white,
    );

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      widget.onCedulaScanned(cedula);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _controller?.dispose();
    _textRecognizer.close();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Lector Automático de Cédula'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),

          // Marco guía (proporción de cédula)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 220),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _frameColor, width: _frameWidth),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ENFOQUE CÉDULA (FRENTE O REVERSO)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Soporta OCR y Código de Barras PDF417',
                    style: TextStyle(color: Colors.yellow, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'ESCANEO AUTOMÁTICO ACTIVO',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}