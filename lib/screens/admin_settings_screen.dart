import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/config_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _padronUrlController = TextEditingController();
  final _logoPathController = TextEditingController();
  Color _primaryColor = Colors.blue;
  Color _secondaryColor = Colors.blueAccent;

  @override
  void initState() {
    super.initState();
    _baseUrlController.text = ConfigService.getBaseUrl();
    _padronUrlController.text = ConfigService.getPadronUrl();
    _logoPathController.text = ConfigService.getLogoPath();
    _primaryColor = ConfigService.getPrimaryColor();
    _secondaryColor = ConfigService.getSecondaryColor();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _padronUrlController.dispose();
    _logoPathController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    await ConfigService.setBaseUrl(_baseUrlController.text.trim());
    await ConfigService.setPadronUrl(_padronUrlController.text.trim());
    await ConfigService.setLogoPath(_logoPathController.text.trim());
    await ConfigService.setPrimaryColor('0x${_primaryColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}');
    await ConfigService.setSecondaryColor('0x${_secondaryColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}');

    Fluttertoast.showToast(msg: 'Configuración guardada exitosamente. Reinicie la app para aplicar todos los cambios.');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Administrador'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('URLs de API', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL API',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _padronUrlController,
              decoration: const InputDecoration(
                labelText: 'Padron URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Imagen y Logo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _logoPathController,
              decoration: const InputDecoration(
                labelText: 'Asset Path Logo (e.g. assets/images/logoyayo.png)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Colores de Marca', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListTile(
              title: const Text('Color Primario'),
              trailing: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: _primaryColor, shape: BoxShape.circle),
              ),
              onTap: () async {
                // Simplified color picker or just preset selection for now
                _showColorPicker((color) => setState(() => _primaryColor = color));
              },
            ),
            ListTile(
              title: const Text('Color Secundario'),
              trailing: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: _secondaryColor, shape: BoxShape.circle),
              ),
              onTap: () async {
                _showColorPicker((color) => setState(() => _secondaryColor = color));
              },
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('GUARDAR CONFIGURACIÓN'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(Function(Color) onColorSelected) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Color'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _colorOption(Colors.blue, onColorSelected),
            _colorOption(const Color(0xFF1E3A8A), onColorSelected),
            _colorOption(Colors.red, onColorSelected),
            _colorOption(Colors.green, onColorSelected),
            _colorOption(Colors.orange, onColorSelected),
            _colorOption(Colors.purple, onColorSelected),
            _colorOption(Colors.black, onColorSelected),
            _colorOption(Colors.indigo, onColorSelected),
          ],
        ),
      ),
    );
  }

  Widget _colorOption(Color color, Function(Color) onColorSelected) {
    return InkWell(
      onTap: () {
        onColorSelected(color);
        Navigator.pop(context);
      },
      child: Container(
        width: 50,
        height: 50,
        color: color,
      ),
    );
  }
}
