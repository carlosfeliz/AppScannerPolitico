import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vibration/vibration.dart';

class CedulaScannerScreen extends StatefulWidget {
  final Function(String? cedula) onCedulaScanned;

  const CedulaScannerScreen({Key? key, required this.onCedulaScanned})
      : super(key: key);

  @override
  State<CedulaScannerScreen> createState() => _CedulaScannerScreenState();
}

class _CedulaScannerScreenState extends State<CedulaScannerScreen> {
  late CameraController _controller;
  late final TextRecognizer _textRecognizer;
  bool _isScanning = false;
  Timer? _scanTimer;
  Color _frameColor = Colors.red;
  double _frameWidth = 4.0;

  @override
  void initState() {
    super.initState();
    _textRecognizer = GoogleMlKit.vision.textRecognizer();
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
      Future.delayed(const Duration(seconds: 2), _startAutoScan);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error al iniciar cámara: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  void _startAutoScan() {
    if (_isScanning) return;
    _isScanning = true;
    _scanTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_controller.value.isInitialized || _controller.value.isTakingPicture) return;
      await _scanText();
    });
  }

  Future<void> _scanText() async {
    try {
      final file = await _controller.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final cedula = _extractCedula(recognizedText.text);
      if (cedula != null) {
        _showSuccessEffect(cedula);
      }
      // No mostramos toast si no es válida (evitamos ruido)
    } catch (e) {
      print('OCR error: $e');
    }
  }

  String? _extractCedula(String text) {
    final regExp = RegExp(r'\b\d{3}-\d{7}-\d\b');
    final match = regExp.firstMatch(text);
    if (match != null) {
      return match.group(0)!.replaceAll('-', '');
    }
    return null;
  }

  bool _validateCedula(String cedula) {
    if (cedula.length != 11) return false;
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
  }

  Future<void> _showSuccessEffect(String cedula) async {
    setState(() {
      _frameColor = Colors.green;
      _frameWidth = 6.0;
    });

    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 300);
    }

    Fluttertoast.showToast(
      msg: '✅ Cédula detectada: $cedula',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: Colors.black.withOpacity(0.8),
      textColor: Colors.white,
    );

    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _frameColor = Colors.red;
      _frameWidth = 4.0;
    });

    // ✅ IMPORTANTE: Solo devolvemos la cédula y cerramos
    widget.onCedulaScanned(cedula);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _controller.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 250),
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
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'COLOQUE CÉDULA AQUÍ',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '15-20 CM',
                    style: TextStyle(color: Colors.yellow, fontSize: 14),
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
                'LEYENDO AUTOMÁTICAMENTE',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}