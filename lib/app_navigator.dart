import 'package:flutter/material.dart';

/// Llaves globales para poder navegar y mostrar avisos desde los servicios
/// (por ejemplo, al expirar la sesion), donde no hay un BuildContext a mano.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
