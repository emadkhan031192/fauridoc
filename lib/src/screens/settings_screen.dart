import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/theme.dart';
import 'help_feedback_screen.dart';

/// Settings (spec styling: white cards, 20px radius, 17/800 section titles):
/// about card, app version, language selector, help & feedback, footer.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ur = fdIsUrdu(ref.watch(localeProvider));
    return Scaffold(
      backgroundColor: FdColors.bg,
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(FdDim.page, 14, FdDim.page, 16),
          children: [
            _screenTitle(ur, tr(ref, 'set.title')),
            const SizedBox(height: 20),
            Text(tr(ref, 'set.aboutTitle'),
                style: _sectionTitle(ur)),
            const SizedBox(height: 10),
            _Card(
              child: Text(tr(ref, 'set.aboutBody'),
                  style:
                      FdType.body(ur, size: 15, color: FdColors.ink)),
            ),
            const SizedBox(height: 18),
            Text(tr(ref, 'set.language'), style: _sectionTitle(ur)),
            const SizedBox(height: 10),
            _Card(
              padding: const EdgeInsets.all(6),
              child: _LanguageSegment(ur: ur),
            ),
            const SizedBox(height: 18),
            Text(tr(ref, 'set.version'), style: _sectionTitle(ur)),
            const SizedBox(height: 10),
            _Card(
              child: Row(
                children: [
                  Text(tr(ref, 'set.version'),
                      style: FdType.body(ur,
                          size: 15,
                          w: FontWeight.w700,
                          color: FdColors.ink)),
                  const Spacer(),
                  const Text('1.0.0',
                      style: TextStyle(
                          fontFamily: FdType.latin,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: FdColors.muted)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SetPress(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const HelpFeedbackScreen())),
              child: _Card(
                child: Row(
                  children: [
                    const Icon(Icons.help_outline,
                        color: FdColors.muted, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(tr(ref, 'set.helpFeedback'),
                          style: FdType.body(ur,
                              size: 15,
                              w: FontWeight.w600,
                              color: FdColors.ink)),
                    ),
                    const Icon(Icons.chevron_right,
                        color: Color(0xFF9AA9A5), size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: Text(
                tr(ref, 'set.footer'),
                style: FdType.body(ur,
                    size: 12, w: FontWeight.w500, color: FdColors.muted),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White spec card: 20px radius, 1px line border.
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card(
      {required this.child,
      this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FdColors.line),
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Screen title: 28/800 (same as the profile screen).
TextStyle _titleStyle(bool ur) => TextStyle(
      fontFamily: FdType.family(ur),
      fontSize: ur ? (28) * 0.9 : (28),
      fontWeight: ur ? FontWeight.w700 : FontWeight.w800,
      letterSpacing: ur ? 0 : -0.56,
      color: FdColors.ink,
      height: FdType.height(ur, 1.2),
    );

Widget _screenTitle(bool ur, String text) =>
    Text(text, style: _titleStyle(ur));

/// Section title: 17/800.
TextStyle _sectionTitle(bool ur) => TextStyle(
      fontFamily: FdType.family(ur),
      fontSize: ur ? (17) * 0.9 : (17),
      fontWeight: FontWeight.w800,
      color: FdColors.ink,
      height: FdType.height(ur, 1.3),
    );

/// EN | اردو segmented control (spec §13): grey track, 42px halves.
class _LanguageSegment extends ConsumerWidget {
  final bool ur;
  const _LanguageSegment({required this.ur});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget half(
        String label, bool labelUr, bool active, VoidCallback onTap) {
      return Expanded(
        child: _SetPress(
          onTap: onTap,
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              boxShadow: active
                  ? [
                      const BoxShadow(
                        color: Color.fromRGBO(15, 42, 46, 0.14),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      )
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: FdType.body(
                labelUr,
                size: 14,
                w: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? FdColors.primary : FdColors.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEEC),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          half('English', false, !ur,
              () => ref.read(localeProvider.notifier).setLocale('en')),
          half('اردو', true, ur,
              () => ref.read(localeProvider.notifier).setLocale('ur')),
        ],
      ),
    );
  }
}

/// `.press` from the spec: scale to 0.97 in 80 ms while pressed.
class _SetPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _SetPress({required this.child, this.onTap});

  @override
  State<_SetPress> createState() => _SetPressState();
}

class _SetPressState extends State<_SetPress> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: widget.child,
      ),
    );
  }
}
