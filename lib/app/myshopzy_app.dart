import 'package:flutter/material.dart';

import '../features/home/presentation/home_page.dart';
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
      home: const HomePage(),
      routes: AppRouter.routes,
    );
  }
}
