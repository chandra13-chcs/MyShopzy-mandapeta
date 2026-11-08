import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/translations.dart';
import '../services/auth_service.dart';
import '../services/kyc_service.dart';
import '../services/rider_controller.dart';
import 'kyc_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';

/// First screen shown when the app opens. Shows the logo for a moment
/// while it checks if a rider is already signed in on this phone, then
/// sends them to the right place.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final auth = context.read<AuthService>();
    final rider = context.read<RiderController>();
    final kyc = context.read<KycService>();
    await auth.loadSavedRider();
    await rider.load();
    if (auth.isLoggedIn) await kyc.load();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => !auth.isLoggedIn
            ? const LoginScreen()
            : kyc.isApproved
                ? const HomeScreen()
                : const KycScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9480F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delivery_dining, color: Colors.white, size: 72),
            const SizedBox(height: 12),
            Text(
              T.t('app_name'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              T.t('splash_tagline'),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
