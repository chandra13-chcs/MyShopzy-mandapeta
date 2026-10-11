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
              final heroHeight = AuthBrandBanner.heightForViewport(
                constraints.maxWidth,
                screenHeight,
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    height: heroHeight,
                    child: Image.asset(
                      AuthBrandBanner.assetPath,
                      key: const ValueKey('welcome-banner'),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      alignment: Alignment.topCenter,
                      semanticLabel:
                          'MyShopzy, Smart Shopping, Fast Delivery',
                    ),
                  ),
                  Positioned(
                    top: heroHeight + 8,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _WelcomeActionPanel(
                      compact: isCompact,
                      onLogin: () => Navigator.of(context).pushNamed('/login'),
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
  const _WelcomeActionPanel({required this.compact, required this.onLogin});

  static const _green = Color(0xFF006633);

  final bool compact;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: const Color(0x33001A0D),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(26, compact ? 18 : 22, 26, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Text(
              'Welcome back,',
              key: ValueKey('welcome-back-message'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AuthPalette.darkGreen,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
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
            const AuthLegalLinks(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AuthPalette.yellow,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    'Smart Shopping  •  Fast Delivery',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AuthPalette.darkGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 22,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AuthPalette.yellow,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
