import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../providers/providers.dart';
import '../providers/font_scale.dart';
import '../widgets/theme.dart';

/// Static help content + a "Send feedback" mailto button.
class HelpFeedbackScreen extends ConsumerWidget {
  const HelpFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(fontScaleProvider); // Re-render when the font-size sliders change.
    final ur = fdIsUrdu(ref.watch(localeProvider));
    return Scaffold(
      backgroundColor: FdColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_right
                : Icons.chevron_left,
            size: 30,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title:
            Text(tr(ref, 'help.title'), style: FdType.title(ur, size: 22)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _HelpCard(
            ur: ur,
            icon: Icons.search,
            title: tr(ref, 'help.sectionFinding'),
            body: tr(ref, 'help.sectionFindingBody'),
          ),
          const SizedBox(height: 12),
          _HelpCard(
            ur: ur,
            icon: Icons.science_outlined,
            title: tr(ref, 'help.sectionLabs'),
            body: tr(ref, 'help.sectionLabsBody'),
          ),
          const SizedBox(height: 12),
          _HelpCard(
            ur: ur,
            icon: Icons.local_hospital_outlined,
            title: tr(ref, 'help.sectionEmergency'),
            body: tr(ref, 'help.sectionEmergencyBody'),
          ),
          const SizedBox(height: 12),
          _HelpCard(
            ur: ur,
            icon: Icons.add_business_outlined,
            title: tr(ref, 'help.sectionListing'),
            body: tr(ref, 'help.sectionListingBody'),
          ),
          const SizedBox(height: 20),
          Text(tr(ref, 'help.faqTitle'),
              style: FdType.title(ur, size: 19)),
          const SizedBox(height: 10),
          _FaqCard(
            ur: ur,
            question: tr(ref, 'help.faqFreeQ'),
            answer: tr(ref, 'help.faqFreeA'),
          ),
          const SizedBox(height: 10),
          _FaqCard(
            ur: ur,
            question: tr(ref, 'help.faqDataQ'),
            answer: tr(ref, 'help.faqDataA'),
          ),
          const SizedBox(height: 10),
          _FaqCard(
            ur: ur,
            question: tr(ref, 'help.faqLangQ'),
            answer: tr(ref, 'help.faqLangA'),
          ),
          const SizedBox(height: 24),
          FdButton(
            label: tr(ref, 'help.sendFeedback'),
            icon: Icons.mail_outline,
            isUrdu: ur,
            onTap: () => _sendFeedback(ref, context),
          ),
        ],
      ),
    );
  }

  /// Opens the email app with a pre-addressed feedback mail.
  Future<void> _sendFeedback(WidgetRef ref, BuildContext context) async {
    final locale = ref.read(localeProvider);
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {
        'subject': translate(locale, 'help.feedbackSubject'),
      },
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate(locale, 'help.feedbackFailed'))),
      );
    }
  }
}

/// White info card: icon + title + body.
class _HelpCard extends StatelessWidget {
  final bool ur;
  final IconData icon;
  final String title;
  final String body;

  const _HelpCard({
    required this.ur,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdDim.cardRadius),
        border: Border.all(color: FdColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: FdColors.mint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: FdColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FdType.title(ur, size: 16)),
                const SizedBox(height: 4),
                Text(body,
                    style: FdType.body(ur,
                        size: 14, color: FdColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White card: bold question, muted answer.
class _FaqCard extends StatelessWidget {
  final bool ur;
  final String question;
  final String answer;

  const _FaqCard({
    required this.ur,
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdDim.cardRadius),
        border: Border.all(color: FdColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question,
              style: FdType.body(ur,
                  size: 15, w: FontWeight.w700, color: FdColors.ink)),
          const SizedBox(height: 4),
          Text(answer,
              style:
                  FdType.body(ur, size: 14, color: FdColors.inkSoft)),
        ],
      ),
    );
  }
}
