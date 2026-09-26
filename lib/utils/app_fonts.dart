import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized typography access matching the minimal Scandinavian reference design.
/// Uses Plus Jakarta Sans as primary display & body font with JetBrains Mono for
/// architectural overline tags and technical metadata.
class AppFonts {
  AppFonts._();

  /// Primary modern sans-serif matching the reference UI design (Plus Jakarta Sans).
  static TextStyle plusJakartaSans({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }

  /// Clean sans-serif for general UI (aliased to Plus Jakarta Sans for complete UI harmony).
  static TextStyle inter({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }

  /// Monospace font for technical metadata, commit boards, and terminal UI.
  static TextStyle jetBrainsMono({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }

  /// Display font for Bauhaus/outfit style.
  static TextStyle outfit({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }

  // ─── SIGNATURE REFERENCE UI TYPOGRAPHY PRESETS ────────────────────────────

  /// Top Screen Headline (e.g. "Choose a trigger", "At a time", "Only run if...")
  static TextStyle pageTitle({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = -0.4,
  }) {
    return plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: 1.2,
    );
  }

  /// Terracotta / Accent Overline Tag (e.g. "WHEN", "IF", "07:00 · MON-FRI")
  static TextStyle overlineTag({
    Color color = const Color(0xFFD9532F),
    double fontSize = 10.5,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = 1.6,
  }) {
    return jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Section Header (e.g. "TIME", "PEOPLE", "DEVICES AND SENSORS", "ENERGY", "REPEAT")
  static TextStyle sectionHeader({
    Color? color,
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = 1.4,
  }) {
    return jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// List Item Primary Title (e.g. "At a time", "Someone arrives")
  static TextStyle itemTitle({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) {
    return plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
    );
  }

  /// List Item Secondary Subtitle (e.g. "Every day or chosen days", "Lisbon · today 07:22 / 19:32")
  static TextStyle itemSubtitle({
    double fontSize = 12.5,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) {
    return plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
    );
  }

  /// Hero Number / Tabular Time Display (e.g. "07 : 00" or big metrics)
  static TextStyle heroNumber({
    double fontSize = 42,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double letterSpacing = -1.0,
  }) {
    return plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Full-width Pill Action Button (e.g. "Use this time", "Skip, no condition")
  static TextStyle pillButton({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = 0.2,
  }) {
    return plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}
