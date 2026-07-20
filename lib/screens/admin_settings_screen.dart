import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/config_service.dart';
import 'org_screen.dart';

/// Ajustes avanzados (solo super admin). El branding y las URLs se configuran
/// automaticamente al elegir la organizacion; esta pantalla permite un override
/// manual de las URLs y volver a elegir organizacion.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _padronUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _baseUrlController.text = ConfigService.getBaseUrl();
    _padronUrlController.text = ConfigService.getPadronUrl();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _padronUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    await ConfigService.setBaseUrl(_baseUrlController.text.trim());
    await ConfigService.setPadronUrl(_padronUrlController.text.trim());
    Fluttertoast.showToast(msg: 'Configuracion guardada');
    if (mounted) Navigator.pop(context);
  }

  Future<void> _changeOrg() async {
    await ConfigService.clearTenant();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OrgScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = ConfigService.getPrimaryColor();
    final tenantName = ConfigService.getTenantName();
    final slug = ConfigService.getTenantSlug();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion Avanzada'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              color: primary.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: Icon(Icons.apartment_rounded, color: primary),
                title: Text(
                  tenantName.isEmpty ? 'Sin organizacion' : tenantName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(slug.isEmpty ? '-' : slug),
                trailing: TextButton(
                  onPressed: _changeOrg,
                  child: const Text('Cambiar'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Override manual de URLs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'Normalmente no hace falta tocarlas: se configuran solas al elegir la organizacion.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL API',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _padronUrlController,
              decoration: const InputDecoration(
                labelText: 'Padron URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('GUARDAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
