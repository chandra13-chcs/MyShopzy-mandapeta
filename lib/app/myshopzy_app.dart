import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class MyShopzyApp extends StatelessWidget {
  const MyShopzyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyShopzy',
      theme: AppTheme.light,
      routes: AppRouter.routes,
    );
  }
}
