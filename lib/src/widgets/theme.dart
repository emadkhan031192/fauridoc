import 'package:flutter/material.dart';

/// Fauridoc design system — sampled from the 16-screen design PDF
/// (design/fauridoc-screens.html). Albert Sans for Latin, Noto Nastaliq Urdu for Urdu.
class FdColors {
  static const primary = Color(0xFF0B6B5C); // teal: splash, buttons, chips
  static const primaryDark = Color(0xFF0B5446);
  static const ink = Color(0xFF0F2A2E); // headings + dark "Call" buttons
  static const inkSoft = Color(0xFF3E5754); // body grey-green
  static const muted = Color(0xFF566B68); // secondary text
  static const line = Color(0xFFE1E7E4); // hairlines, chip borders

  static const lime = Color(0xFFD2F55A); // "Top rated near you" card
  static const limeLight = Color(0xFFEFFAC2); // time pills on lime
  static const red = Color(0xFFC62828); // emergency
  static const redSoft = Color(0xFFF8DDDB); // pink chips / headers
  static const redInk = Color(0xFFB3261E);
  static const mint = Color(0xFFDDF0EA); // search cards, status cards
  static const mintDeep = Color(0xFFDDF0EA); // avatars, nav pill
  static const mintInk = Color(0xFF0B6B5C);
  static const lavender = Color(0xFFE3E9FF); // alt cards, lab header
  static const lavenderInk = Color(0xFF2B3F9E);
  static const peach = Color(0xFFFFE6D2); // doctor header
  static const peachInk = Color(0xFF8A3F00);
  static const amberCard = Color(0xFFFFF9ED); // pinned community card
  static const amberStrong = Color(0xFFF5B400); // rating bars, 1122 badge
  static const amberInk = Color(0xFF8A5A00);
  static const amberSoft = Color(0xFFFFF0DB); // pending pills

  static const bg = Color(0xFFF5F7F6);
  static const card = Colors.white;
  static const starGold = Color(0xFFF5B400);

  /// Alternating pastel card backgrounds for search/list rows.
  static const cardTints = [
    Color(0xFFE1F3EC),
    Color(0xFFE3EBFF),
    Color(0xFFFFE9DA),
    Color(0xFFF8E3EE),
    Color(0xFFF1EFD8),
  ];

  /// Header banner tints per entity type.
  static const doctorHeader = peach;
  static const labHeader = lavender;
  static const hospitalHeader = Color(0xFFF8DDDB);

  static Color tintForIndex(int i) => cardTints[i % cardTints.length];
}

/// Central type scale. [isUrdu] swaps the family to Nastaliq and scales
/// the size down by 10% (Nastaliq renders large).
class FdType {
  static const latin = 'AlbertSans';
  static const urdu = 'NotoNastaliqUrdu';

  /// User-adjustable font scales (mirrored from [fontScaleProvider]).
  /// Defaults keep the old behavior: Latin at 100%, Urdu at 90%.
  static double enScale = 1.0;
  static double urScale = 0.9;

  /// Single computation point for user-scaled font sizes:
  /// `base * (ur ? urScale : enScale)`.
  static double scaled(bool ur, double size) =>
      size * (ur ? urScale : enScale);

  static String family(bool isUrdu) => isUrdu ? urdu : latin;

  /// Extra line height keeps Nastaliq legible.
  static double height(bool isUrdu, double base) => isUrdu ? base + 0.9 : base;

  static TextStyle display(bool ur,
          {double size = 34, FontWeight w = FontWeight.w700}) =>
      TextStyle(
        fontFamily: family(ur),
        fontSize: scaled(ur, size),
        fontWeight: ur ? FontWeight.w700 : w,
        color: FdColors.ink,
        height: height(ur, 1.18),
        letterSpacing: ur ? 0 : -0.3,
      );

  static TextStyle title(bool ur,
          {double size = 22, FontWeight w = FontWeight.w700}) =>
      TextStyle(
        fontFamily: family(ur),
        fontSize: scaled(ur, size),
        fontWeight: ur ? FontWeight.w700 : w,
        color: FdColors.ink,
        height: height(ur, 1.25),
      );

  static TextStyle body(bool ur,
          {double size = 15,
          FontWeight w = FontWeight.w400,
          Color color = FdColors.inkSoft}) =>
      TextStyle(
        fontFamily: family(ur),
        fontSize: scaled(ur, size),
        fontWeight: w,
        color: color,
        height: height(ur, 1.45),
      );

  static TextStyle label(bool ur,
          {double size = 13,
          FontWeight w = FontWeight.w600,
          Color color = FdColors.muted}) =>
      TextStyle(
        fontFamily: family(ur),
        fontSize: scaled(ur, size),
        fontWeight: w,
        color: color,
        height: height(ur, 1.3),
        letterSpacing: ur ? 0 : 0.6,
      );

  static TextStyle button(bool ur,
          {double size = 17, Color color = Colors.white}) =>
      TextStyle(
        fontFamily: family(ur),
        fontSize: scaled(ur, size),
        fontWeight: FontWeight.w600,
        color: color,
        height: height(ur, 1.2),
      );
}

/// Spacing / radius tokens matching the design proportions.
class FdDim {
  static const page = 20.0;
  static const cardRadius = 24.0;
  static const bannerRadius = 20.0;
  static const pillRadius = 999.0;
  static const fieldRadius = 20.0;
  static const buttonHeight = 62.0;
  static const chipHeight = 52.0;
  static const searchHeight = 60.0;
}

/// The Fauridoc logo: white rounded square, teal plus, orange bolt.
class FdLogo extends StatelessWidget {
  final double size;
  const FdLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final teal = Paint()..color = FdColors.primary;
    final orange = Paint()..color = const Color(0xFFF59E0B);
    final c = size.width / 2;
    final arm = size.width * 0.13;
    final len = size.width * 0.30;
    // teal plus
    canvas.drawRect(
        Rect.fromCenter(center: Offset(c, c), width: arm, height: len), teal);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(c, c), width: len, height: arm), teal);
    // orange lightning bolt over the plus
    final bolt = Path()
      ..moveTo(c + size.width * 0.045, c - size.width * 0.17)
      ..lineTo(c - size.width * 0.075, c + size.width * 0.02)
      ..lineTo(c - size.width * 0.005, c + size.width * 0.02)
      ..lineTo(c - size.width * 0.045, c + size.width * 0.17)
      ..lineTo(c + size.width * 0.075, c - size.width * 0.02)
      ..lineTo(c + size.width * 0.005, c - size.width * 0.02)
      ..close();
    canvas.drawPath(bolt, orange);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pill button in the design language.
class FdButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final FdButtonStyle style;
  final IconData? icon;
  final bool isUrdu;
  final double? width;

  const FdButton({
    super.key,
    required this.label,
    this.onTap,
    this.style = FdButtonStyle.primary,
    this.icon,
    this.isUrdu = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide? border;
    switch (style) {
      case FdButtonStyle.primary:
        bg = FdColors.primary;
        fg = Colors.white;
        break;
      case FdButtonStyle.dark:
        bg = FdColors.ink;
        fg = Colors.white;
        break;
      case FdButtonStyle.white:
        bg = Colors.white;
        fg = FdColors.ink;
        break;
      case FdButtonStyle.outline:
        bg = Colors.white;
        fg = FdColors.primary;
        border = const BorderSide(color: FdColors.primary, width: 1.6);
        break;
      case FdButtonStyle.danger:
        bg = FdColors.red;
        fg = Colors.white;
        break;
      case FdButtonStyle.dangerOutline:
        bg = Colors.white;
        fg = FdColors.redInk;
        border = BorderSide(color: FdColors.red.withValues(alpha: 0.4), width: 1.6);
        break;
    }
    return SizedBox(
      width: width,
      height: FdDim.buttonHeight,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(FdDim.pillRadius),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FdDim.pillRadius),
              border: border != null ? Border.fromBorderSide(border) : null,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: fg, size: 22),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: FdType.button(isUrdu, color: fg),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum FdButtonStyle { primary, dark, white, outline, danger, dangerOutline }

/// Rounded search field with magnifier icon.
class FdSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool isUrdu;
  final TextEditingController? controller;

  const FdSearchField({
    super.key,
    required this.hint,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.isUrdu = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: FdDim.searchHeight,
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        style: FdType.body(isUrdu, size: 16, color: FdColors.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: FdType.body(isUrdu, size: 16, color: FdColors.muted),
          prefixIcon: const Icon(Icons.search, color: FdColors.muted, size: 26),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      ),
    );
  }
}

/// Selectable filter chip: teal-filled when selected, white otherwise.
class FdChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool isUrdu;
  final Widget? leading;

  const FdChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.isUrdu = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FdColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(FdDim.pillRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
        onTap: onTap,
        child: Container(
          height: FdDim.chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FdDim.pillRadius),
            border: selected
                ? null
                : Border.all(color: FdColors.line, width: 1.4),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: FdType.body(
                  isUrdu,
                  size: 16,
                  w: FontWeight.w600,
                  color: selected ? Colors.white : FdColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Teal check badge shown next to verified names.
class FdVerifiedBadge extends StatelessWidget {
  final double size;
  const FdVerifiedBadge({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: FdColors.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.check, color: Colors.white, size: size * 0.62),
    );
  }
}

/// White pill with gold star + rating, e.g. "★ 4.9".
class FdRatingPill extends StatelessWidget {
  final double rating;
  final bool isUrdu;
  const FdRatingPill({super.key, required this.rating, this.isUrdu = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: FdColors.starGold, size: 18),
          const SizedBox(width: 5),
          Text(
            rating.toStringAsFixed(1),
            style: FdType.body(isUrdu,
                size: 16, w: FontWeight.w700, color: FdColors.ink),
          ),
        ],
      ),
    );
  }
}

/// Soft pill for "New" (no reviews yet) listings.
class FdNewPill extends StatelessWidget {
  final String label;
  final bool isUrdu;
  const FdNewPill({super.key, required this.label, this.isUrdu = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
      ),
      child: Text(
        label,
        style: FdType.body(isUrdu,
            size: 14, w: FontWeight.w700, color: FdColors.primary),
      ),
    );
  }
}

/// Rounded-square initials avatar on a pastel background.
class FdAvatarTile extends StatelessWidget {
  final String name;
  final double size;
  final Color bg;

  const FdAvatarTile({
    super.key,
    required this.name,
    this.size = 76,
    this.bg = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name
        .replaceFirst(RegExp(r'^Dr\.\s*'), '')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '•' : initials,
        style: TextStyle(
          fontFamily: FdType.latin,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: FdColors.primary,
        ),
      ),
    );
  }
}

/// Section header row: bold title left, teal link right.
class FdSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isUrdu;

  const FdSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.isUrdu = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: FdType.title(isUrdu, size: 21)),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: FdType.body(isUrdu,
                  size: 15, w: FontWeight.w600, color: FdColors.primary),
            ),
          ),
      ],
    );
  }
}

/// Small-caps section label with trailing divider, e.g. "OTHER EMERGENCY WARDS NEARBY".
class FdCapsLabel extends StatelessWidget {
  final String label;
  final bool isUrdu;
  const FdCapsLabel({super.key, required this.label, this.isUrdu = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: FdType.label(isUrdu, size: 13, w: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: FdColors.line, thickness: 1.4)),
      ],
    );
  }
}

/// Info card with label/value rows (doctor/lab/hospital profiles).
class FdInfoCard extends StatelessWidget {
  final List<FdInfoRow> rows;
  final bool isUrdu;

  const FdInfoCard({super.key, required this.rows, this.isUrdu = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdDim.cardRadius),
        border: Border.all(color: FdColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 128,
                    child: Text(
                      rows[i].label,
                      style: FdType.body(isUrdu,
                          size: 15, w: FontWeight.w500, color: FdColors.muted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].value,
                      style: FdType.body(isUrdu,
                          size: 16, w: FontWeight.w600, color: FdColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            if (i < rows.length - 1)
              const Divider(color: FdColors.line, height: 1),
          ],
        ],
      ),
    );
  }
}

class FdInfoRow {
  final String label;
  final String value;
  const FdInfoRow(this.label, this.value);
}

/// Bottom navigation bar from the design: 5 items, mint pill on active.
class FdBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isUrdu;
  final List<String> labels;

  const FdBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.labels,
    this.isUrdu = false,
  });

  @override
  State<FdBottomNav> createState() => _FdBottomNavState();
}

class _FdBottomNavState extends State<FdBottomNav> {
  int _pressed = -1;

  static const _icons = [
    Icons.home_outlined,
    Icons.search,
    Icons.location_on_outlined,
    Icons.forum_outlined,
    Icons.person_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 84 + bottomPad,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: FdColors.line)),
      ),
      padding: EdgeInsets.only(top: 8, bottom: bottomPad),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 5; i++)
            GestureDetector(
              onTapDown: (_) => setState(() => _pressed = i),
              onTapUp: (_) {
                setState(() => _pressed = -1);
                widget.onTap(i);
              },
              onTapCancel: () => setState(() => _pressed = -1),
              behavior: HitTestBehavior.opaque,
              child: AnimatedScale(
                scale: _pressed == i ? 0.97 : 1.0,
                duration: const Duration(milliseconds: 80),
                child: SizedBox(
                  width: 68,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == widget.currentIndex
                              ? FdColors.mint
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          _icons[i],
                          color: i == widget.currentIndex
                              ? FdColors.primary
                              : FdColors.muted,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FdType.body(
                          widget.isUrdu,
                          size: 11,
                          w: i == widget.currentIndex
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: i == widget.currentIndex
                              ? FdColors.primary
                              : FdColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ThemeData for the app. [locale] picks the default font family.
ThemeData fauridocTheme([String locale = 'en']) {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: FdColors.bg,
    fontFamily: locale == 'ur' ? FdType.urdu : FdType.latin,
    colorScheme: ColorScheme.fromSeed(
      seedColor: FdColors.primary,
      primary: FdColors.primary,
      surface: FdColors.bg,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: FdColors.bg,
      foregroundColor: FdColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: FdType.latin,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: FdColors.ink,
      ),
    ),
  );
}

/// True when the current locale is Urdu.
bool fdIsUrdu(String locale) => locale == 'ur';

// ---------------------------------------------------------------------------
// Deprecated compatibility shims — kept so pre-redesign code still compiles
// while screens are migrated to the Fd* design system above.
// ---------------------------------------------------------------------------

/// Old brand color holder. Prefer [FdColors].
typedef FauridocTheme = FdColors;

/// Old pill badge. Prefer the Fd* widgets.
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const Pill({
    super.key,
    required this.label,
    this.color = FdColors.primary,
    this.textColor = Colors.white,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
