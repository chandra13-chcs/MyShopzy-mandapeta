import 'package:flutter/material.dart';

import 'main_navigation_shell.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class MyShopzyApp extends StatelessWidget {
  const MyShopzyApp({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyShopzy',
      theme: AppTheme.light,
      home: MainNavigationShell(clock: clock),
      routes: AppRouter.routes,
    );
  }
}
