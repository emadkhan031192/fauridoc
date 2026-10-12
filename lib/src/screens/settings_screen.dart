import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

/// Language settings (+ demo-mode info and admin preview in demo mode).
class SettingsScreen extends ConsumerWidget {
  final bool demoMode;

  const SettingsScreen({super.key, required this.demoMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'settingsTitle'))),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              tr(ref, 'language'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          ListTile(
            title: Text(tr(ref, 'english')),
            trailing:
                locale == 'en' ? const Icon(Icons.check) : null,
            onTap: () => ref.read(localeProvider.notifier).setLocale('en'),
          ),
          ListTile(
            title: Text(tr(ref, 'urdu')),
            trailing:
                locale == 'ur' ? const Icon(Icons.check) : null,
            onTap: () => ref.read(localeProvider.notifier).setLocale('ur'),
          ),
          if (demoMode) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: ListTile(
                  title: Text(tr(ref, 'demoMode')),
                  subtitle: Text(tr(ref, 'demoModeBody')),
                ),
              ),
            ),
            SwitchListTile(
              title: Text(tr(ref, 'adminPreview')),
              value: ref.watch(demoAdminPreviewProvider),
              onChanged: (v) =>
                  ref.read(demoAdminPreviewProvider.notifier).set(v),
            ),
          ],
        ],
      ),
    );
  }
}
