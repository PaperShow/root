import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central theme colors and styling tokens for RootL SuperApp.
/// Inspired by modern warm-minimal Nordic & Scandinavian interfaces (as in reference UI).
class AppTheme {
  final bool isLight;
  final Color scaffoldBackground;
  final Color card;
  final Color cardSecondary;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentWarm;
  final Color accentMuted;
  final Color expenseCoral;
  final Color incomeMint;

  // Bottom Navigation styling tokens (keeping existing minimal floating pill aesthetic)
  final Color navBarBg;
  final Color navBarBorder;
  final Color navBarShadow;
  final Color navActiveCircle;
  final Color navActiveIcon;
  final Color navInactiveIcon;

  const AppTheme({
    required this.isLight,
    required this.scaffoldBackground,
    required this.card,
    required this.cardSecondary,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentWarm,
    required this.accentMuted,
    required this.expenseCoral,
    required this.incomeMint,
    required this.navBarBg,
    required this.navBarBorder,
    required this.navBarShadow,
    required this.navActiveCircle,
    required this.navActiveIcon,
    required this.navInactiveIcon,
  });

  /// Helper to get current theme from context
  static AppTheme of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? light : dark;
  }

  static const dark = AppTheme(
    isLight: false,
    scaffoldBackground: Color(0xFF0F0F11),
    card: Color(0xFF18181B),
    cardSecondary: Color(0xFF242428),
    border: Color(0xFF2E2E34),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    accent: Color(0xFFFFFFFF),
    accentWarm: Color(0xFFF97316),
    accentMuted: Color(0x33FFFFFF),
    expenseCoral: Color(0xFFF87171),
    incomeMint: Color(0xFF34D399),

    // Bottom Nav Pill in Dark Mode: Sleek floating capsule with light-white border
    navBarBg: Color(0xFF18181B),
    navBarBorder: Color(0x38FFFFFF), // Light white distinction border
    navBarShadow: Color(0x99000000),
    navActiveCircle: Color(0xFFFFFFFF),
    navActiveIcon: Color(0xFF18181B),
    navInactiveIcon: Color(0xFF71717A),
  );

  static const light = AppTheme(
    isLight: true,
    scaffoldBackground: Color(0xFFF7F7F5), // Warm gallery off-white from reference UI
    card: Color(0xFFFFFFFF),
    cardSecondary: Color(0xFFECECE8), // Clean neutral secondary from reference UI
    border: Color(0xFFE4E4DF),
    textPrimary: Color(0xFF18181B), // Crisp deep slate/black
    textSecondary: Color(0xFF52525B),
    textMuted: Color(0xFFA1A1AA),
    accent: Color(0xFF18181B), // Solid black pill active state from reference UI
    accentWarm: Color(0xFFD9532F), // Warm terracotta accent from reference UI
    accentMuted: Color(0x1418181B),
    expenseCoral: Color(0xFFD9532F),
    incomeMint: Color(0xFF10B981),

    // Bottom Nav Pill in Light Mode: Pure white pill with solid black circle indicator
    navBarBg: Color(0xFFFFFFFF),
    navBarBorder: Color(0xFFE5E5DF),
    navBarShadow: Color(0x18000000),
    navActiveCircle: Color(0xFF18181B),
    navActiveIcon: Color(0xFFFFFFFF),
    navInactiveIcon: Color(0xFF71717A),
  );

  /// Material ThemeData for Light Mode
  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme;
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: light.scaffoldBackground,
      canvasColor: light.scaffoldBackground,
      cardColor: light.card,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(baseTextTheme).apply(
        bodyColor: light.textPrimary,
        displayColor: light.textPrimary,
      ),
      dialogTheme: DialogThemeData(backgroundColor: light.card),
      dividerColor: light.border,
      colorScheme: ColorScheme.light(
        surface: light.card,
        primary: light.accent,
        onPrimary: Colors.white,
        onSurface: light.textPrimary,
        outline: light.border,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: light.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: light.scaffoldBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: light.textPrimary),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: light.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Material ThemeData for Dark Mode
  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: dark.scaffoldBackground,
      canvasColor: dark.scaffoldBackground,
      cardColor: dark.card,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(baseTextTheme).apply(
        bodyColor: dark.textPrimary,
        displayColor: dark.textPrimary,
      ),
      dialogTheme: DialogThemeData(backgroundColor: dark.card),
      dividerColor: dark.border,
      colorScheme: ColorScheme.dark(
        surface: dark.card,
        primary: dark.accent,
        onPrimary: Colors.black,
        onSurface: dark.textPrimary,
        outline: dark.border,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark.scaffoldBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: dark.textPrimary),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: dark.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
