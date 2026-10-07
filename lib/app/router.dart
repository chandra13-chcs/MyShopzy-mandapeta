import 'package:flutter/material.dart';

import '../features/home/presentation/home_page.dart';

class AppRouter {
  static const home = '/';

  static Map<String, WidgetBuilder> get routes => {
    home: (_) => const HomePage(),
  };
}
