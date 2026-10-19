import 'package:flutter/material.dart';

import '../data/customer_api.dart';

bool isOfflineApiError(Object? error) =>
    error is CustomerApiException &&
    (error.code == 'NETWORK_ERROR' || error.code == 'REQUEST_TIMEOUT');

class OfflineErrorState extends StatelessWidget {
  const OfflineErrorState({
    required this.onRetry,
    super.key,
    this.compact = false,
  });

  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 12 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFF59615C),
              size: 28,
            ),
            const SizedBox(height: 8),
            const Text(
              'No internet connection',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF17251F),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF59615C), fontSize: 12),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
