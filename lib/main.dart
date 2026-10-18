import 'package:flutter/material.dart';

import 'app/router.dart';
import 'app/theme/app_theme.dart';
import 'features/auth/presentation/landing_page.dart';
import 'features/home/presentation/home_page.dart';
import 'shared/data/customer_api.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyShopzy',
      theme: AppTheme.light,
      home: CustomerApi.instance.hasCustomerSession
          ? HomePage()
          : const LandingPage(),
      routes: AppRouter.routes,
    ),
  );
}