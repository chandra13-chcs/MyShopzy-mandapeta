import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_strings.dart';
import 'services/auth_service.dart';
import 'services/kyc_service.dart';
import 'services/mock_kyc_service.dart';
import 'services/rider_controller.dart';
import 'screens/splash_screen.dart';
import 'utils/nav.dart';
import 'widgets/incoming_order_overlay.dart';
import 'widgets/no_internet_banner.dart';

void main() {
  runApp(const MyShopzyRiderApp());
}

const _brand = Color(0xFFD9480F);

class MyShopzyRiderApp extends StatelessWidget {
  const MyShopzyRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        // To use a real backend later: RiderController(repository: ApiOrderRepository())
        ChangeNotifierProvider(create: (_) => RiderController()),
        ChangeNotifierProvider(
          create: (context) => KycService(
            repository: MockKycService(),
            riderController: context.read<RiderController>(),
          ),
        ),
      ],
      // Only rebuild the app shell when the theme choice changes.
      child: Selector<RiderController, ThemeMode>(
        selector: (_, c) => c.themeMode,
        builder: (context, mode, _) => MaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: ThemeData(colorSchemeSeed: _brand, useMaterial3: true),
          darkTheme: ThemeData(
              colorSchemeSeed: _brand,
              brightness: Brightness.dark,
              useMaterial3: true),
          themeMode: mode,
          // The new-order popup and the no-internet strip sit above every screen.
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [
              child ?? const SizedBox.shrink(),
              const IncomingOrderOverlay(),
              const NoInternetBanner(),
            ],
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
