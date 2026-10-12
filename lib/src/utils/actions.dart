import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../providers/providers.dart';

/// Normalize a Pakistani phone number for wa.me links:
/// "0316…" -> "92316…", "+92316…" -> "92316…".
String normalizeWhatsapp(String raw) {
  var n = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (n.startsWith('0')) n = '92${n.substring(1)}';
  return n;
}

Future<void> _launch(BuildContext context, Uri uri, String noPhoneKey) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(translateOf(context, noPhoneKey))),
    );
  }
}

String translateOf(BuildContext context, String key) {
  final container = ProviderScope.containerOf(context, listen: false);
  return translate(container.read(localeProvider), key);
}

/// Tap-to-call.
Future<void> callNumber(BuildContext context, String phone) {
  if (phone.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(translateOf(context, 'noPhoneNumber'))),
    );
    return Future.value();
  }
  return _launch(context, Uri.parse('tel:${phone.trim()}'), 'noPhoneNumber');
}

/// Open a WhatsApp chat. Records a stats click for [doctorId] when given.
Future<void> openWhatsapp(
  BuildContext context,
  WidgetRef ref,
  String rawNumber, {
  String? doctorId,
  String message = '',
}) async {
  final number = normalizeWhatsapp(rawNumber);
  if (number.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(translateOf(context, 'noPhoneNumber'))),
    );
    return;
  }
  if (doctorId != null) {
    ref.read(repositoryProvider).recordWhatsappClick(doctorId);
  }
  final uri = Uri.parse(
    'https://wa.me/$number${message.isNotEmpty ? '?text=${Uri.encodeComponent(message)}' : ''}',
  );
  await _launch(context, uri, 'noPhoneNumber');
}

/// Open directions: native geo: intent when coordinates exist,
/// otherwise a Google Maps search for the label.
Future<void> openDirections(
  BuildContext context,
  double? lat,
  double? lng,
  String label,
) {
  final uri = (lat != null && lng != null)
      ? Uri.parse('geo:$lat,$lng?q=${Uri.encodeComponent(label)}')
      : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(label)}');
  return _launch(context, uri, 'error');
}
