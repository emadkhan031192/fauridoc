import 'dart:io';

import 'package:flutter/material.dart';

/// Brand colors (from the design brief).
class FauridocTheme {
  static const teal = Color(0xFF0B7A75);
  static const tealDark = Color(0xFF095F5B);
  static const ink = Color(0xFF12211F);
  static const emergencyRed = Color(0xFFD7263D);
  static const starAmber = Color(0xFFF5A623);
  static const bg = Color(0xFFF6F8F7);

  static ThemeData light(String? fontFamily) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: teal),
        scaffoldBackgroundColor: bg,
        fontFamily: fontFamily,
        appBarTheme: const AppBarTheme(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: teal,
          foregroundColor: Colors.white,
        ),
      );
}

/// Small pill badge, e.g. "Verified", "Doctor", "24/7 Emergency".
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const Pill({
    super.key,
    required this.label,
    this.color = FauridocTheme.teal,
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

/// Image that handles network URLs, local file paths (demo mode), and
/// bundled assets. Shows [fallback] when there is no photo.
class AnyPhoto extends StatelessWidget {
  final String? photoUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;

  const AnyPhoto({
    super.key,
    this.photoUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    Widget? img;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('http')) {
        img = Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      } else if (url.startsWith('assets/')) {
        img = Image.asset(url, width: width, height: height, fit: fit);
      } else {
        final f = File(url);
        if (f.existsSync()) {
          img = Image.file(f, width: width, height: height, fit: fit);
        }
      }
    }
    return img ?? fallback ?? const SizedBox.shrink();
  }
}

/// Circular avatar showing a photo, or initials when there is none.
class EntityAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;

  const EntityAvatar({super.key, this.photoUrl, required this.name, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();
    final url = photoUrl;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('http')) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: FauridocTheme.teal.withValues(alpha: 0.15),
          backgroundImage: NetworkImage(url),
          onBackgroundImageError: (_, _) {},
        );
      }
      if (!url.startsWith('assets/')) {
        final f = File(url);
        if (f.existsSync()) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: FauridocTheme.teal.withValues(alpha: 0.15),
            backgroundImage: FileImage(f),
          );
        }
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: FauridocTheme.teal.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: TextStyle(
          color: FauridocTheme.tealDark,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}
