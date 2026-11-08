import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/translations.dart';

/// 250.0 -> "₹250", 250.5 -> "₹250.50"
String money(double v) =>
    '₹${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// Opens the phone dialer. Needs the `tel` query in AndroidManifest (see STATUS.md).
Future<void> callNumber(BuildContext context, String phone) async {
  await _launchOrNotify(context, Uri(scheme: 'tel', path: phone));
}

/// Opens Google Maps directions from the rider's current location to a place.
/// Used for the "Navigate" button during an active delivery (one leg at a time).
Future<void> openMaps(BuildContext context, double lat, double lng) async {
  final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=two_wheeler');
  await _launchOrNotify(context, uri, mode: LaunchMode.externalApplication);
}

/// Opens Google Maps showing the full route: shop -> customer. Used on the
/// incoming-order popup so the rider can see the whole trip before deciding
/// to accept, not just one leg of it.
Future<void> openRoute(BuildContext context, double fromLat, double fromLng,
    double toLat, double toLng) async {
  final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$fromLat,$fromLng&destination=$toLat,$toLng&travelmode=two_wheeler');
  await _launchOrNotify(context, uri, mode: LaunchMode.externalApplication);
}

/// Opens a WhatsApp chat (number with country code, digits only).
Future<void> openWhatsApp(BuildContext context, String number) async {
  await _launchOrNotify(
    context,
    Uri.parse('https://wa.me/$number'),
    mode: LaunchMode.externalApplication,
  );
}

Future<void> _launchOrNotify(
  BuildContext context,
  Uri uri, {
  LaunchMode? mode,
}) async {
  bool opened;
  try {
    opened =
        mode == null ? await launchUrl(uri) : await launchUrl(uri, mode: mode);
  } on PlatformException {
    opened = false;
  } on MissingPluginException {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(T.t('app_launch_failed'))));
  }
}

/// 4980 seconds -> "1h 23m", 300 -> "5m", 20 -> "0m"
String fmtHoursMinutes(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

/// 754 seconds -> "12:34"
String fmtClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final m = s ~/ 60;
  final r = (s % 60).toString().padLeft(2, '0');
  return '$m:$r';
}

/// A simple "Are you sure?" box. Returns true only when the rider taps Yes.
Future<bool> confirmDialog(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(T.t('cancel'))),
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(T.t('yes'))),
      ],
    ),
  );
  return result ?? false;
}
