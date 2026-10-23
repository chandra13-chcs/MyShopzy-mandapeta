import 'package:flutter/material.dart';

import '../features/auth/presentation/landing_page.dart';
import '../features/auth/presentation/login_page.dart';
import 'main_navigation_shell.dart';

class AppRouter {
  static const welcome = '/welcome';
  static const phoneEntry = '/login';
  static const home = '/home';
  static const registration = '/register';
  static const forgotPassword = '/forgot-password';

  static Map<String, WidgetBuilder> get routes => {
    welcome: (_) => const LandingPage(),
    phoneEntry: (_) => const LoginPage(),
    home: (_) => const MainNavigationShell(),
    registration: (_) => const LoginPage(),
    forgotPassword: (_) => const LoginPage(),
  };
}
