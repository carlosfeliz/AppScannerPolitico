import 'package:flutter/material.dart';
import 'services/config_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigService.init();
  runApp(const CapturasApp());
}

class CapturasApp extends StatelessWidget {
  const CapturasApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primary = ConfigService.getPrimaryColor();
    return MaterialApp(
      title: 'Capturas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: ConfigService.getButtonColor(),
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}