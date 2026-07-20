import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/config_service.dart';

/// Logo del tenant activo. Muestra el logo de red (branding) si existe; si no,
/// un icono neutro. No depende de assets clavados de ningun cliente.
class BrandLogo extends StatelessWidget {
  final double size;
  final Color? fallbackColor;

  const BrandLogo({Key? key, this.size = 120, this.fallbackColor})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final logoUrl = ConfigService.getLogoUrl();
    final fallback = _fallback(context);

    if (logoUrl.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: logoUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholder: (_, __) => SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
        ),
      ),
      errorWidget: (_, __, ___) => fallback,
    );
  }

  // Marca por defecto de la plataforma (Siselect) cuando el tenant aun no tiene
  // logo propio. Va sobre una tarjeta blanca para ser legible en cualquier fondo.
  Widget _fallback(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: size * 0.16, vertical: size * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/Siseleto.png',
        width: size * 1.5,
        fit: BoxFit.contain,
      ),
    );
  }
}
