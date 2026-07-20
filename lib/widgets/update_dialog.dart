import 'package:flutter/material.dart';

import '../services/config_service.dart';
import '../services/update_service.dart';

/// Aviso de actualizacion disponible.
///
/// Si la actualizacion es obligatoria no se puede cerrar: ni con el boton
/// atras, ni tocando fuera, ni con un boton "Despues". Eso ocurre cuando la
/// version instalada quedo por debajo del minimo que acepta el servidor, tipico
/// tras un cambio en la API que la romperia.
class UpdateDialog extends StatefulWidget {
  final UpdateInfo update;

  const UpdateDialog({super.key, required this.update});

  static Future<void> show(BuildContext context, UpdateInfo update) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !update.mandatory,
      builder: (_) => UpdateDialog(update: update),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double? _progress;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _downloading = true;
      _error = null;
    });

    final error = await UpdateService.downloadAndInstall(
      widget.update,
      onProgress: (p) => mounted ? setState(() => _progress = p) : null,
    );

    if (!mounted) return;
    setState(() {
      _downloading = false;
      _error = error;
    });

    // Sin error, Android ya mostro su instalador encima. El dialogo se queda
    // detras a proposito: si el usuario cancela la instalacion, sigue viendo
    // el aviso (y si era obligatoria, sigue sin poder pasar).
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.update;
    final primary = ConfigService.getPrimaryColor();

    return PopScope(
      canPop: !u.mandatory,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(u.mandatory ? Icons.warning_amber_rounded : Icons.system_update,
                color: primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                u.mandatory ? 'Actualizacion requerida' : 'Actualizacion disponible',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              u.mandatory
                  ? 'Esta version ya no es compatible con el sistema. Debe '
                      'actualizar para continuar usando la aplicacion.'
                  : 'Hay una version nueva disponible (${u.displayVersion}).',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            if (u.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(u.notes, style: const TextStyle(fontSize: 13)),
              ),
            ],
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text(
                _progress == null
                    ? 'Descargando...'
                    : 'Descargando ${(_progress! * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(fontSize: 12, color: Colors.red)),
            ],
            if (!_downloading && _error == null) ...[
              const SizedBox(height: 12),
              const Text(
                'Al instalar, Android puede pedirle permiso para instalar '
                'aplicaciones de esta fuente. Es normal: solo hay que '
                'autorizarlo una vez.',
                style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
              ),
            ],
          ],
        ),
        actions: [
          if (!u.mandatory && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Despues'),
            ),
          ElevatedButton(
            onPressed: _downloading ? null : _install,
            style: ElevatedButton.styleFrom(
              backgroundColor: ConfigService.getButtonColor(),
              foregroundColor: Colors.white,
            ),
            child: Text(_error != null ? 'Reintentar' : 'Actualizar'),
          ),
        ],
      ),
    );
  }
}
