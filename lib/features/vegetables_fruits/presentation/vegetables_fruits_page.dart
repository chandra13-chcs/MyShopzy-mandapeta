import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'produce_catalog_page.dart';

class VegetablesFruitsPage extends StatelessWidget {
  const VegetablesFruitsPage({super.key});

  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _green = AppTheme.primaryGreen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE8EBE6)),
                      minimumSize: const Size(42, 42),
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mandapeta, Andhra Pradesh',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Fresh produce delivered nearby',
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F3E9),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Text(
                      '18 km',
                      style: TextStyle(
                        color: _green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 25, 16, 24),
                children: [
                  const Text(
                    'Vegetables & Fruits',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Choose what you need today',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                  const SizedBox(height: 19),
                  _ProduceTypeCard(
                    title: 'Fruits',
                    subtitle: 'Fresh, seasonal picks',
                    icon: Icons.apple_rounded,
                    background: const Color(0xFFEAF1DD),
                    accent: const Color(0xFF59733D),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const ProduceCatalogPage(
                          type: ProduceType.fruit,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  _ProduceTypeCard(
                    title: 'Vegetables',
                    subtitle: 'Everyday farm-fresh produce',
                    icon: Icons.eco_rounded,
                    background: const Color(0xFFE0EEE0),
                    accent: const Color(0xFF397447),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const ProduceCatalogPage(
                          type: ProduceType.vegetable,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProduceTypeCard extends StatelessWidget {
  const _ProduceTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 148,
          child: Stack(
            children: [
              Positioned(
                right: -19,
                top: -42,
                child: Container(
                  width: 176,
                  height: 176,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                top: 16,
                bottom: 16,
                child: Container(
                  width: 125,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, color: accent, size: 66),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 145, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accent,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.82),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Explore',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: accent,
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
