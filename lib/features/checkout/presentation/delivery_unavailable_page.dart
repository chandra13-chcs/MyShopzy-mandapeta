import 'package:flutter/material.dart';

import '../../../app/main_navigation_shell.dart';
import '../../../app/theme/app_theme.dart';

class ServiceabilityUnavailablePage extends StatelessWidget {
  const ServiceabilityUnavailablePage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final detail = message.trim().isEmpty
        ? 'Instamart is unavailable in your location. Please revisit after a while.'
        : message;
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 216,
                        height: 216,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE6EFF6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_city_rounded,
                          size: 112,
                          color: Color(0xFF9BB8CB),
                        ),
                      ),
                      const SizedBox(height: 42),
                      const Text(
                        'Sorry! We don’t deliver here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.primaryText,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        detail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 16,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 230,
                        height: 52,
                        child: FilledButton(
                          key: const ValueKey('change-delivery-location'),
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1557E8),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Change Location'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: TextButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const MainNavigationShell(),
                  ),
                  (route) => false,
                ),
                child: const Text('Browse Products'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
