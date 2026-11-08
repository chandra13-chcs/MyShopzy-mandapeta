import 'package:flutter/material.dart';
import '../constants/app_config.dart';
import '../constants/translations.dart';
import '../utils/format.dart';
import '../widgets/primary_button.dart';

/// Help & support: call support, WhatsApp, emergency, and common questions.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(T.t('help_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PrimaryButton(
            label: T.t('help_call'),
            onPressed: () => callNumber(context, AppConfig.supportPhone),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: T.t('help_whatsapp'),
            outlined: true,
            onPressed: () => openWhatsApp(context, AppConfig.supportWhatsapp),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: T.t('sos'),
            outlined: true,
            onPressed: () => callNumber(context, '112'),
          ),
          const SizedBox(height: 20),
          Text(T.t('help_faq'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (var i = 1; i <= 5; i++)
            ExpansionTile(
              title: Text(T.t('faq_q$i')),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(T.t('faq_a$i'))],
            ),
        ],
      ),
    );
  }
}
