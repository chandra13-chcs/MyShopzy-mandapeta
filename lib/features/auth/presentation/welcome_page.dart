import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_visuals.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const _green = Color(0xFF006633);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _green,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _green,
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = constraints.maxHeight;
              final isCompact = screenHeight < 680;
              final heroHeight = screenHeight * (isCompact ? 0.57 : 0.59);
              final overlap = isCompact ? 22.0 : 30.0;

              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: heroHeight,
                    child: Image.asset(
                      'assets/category_tiles/myshopzy_welcome.png',
                      key: const ValueKey('welcome-banner'),
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.08),
                      semanticLabel:
                          'MyShopzy, Smart Shopping, Fast Delivery',
                    ),
                  ),
                  Positioned(
                    top: heroHeight - overlap,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _WelcomeActionPanel(
                      compact: isCompact,
                      onLogin: () =>
                          Navigator.of(context).pushNamed('/login'),
                      onSignUp: () =>
                          Navigator.of(context).pushNamed('/register'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WelcomeActionPanel extends StatelessWidget {
  const _WelcomeActionPanel({
    required this.compact,
    required this.onLogin,
    required this.onSignUp,
  });

  static const _green = Color(0xFF006633);
  static const _yellow = Color(0xFFFFC900);

  final bool compact;
  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: const Color(0x33001A0D),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(26, compact ? 34 : 46, 26, 20),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: compact ? 54 : 60,
              child: FilledButton(
                key: const ValueKey('welcome-login'),
                onPressed: onLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: const Color(0x33001A0D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SizedBox(height: compact ? 14 : 18),
            SizedBox(
              width: double.infinity,
              height: compact ? 54 : 60,
              child: FilledButton(
                key: const ValueKey('welcome-signup'),
                onPressed: onSignUp,
                style: FilledButton.styleFrom(
                  backgroundColor: _yellow,
                  foregroundColor: AuthPalette.darkGreen,
                  elevation: 3,
                  shadowColor: const Color(0x33001A0D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const Spacer(),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: _yellow,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
