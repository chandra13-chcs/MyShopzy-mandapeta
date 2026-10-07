import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _background = Color(0xFFFCFDFC);
  static const _green = Color(0xFF2C7C65);
  static const _lightGreen = Color(0xFFEFF8F4);
  static const _mainText = Color(0xFF202321);
  static const _secondaryText = Color(0xFF777C79);
  static const _border = Color(0xFFE7EAE8);

  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _mainText,
        surfaceTintColor: _background,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            _buildSectionLabel('Preferences'),
            const SizedBox(height: 10),
            _buildCard([
              _buildSwitchRow(
                title: 'Notifications',
                icon: Icons.notifications_none_rounded,
                value: _notificationsEnabled,
                onChanged: (value) =>
                    setState(() => _notificationsEnabled = value),
              ),
              const Divider(height: 1, color: _border),
              _buildSwitchRow(
                title: 'Dark Mode',
                icon: Icons.dark_mode_outlined,
                value: _darkModeEnabled,
                onChanged: (value) => setState(() => _darkModeEnabled = value),
              ),
              const Divider(height: 1, color: _border),
              _buildActionRow(
                title: 'Language',
                icon: Icons.language_rounded,
                trailing: const Text(
                  'English',
                  style: TextStyle(color: _secondaryText, fontSize: 13),
                ),
                onTap: () => _showMessage(
                  context,
                  'Language options will be available soon',
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionLabel('App'),
            const SizedBox(height: 10),
            _buildCard([
              _buildActionRow(
                title: 'About MyShopzy',
                icon: Icons.info_outline_rounded,
                onTap: () => _showMessage(
                  context,
                  'More app information will be available soon',
                ),
              ),
              const Divider(height: 1, color: _border),
              _buildActionRow(
                title: 'App Version',
                icon: Icons.phone_android_outlined,
                trailing: const Text(
                  'Version 1.0.0',
                  style: TextStyle(color: _secondaryText, fontSize: 13),
                ),
              ),
              const Divider(height: 1, color: _border),
              _buildActionRow(
                title: 'Rate MyShopzy',
                icon: Icons.star_outline_rounded,
                onTap: () => _showMessage(
                  context,
                  'Rating MyShopzy will be available soon',
                ),
              ),
              const Divider(height: 1, color: _border),
              _buildActionRow(
                title: 'Share MyShopzy',
                icon: Icons.share_outlined,
                onTap: () => _showMessage(
                  context,
                  'Sharing MyShopzy will be available soon',
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _mainText,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        children: [
          _buildIcon(icon),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _mainText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: _green,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: _border,
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required String title,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _buildIcon(icon),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _mainText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ?trailing,
            if (onTap != null) ...[
              if (trailing != null) const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: _secondaryText),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _lightGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: _green, size: 21),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
