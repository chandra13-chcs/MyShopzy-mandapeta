import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/translations.dart';
import '../services/auth_service.dart';
import '../models/kyc.dart';
import '../services/kyc_service.dart';
import '../services/rider_controller.dart';
import '../utils/format.dart';
import '../utils/theme_colors.dart';
import '../widgets/primary_button.dart';
import 'edit_profile_screen.dart';
import 'help_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'kyc_screen.dart';

/// Feature 9: profile, rating, language, notifications, sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RiderController>();
    final rider = context.watch<AuthService>().rider;
    final kyc = context.watch<KycService>();
    final kycColor = switch (kyc.data.status) {
      KycStatus.pending => Colors.orange,
      KycStatus.approved => Colors.green,
      KycStatus.rejected => Colors.red,
      KycStatus.notSubmitted => Colors.grey,
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFFD9480F),
              child: Text(
                (rider?.name.isNotEmpty ?? false)
                    ? rider!.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white, fontSize: 28),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rider?.name ?? '',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('+91 ${rider?.phone ?? ''}'),
                  if (rider != null && rider.vehicleNumber.isNotEmpty)
                    Text(
                        '${T.t('vehicle_${rider.vehicleType}')} · ${rider.vehicleNumber}'),
                  Text(c.history.isEmpty
                      ? '${T.t('rating')}: -'
                      : '${T.t('rating')}: ${c.averageRating.toStringAsFixed(1)} ★ (${c.history.length})'),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 32),
        Text(T.t('language'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final e in T.languages.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: c.language == e.key,
                onSelected: (_) => c.setLanguage(e.key),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 8),
        Text(T.t('theme'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final m in ThemeMode.values)
              ChoiceChip(
                label: Text(T.t('theme_${m.name}')),
                selected: c.themeMode == m,
                onSelected: (_) => c.setThemeMode(m),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(T.t('notif_enable')),
          value: c.notifEnabled,
          onChanged: c.setNotifEnabled,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined),
          title: Text(T.t('notifications')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.edit_outlined),
          title: Text(T.t('edit_profile')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen())),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_user_outlined),
          title: Text(T.t('kyc_verification_status')),
          trailing: Chip(
            label: Text(T.t('kyc_status_${kyc.data.status.name}')),
            backgroundColor: tint(context, kycColor),
          ),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const KycScreen())),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.help_outline),
          title: Text(T.t('help_title')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const HelpScreen())),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: T.t('logout'),
          outlined: true,
          onPressed: () async {
            final auth = context.read<AuthService>();
            final nav = Navigator.of(context);
            final controller = context.read<RiderController>();
            final kycService = context.read<KycService>();
            final sure = await confirmDialog(context, T.t('confirm_logout'));
            if (!sure) return;
            await controller.reset();
            await kycService.reset();
            await auth.logout();
            nav.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
      ],
    );
  }
}
