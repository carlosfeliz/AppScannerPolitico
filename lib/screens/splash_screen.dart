import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/config_service.dart';
import '../widgets/brand_logo.dart';
import 'login_screen.dart';
import 'main_form_screen.dart';
import 'org_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _decideNext();
  }

  Future<void> _decideNext() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    // Sin organizacion configurada -> pantalla de organizacion.
    if (!ConfigService.hasTenant()) {
      _go(const OrgScreen());
      return;
    }

    // El almacenamiento seguro puede fallar o tardar (llave corrupta tras
    // actualizar la app). Nunca dejar el splash colgado: ante cualquier
    // problema se va al login.
    bool authed = false;
    try {
      authed = await AuthService.isAuthenticated()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      try {
        await AuthService.clearLocalSession();
      } catch (_) {}
    }
    if (!mounted) return;
    _go(authed ? const MainFormScreen() : const LoginScreen());
  }

  void _go(Widget screen) {
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Splash neutro: todavia no se ha entrado a ninguna organizacion, asi que
    // no se muestra su nombre, logo ni colores. Eso se aplica despues.
    const primary = ConfigService.fallbackPrimary;
    final secondary = Color.lerp(primary, Colors.black, 0.35) ?? primary;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primary, secondary],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BrandLogo(size: 160, platformOnly: true),
                  const SizedBox(height: 36),
                  const Text(
                    'SISELECT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CAPTURAS',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
