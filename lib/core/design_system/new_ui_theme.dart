import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'theme.dart' as legacy;
import 'tokens.dart';

abstract final class NewUiTokens {
  static const primary = Color(0xFF007C91);
  static const primaryDeep = Color(0xFF005C6C);
  static const primaryLight = Color(0xFF5CCBDD);
  static const onHero = Color(0xFFFFFFFF);
  static const lightBackground = Color(0xFFF5FBFC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF10343A);
  static const lightMuted = Color(0xFF567073);
  static const lightBorder = Color(0xFFDCE9E8);
  static const inputBorder = Color(0xFF8794A8);
  static const darkInputBorder = Color(0xFF5F7782);
  static const lightSoftPrimary = Color(0xFFE8F6F8);
  static const heroStart = Color(0xFF00434E);
  static const darkBackground = Color(0xFF0B1418);
  static const darkSurface = Color(0xFF121E24);
  static const darkText = Color(0xFFE8F1F3);
  static const darkMuted = Color(0xFFA3B5BB);
  static const darkBorder = Color(0xFF1D2B31);
  static const darkSoftPrimary = Color(0xFF12343C);
  static const lightSuccess = AppTone(
    fg: Color(0xFF14693A),
    bg: Color(0xFFDDF3E4),
    border: Color(0xFF9ED9A4),
  );
  static const lightWarning = AppTone(
    fg: Color(0xFF8A5300),
    bg: Color(0xFFFFF0D6),
    border: Color(0xFFF2D48A),
  );
  static const lightError = AppTone(
    fg: Color(0xFFB3261E),
    bg: Color(0xFFFDE7E5),
    border: Color(0xFFF1B3A5),
  );
  static const darkSuccess = AppTone(
    fg: Color(0xFF7FDBA3),
    bg: Color(0xFF123A25),
    border: Color(0xFF24604A),
  );
  static const darkWarning = AppTone(
    fg: Color(0xFFF5C46B),
    bg: Color(0xFF3F2E0C),
    border: Color(0xFF6B5420),
  );
  static const darkError = AppTone(
    fg: Color(0xFFFF9B94),
    bg: Color(0xFF3F1B19),
    border: Color(0xFF6E3229),
  );
}

ThemeData buildNewUiLightTheme() => _buildNewUiTheme(Brightness.light);

ThemeData buildNewUiDarkTheme() => _buildNewUiTheme(Brightness.dark);

ThemeData _buildNewUiTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = dark ? legacy.buildDarkTheme() : legacy.buildLightTheme();
  final background =
      dark ? NewUiTokens.darkBackground : NewUiTokens.lightBackground;
  final surface = dark ? NewUiTokens.darkSurface : NewUiTokens.lightSurface;
  final ink = dark ? NewUiTokens.darkText : NewUiTokens.lightText;
  final muted = dark ? NewUiTokens.darkMuted : NewUiTokens.lightMuted;
  final border = dark ? NewUiTokens.darkBorder : NewUiTokens.lightBorder;
  final inputBorder =
      dark ? NewUiTokens.darkInputBorder : NewUiTokens.inputBorder;
  final softPrimary =
      dark ? NewUiTokens.darkSoftPrimary : NewUiTokens.lightSoftPrimary;
  final success = dark ? NewUiTokens.darkSuccess : NewUiTokens.lightSuccess;
  final warning = dark ? NewUiTokens.darkWarning : NewUiTokens.lightWarning;
  final error = dark ? NewUiTokens.darkError : NewUiTokens.lightError;
  final info = AppTone(
    fg: dark ? NewUiTokens.primaryLight : NewUiTokens.primaryDeep,
    bg: softPrimary,
    border: dark ? const Color(0xFF1F5A66) : const Color(0xFF9ADBE5),
  );
  final neutral = AppTone(
    fg: muted,
    bg: surface,
    border: border,
  );
  final appColors = (dark ? AppColors.dark : AppColors.light).copyWith(
    primary: NewUiTokens.primary,
    primaryDeep: dark ? NewUiTokens.primaryLight : NewUiTokens.primaryDeep,
    ink: ink,
    scaffold: background,
    surface: surface,
    hairline: border,
    mint: softPrimary,
    amber: dark ? const Color(0xFFF5C46B) : const Color(0xFFF5A524),
    success: success,
    warning: warning,
    danger: error,
    info: info,
    neutral: neutral,
    statusPending: warning,
    statusAccepted: info,
    statusAssigned: info,
    statusOnTheWay: success,
    statusDelivered: success,
    statusCancelled: neutral,
    statusRejected: error,
    brandGradient: const LinearGradient(
      colors: [NewUiTokens.primary, NewUiTokens.primaryDeep],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroGradient: const LinearGradient(
      colors: [NewUiTokens.heroStart, NewUiTokens.primary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    softSurfaceGradient: LinearGradient(
      colors: [surface, softPrimary],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    glassFill: dark ? const Color(0x14121E24) : const Color(0xB3FFFFFF),
    glassBorder: border,
    scrim: dark ? const Color(0xB30B1418) : const Color(0x66001A1F),
    shadowSoft: dark
        ? const []
        : const [
            BoxShadow(
              color: Color(0x120F1B2D),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
    shadowLifted: dark
        ? const []
        : const [
            BoxShadow(
              color: Color(0x1F0F1B2D),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
  );
  final colorScheme = base.colorScheme.copyWith(
    brightness: brightness,
    primary: NewUiTokens.primary,
    onPrimary: NewUiTokens.onHero,
    secondary: dark ? NewUiTokens.primaryLight : NewUiTokens.primaryDeep,
    onSecondary: dark ? NewUiTokens.darkBackground : NewUiTokens.onHero,
    surface: surface,
    onSurface: ink,
    onSurfaceVariant: muted,
    error: error.fg,
    onError: dark ? NewUiTokens.darkBackground : NewUiTokens.onHero,
  );
  final extensions = base.extensions.values
      .where((extension) => extension is! AppColors)
      .toList()
    ..add(appColors);

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    extensions: extensions,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: ink,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: ink,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: ink,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: ink,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: muted,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: BorderSide(color: inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: BorderSide(color: inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: const BorderSide(color: NewUiTokens.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: BorderSide(color: error.fg),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: BorderSide(color: error.fg, width: 2),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.pillBorder,
        side: BorderSide(color: border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor:
            dark ? NewUiTokens.primaryLight : NewUiTokens.primaryDeep,
        minimumSize: const Size(
          AppSize.minTouchTarget,
          AppSize.minTouchTarget,
        ),
      ),
    ),
  );
}
