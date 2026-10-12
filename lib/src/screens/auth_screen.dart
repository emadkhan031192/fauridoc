import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/theme.dart';
import 'register_entity_screen.dart';

/// Sign-in / registration entry point in the design language.
///
/// Hierarchy: Google (Firebase) or phone — demo backend signs in locally,
/// Firebase backend uses real two-step SMS OTP. Doctors continue to
/// "Add a listing" after signing in.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _showPhone = false;
  bool _busy = false;
  bool _codeSent = false;
  String? _verificationId;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      _snack(tr(ref, 'auth.signedIn'));
      Navigator.of(context).pop();
    } catch (e) {
      _snack(e is UnsupportedError
          ? tr(ref, 'auth.googleNeedsFirebase')
          : e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Demo backend: instant local sign-in (no SMS).
  Future<void> _phoneDemo() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _snack(tr(ref, 'auth.fillNamePhone'));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).signInDemo(name, phone);
      if (!mounted) return;
      _snack(tr(ref, 'auth.signedIn'));
      Navigator.of(context).pop();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Normalize a Pakistani mobile to +92XXXXXXXXXX for Firebase.
  String _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.startsWith('92')) return '+$digits';
    return '+92$digits';
  }

  /// Firebase step 1: request the SMS code.
  Future<void> _sendCode() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _snack(tr(ref, 'auth.fillNamePhone'));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).sendPhoneCode(
            _normalizePhone(phone),
            onCodeSent: (verificationId) {
              if (!mounted) return;
              setState(() {
                _verificationId = verificationId;
                _codeSent = true;
                _busy = false;
              });
              _snack(tr(ref, 'auth.codeSent'));
            },
            onError: (message) {
              if (!mounted) return;
              setState(() => _busy = false);
              _snack(message);
            },
            onAutoVerified: (_) {
              if (!mounted) return;
              _snack(tr(ref, 'auth.signedIn'));
              Navigator.of(context).pop();
            },
          );
      // Safety: if verifyPhoneNumber resolved without any callback firing
      // (e.g. timeout with no auto-retrieval), release the button.
      if (mounted && _busy && !_codeSent) setState(() => _busy = false);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _snack(e is UnsupportedError
          ? tr(ref, 'auth.googleNeedsFirebase')
          : e.toString());
    }
  }

  /// Firebase step 2: verify the SMS code.
  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    final vid = _verificationId;
    if (vid == null || code.isEmpty) {
      _snack(tr(ref, 'auth.fillNamePhone'));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authProvider.notifier)
          .verifyPhoneCode(vid, code, name: _nameCtrl.text.trim());
      if (!mounted) return;
      _snack(tr(ref, 'auth.signedIn'));
      Navigator.of(context).pop();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Step 1: name + phone. Demo signs in instantly; Firebase sends an SMS.
  List<Widget> _phoneStep(bool ur, bool isDemo) {
    return [
      _AuthField(
          controller: _nameCtrl,
          hint: tr(ref, 'auth.name'),
          ur: ur,
          icon: Icons.person_outline),
      const SizedBox(height: 12),
      _AuthField(
        controller: _phoneCtrl,
        hint: tr(ref, 'auth.phoneNumber'),
        ur: ur,
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        prefix: const Padding(
          padding: EdgeInsets.only(left: 18),
          child: Text('+92 ',
              style: TextStyle(
                  fontFamily: FdType.latin,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: FdColors.ink)),
        ),
      ),
      if (isDemo) ...[
        const SizedBox(height: 12),
        Text(tr(ref, 'auth.demoNote'),
            style: FdType.body(ur, size: 13, color: FdColors.muted)),
      ],
      const SizedBox(height: 14),
      FdButton(
        label: tr(ref, isDemo ? 'auth.sendCode' : 'auth.sendSms'),
        isUrdu: ur,
        onTap: _busy ? null : (isDemo ? _phoneDemo : _sendCode),
      ),
    ];
  }

  /// Step 2 (Firebase): enter the 6-digit SMS code.
  List<Widget> _codeStep(bool ur) {
    return [
      Text(tr(ref, 'auth.enterCode'),
          style: FdType.title(ur, size: 18),
          textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text(tr(ref, 'auth.codeSent'),
          style: FdType.body(ur, size: 13, color: FdColors.muted),
          textAlign: TextAlign.center),
      const SizedBox(height: 14),
      _AuthField(
        controller: _codeCtrl,
        hint: tr(ref, 'auth.codeHint'),
        ur: ur,
        icon: Icons.sms_outlined,
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 14),
      FdButton(
        label: tr(ref, 'auth.verify'),
        isUrdu: ur,
        onTap: _busy ? null : _verifyCode,
      ),
      const SizedBox(height: 10),
      Center(
        child: GestureDetector(
          onTap: _busy ? null : _sendCode,
          child: Text(
            tr(ref, 'auth.resendCode'),
            style: FdType.body(ur,
                size: 14, w: FontWeight.w600, color: FdColors.primary),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ur = fdIsUrdu(ref.watch(localeProvider));
    final isDemo = ref.read(authProvider.notifier).isDemoBackend;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(tr(ref, 'auth.signInTitle'),
            style: FdType.title(ur, size: 22)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: FdDim.page, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              const Center(child: FdLogo(size: 76)),
              const SizedBox(height: 22),
              Text(
                tr(ref, 'auth.welcome'),
                style: FdType.display(ur, size: 30),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                tr(ref, 'auth.subtitle'),
                style: FdType.body(ur, size: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              _GoogleButton(
                  label: tr(ref, 'auth.google'),
                  ur: ur,
                  busy: _busy,
                  onTap: _busy ? null : _google),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Divider(color: FdColors.line)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(tr(ref, 'auth.or'),
                        style: FdType.body(ur, size: 14)),
                  ),
                  const Expanded(child: Divider(color: FdColors.line)),
                ],
              ),
              const SizedBox(height: 18),
              FdButton(
                label: tr(ref, 'auth.phone'),
                style: FdButtonStyle.outline,
                icon: Icons.phone_outlined,
                isUrdu: ur,
                onTap: () => setState(() => _showPhone = !_showPhone),
              ),
              if (_showPhone) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: FdColors.bg,
                    borderRadius:
                        BorderRadius.circular(FdDim.cardRadius),
                    border: Border.all(color: FdColors.line),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _codeSent
                        ? _codeStep(ur)
                        : _phoneStep(ur, isDemo),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (ref.read(authProvider) == null) {
                      _snack(tr(ref, 'auth.signInFirst'));
                      return;
                    }
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const RegisterEntityScreen()));
                  },
                  child: Text(
                    tr(ref, 'auth.doctorCta'),
                    style: FdType.body(ur,
                        size: 14,
                        w: FontWeight.w600,
                        color: FdColors.primary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// White bordered pill with a blue "G" + label (Google button).
class _GoogleButton extends StatelessWidget {
  final String label;
  final bool ur;
  final bool busy;
  final VoidCallback? onTap;

  const _GoogleButton({
    required this.label,
    required this.ur,
    required this.busy,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: FdDim.buttonHeight,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(FdDim.pillRadius),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FdDim.pillRadius),
              border: Border.all(color: FdColors.line, width: 1.6),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('G',
                          style: TextStyle(
                              fontFamily: FdType.latin,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4285F4))),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(label,
                            style: FdType.button(ur, color: FdColors.ink),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool ur;
  final IconData icon;
  final TextInputType keyboardType;
  final Widget? prefix;

  const _AuthField({
    required this.controller,
    required this.hint,
    required this.ur,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: FdType.body(ur, size: 16, color: FdColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: FdType.body(ur, size: 16, color: FdColors.muted),
        prefixIcon: prefix ?? Icon(icon, color: FdColors.muted, size: 24),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 52, minHeight: 0),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FdDim.fieldRadius),
          borderSide: const BorderSide(color: FdColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FdDim.fieldRadius),
          borderSide: const BorderSide(color: FdColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FdDim.fieldRadius),
          borderSide: const BorderSide(color: FdColors.primary, width: 1.6),
        ),
      ),
    );
  }
}
