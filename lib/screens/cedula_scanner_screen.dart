import 'dart:async';
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
  late CameraController _controller;
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
      _controller = CameraController(camera, ResolutionPreset.high);
      await _controller.initialize();
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
      if (!_controller.value.isInitialized || _controller.value.isTakingPicture || _isProcessing) return;
      await _scanTextAndBarcode();
    });
  }

  Future<void> _scanTextAndBarcode() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final file = await _controller.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);

      // 1. Intentar escaneo de código de barras (PDF417 en el reverso de la cédula)
      final barcodes = await _barcodeScanner.processImage(inputImage);
      for (final barcode in barcodes) {
        final rawValue = barcode.rawValue ?? '';
        final cedulaFromBarcode = _extractCedulaFromText(rawValue);
        if (cedulaFromBarcode != null && _validateCedula(cedulaFromBarcode)) {
          _isScanning = false;
          await _showSuccessEffect(cedulaFromBarcode);
          return;
        }
      }

      // 2. Intentar reconocimiento de texto OCR (Frente de la cédula)
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final cedulaFromText = _extractCedulaFromText(recognizedText.text);
      if (cedulaFromText != null && _validateCedula(cedulaFromText)) {
        _isScanning = false;
        await _showSuccessEffect(cedulaFromText);
        return;
      }
    } catch (e) {
      print('Scanner error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  String? _extractCedulaFromText(String rawText) {
    if (rawText.isEmpty) return null;

    // Normalizar texto convirtiendo caracteres ambiguos comunes de OCR
    String cleanText = rawText
        .replaceAll('O', '0')
        .replaceAll('o', '0')
        .replaceAll('I', '1')
        .replaceAll('l', '1')
        .replaceAll('|', '1')
        .replaceAll('S', '5')
        .replaceAll('s', '5')
        .replaceAll('B', '8');

    // 1. Expresión regular flexible para XXX-XXXXXXX-X o XXX XXXXXXX X
    final regExpWithFormat = RegExp(r'\b\d{3}[-\s.]?\d{7}[-\s.]?\d\b');
    final matches = regExpWithFormat.allMatches(cleanText);

    for (final match in matches) {
      final digitsOnly = match.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length == 11 && _validateCedula(digitsOnly)) {
        return digitsOnly;
      }
    }

    // 2. Buscar cualquier secuencia de 11 dígitos continuos en el texto
    final regExpDigits = RegExp(r'\d{11}');
    final digitMatches = regExpDigits.allMatches(cleanText.replaceAll(RegExp(r'[^\d]'), ''));
    for (final match in digitMatches) {
      final candidate = match.group(0)!;
      if (candidate.length == 11 && _validateCedula(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  // Algoritmo oficial de validación Luhn / Módulo 10 (JCE República Dominicana)
  bool _validateCedula(String cedula) {
    if (cedula.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cedula)) return false; // Descartar números repetidos como 00000000000

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
    } catch (_) {
      return false;
    }
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
    _controller.dispose();
    _textRecognizer.close();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
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
          CameraPreview(_controller),

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