import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/translations.dart';
import '../services/connectivity_service.dart';

/// A red strip at the top of every screen while the device is offline.
/// Connectivity checks are shared with repository failures and retried every
/// 10 seconds; the mock data still works without a network connection.
class NoInternetBanner extends StatefulWidget {
  const NoInternetBanner({super.key});

  @override
  State<NoInternetBanner> createState() => _NoInternetBannerState();
}

class _NoInternetBannerState extends State<NoInternetBanner> {
  final _connectivity = ConnectivityService.instance;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(seconds: 10), (_) => unawaited(_connectivity.check()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _connectivity,
      builder: (context, _) {
        if (_connectivity.isOnline) return const SizedBox.shrink();
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.red.shade700,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        T.t('no_internet'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: _connectivity.isChecking
                          ? null
                          : () => unawaited(_connectivity.check()),
                      child: _connectivity.isChecking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              T.t('retry'),
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
