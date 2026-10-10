import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../profile/models/saved_address.dart';

class DeliveryLocationBottomSheet extends StatelessWidget {
  const DeliveryLocationBottomSheet({
    required this.onViewAll,
    required this.onEnterManually,
    super.key,
  });

  final VoidCallback onViewAll;
  final VoidCallback onEnterManually;

  static const _blue = Color(0xFF1769AA);
  static const _paleBlue = Color(0xFFEAF4FF);
  static const _divider = Color(0xFFE8ECEF);

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5D9DC),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
                decoration: BoxDecoration(
                  color: _paleBlue,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD6E8FC)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      color: _blue,
                      size: 24,
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location Permission is Off',
                            style: TextStyle(
                              color: AppTheme.primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Turn on location to find your delivery area. '
                            'This feature is not connected yet.',
                            style: TextStyle(
                              color: AppTheme.secondaryText,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      key: const ValueKey('location-permission-grant'),
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Location permission is not connected yet.',
                              ),
                            ),
                          ),
                      style: TextButton.styleFrom(
                        foregroundColor: _blue,
                        minimumSize: const Size(48, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'GRANT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Delivery Address',
                      style: TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('location-view-all'),
                    onPressed: onViewAll,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      minimumSize: const Size(64, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'VIEW ALL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              for (var index = 0; index < demoSavedAddresses.length; index++)
                _buildAddressRow(context, demoSavedAddresses[index], index),
              const SizedBox(height: 12),
              const Divider(height: 1, color: _divider),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  key: const ValueKey('location-enter-manually'),
                  onPressed: onEnterManually,
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 21),
                  label: const Text('Enter Location Manually'),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: AppTheme.primaryGreen,
                    minimumSize: const Size(44, 48),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressRow(
    BuildContext context,
    SavedAddress address,
    int index,
  ) {
    return Column(
      children: [
        if (index > 0) const Divider(height: 1, color: _divider),
        Semantics(
          button: true,
          label: '${address.label}, Demo address: ${address.address}',
          child: InkWell(
            key: ValueKey('saved-delivery-address-${address.id}'),
            onTap: () => Navigator.of(context).pop(address),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppTheme.lightBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      address.icon,
                      color: AppTheme.primaryGreen,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address.label,
                          style: const TextStyle(
                            color: AppTheme.primaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Demo address: ${address.address}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.secondaryText,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.secondaryText,
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
