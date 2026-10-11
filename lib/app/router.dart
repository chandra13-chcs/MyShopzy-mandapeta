import 'package:flutter/material.dart';

import '../features/auth/presentation/phone_entry_page.dart';
import '../features/home/presentation/home_page.dart';

class AppRouter {
  static const phoneEntry = '/';
  static const home = '/home';

  static Map<String, WidgetBuilder> get routes => {
    phoneEntry: (_) => const PhoneEntryPage(),
    home: (_) => const HomePage(),
  };
}
