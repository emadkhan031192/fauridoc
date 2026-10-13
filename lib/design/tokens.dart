import 'package:flutter/material.dart';

/// Design tokens ported literally from `design/fauridoc-screens.html`.
/// 1 CSS px = 1 Flutter logical px. Do not "improve" these values.
class FdSpec {
  // ---------- colours ----------
  static const primary = Color(0xFF0B6B5C);
  static const darkGreen = Color(0xFF0B5446);
  static const ink = Color(0xFF0F2A2E);
  static const pageBg = Color(0xFFF5F7F6);
  static const border = Color(0xFFE1E7E4);
  static const inputBorder = Color(0xFFD5DEDA);
  static const muted = Color(0xFF566B68);
  static const secondary = Color(0xFF3E5754);
  static const placeholder = Color(0xFF6B7F7B);
  static const lime = Color(0xFFD2F55A);
  static const limeInk = Color(0xFF33430A);
  static const mint = Color(0xFFDDF0EA);
  static const emergencyRed = Color(0xFFC62828);
  static const emergencyRed2 = Color(0xFFD7263D);
  static const openGreen = Color(0xFF1FA463);
  static const closedGrey = Color(0xFF8A9A96);
  static const leaveOrange = Color(0xFFFF7A1A);
  static const star = Color(0xFFF5B400);
  static const mapBg = Color(0xFFE7EDEA);
  static const splashBg = Color(0xFF0B6B5C);

  /// Doctor-card pastel backgrounds, cycled in order.
  static const cardPastels = [
    Color(0xFFE1F3EC),
    Color(0xFFE3EBFF),
    Color(0xFFFFE9DA),
    Color(0xFFF8E3EE),
    Color(0xFFF1EFD8),
  ];

  // Hero tints per entity type.
  static const doctorHeroBg = Color(0xFFFFE6D2);
  static const doctorHeroFg = Color(0xFF8A3F00);
  static const labHeroBg = Color(0xFFE3E9FF);
  static const labHeroFg = Color(0xFF2B3F9E);
  static const hospitalHeroBg = Color(0xFFF8DDDB);
  static const hospitalHeroFg = Color(0xFFC62828);

  // ---------- type ----------
  static const latinFont = 'AlbertSans';
  static const urduFont = 'NotoNastaliqUrdu';

  /// Screen titles: 28/800, letter-spacing -0.02em.
  static const title28 = TextStyle(
    fontFamily: latinFont,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.56,
    color: ink,
    height: 1.2,
  );

  /// App-bar titles: 20/800.
  static const appBar20 = TextStyle(
    fontFamily: latinFont,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: ink,
    height: 1.25,
  );

  /// Section titles: 17/700-800.
  static const section17 = TextStyle(
    fontFamily: latinFont,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: ink,
    height: 1.3,
  );

  static const body15 = TextStyle(
    fontFamily: latinFont,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: ink,
    height: 1.45,
  );

  static const body14 = TextStyle(
    fontFamily: latinFont,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: secondary,
    height: 1.45,
  );

  static const caption13 = TextStyle(
    fontFamily: latinFont,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: muted,
    height: 1.4,
  );

  static const caption12 = TextStyle(
    fontFamily: latinFont,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: muted,
    height: 1.4,
  );

  /// Uppercase field labels: 12/700, +0.06em.
  static const label12 = TextStyle(
    fontFamily: latinFont,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.72,
    color: muted,
  );

  // ---------- shape ----------
  static const cardRadius = 20.0;
  static const pillRadius = 999.0;
  static const inputRadius = 12.0;

  // ---------- behaviour ----------
  /// Press feedback: scale to 0.97 in 80 ms (`.press` class).
  static const pressScale = 0.97;
  static const pressDuration = Duration(milliseconds: 80);

  /// Status bar area: top padding 48-52 px; edge-to-edge, dark icons.
  static const statusBarPadding = 48.0;
}
