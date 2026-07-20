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

  Widget _fallback(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 2),
      ),
      child: Icon(
        Icons.how_to_vote_rounded,
        size: size * 0.5,
        color: fallbackColor ?? Colors.white,
      ),
    );
  }
}
