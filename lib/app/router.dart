import 'package:flutter/material.dart';

import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/phone_entry_page.dart';
import '../features/auth/presentation/registration_page.dart';
import '../features/auth/presentation/welcome_page.dart';
import '../features/home/presentation/home_page.dart';

class AppRouter {
  static const welcome = '/';
  static const phoneEntry = '/login';
  static const home = '/home';
  static const registration = '/register';
  static const forgotPassword = '/forgot-password';

  static Map<String, WidgetBuilder> get routes => {
    welcome: (_) => const WelcomePage(),
    phoneEntry: (_) => const PhoneEntryPage(),
    home: (_) => const HomePage(),
    registration: (_) => const RegistrationPage(),
    forgotPassword: (_) => const ForgotPasswordPage(),
  };
}
