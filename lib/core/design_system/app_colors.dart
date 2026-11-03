import 'package:flutter/material.dart';

import 'palette.dart';

/// A foreground, background and border color for a status or semantic tone.
/// Pair `fg` on `bg`; use `border` for outlines. Never rely on color alone:
/// pair a tone with an icon and text.
@immutable
class AppTone {
  const AppTone({required this.fg, required this.bg, required this.border});

  final Color fg;
  final Color bg;
  final Color border;

  AppTone lerp(AppTone other, double t) => AppTone(
        fg: Color.lerp(fg, other.fg, t)!,
        bg: Color.lerp(bg, other.bg, t)!,
        border: Color.lerp(border, other.border, t)!,
      );
}

/// Theme-aware design colors. Read with `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.primary,
    required this.primaryDeep,
    required this.ink,
    required this.scaffold,
    required this.surface,
    required this.hairline,
    required this.mint,
    required this.amber,
    required this.onHero,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.neutral,
    required this.statusPending,
    required this.statusAccepted,
    required this.statusAssigned,
    required this.statusOnTheWay,
    required this.statusDelivered,
    required this.statusCancelled,
    required this.statusRejected,
    required this.brandGradient,
    required this.heroGradient,
    required this.softSurfaceGradient,
    required this.successGradient,
    required this.warningGradient,
    required this.glassFill,
    required this.glassBorder,
    required this.scrim,
    required this.shadowSoft,
    required this.shadowLifted,
  });

  final Brightness brightness;
  final Color primary;
  final Color primaryDeep;
  final Color ink;
  final Color scaffold;
  final Color surface;
  final Color hairline;
  final Color mint;
  final Color amber;

  /// Text and icon color placed on the gradients and filled brand surfaces.
  final Color onHero;

  final AppTone success;
  final AppTone warning;
  final AppTone danger;
  final AppTone info;
  final AppTone neutral;

  final AppTone statusPending;
  final AppTone statusAccepted;
  final AppTone statusAssigned;
  final AppTone statusOnTheWay;
  final AppTone statusDelivered;
  final AppTone statusCancelled;
  final AppTone statusRejected;

  final LinearGradient brandGradient;
  final LinearGradient heroGradient;
  final LinearGradient softSurfaceGradient;
  final LinearGradient successGradient;
  final LinearGradient warningGradient;

  final Color glassFill;
  final Color glassBorder;
  final Color scrim;

  /// Colored, low-opacity elevation for light mode. Empty in dark mode, where
  /// surfaces use a hairline border instead.
  final List<BoxShadow> shadowSoft;
  final List<BoxShadow> shadowLifted;

  bool get isDark => brightness == Brightness.dark;

  /// Maps a backend booking status to its tone. Unknown statuses are neutral.
  AppTone statusTone(String status) => switch (status) {
        'pending' || 'pending_vendor' => statusPending,
        'accepted' || 'vendor_accepted' => statusAccepted,
        'assigned' || 'vendor_assigned' => statusAssigned,
        'in_transit' ||
        'on_the_way' ||
        'en_route' ||
        'arrived' =>
          statusOnTheWay,
        'delivered' || 'completed' => statusDelivered,
        'cancelled' || 'canceled' => statusCancelled,
        'rejected' => statusRejected,
        _ => neutral,
      };

  static const light = AppColors(
    brightness: Brightness.light,
    primary: AppPalette.teal,
    primaryDeep: AppPalette.tealDeep,
    ink: AppPalette.ink,
    scaffold: AppPalette.paper,
    surface: AppPalette.white,
    hairline: AppPalette.hairline,
    mint: AppPalette.mint,
    amber: AppPalette.amber,
    onHero: AppPalette.white,
    success: _lightSuccess,
    warning: _lightWarning,
    danger: _lightDanger,
    info: _lightInfo,
    neutral: _lightNeutral,
    statusPending: _lightWarning,
    statusAccepted: _lightInfo,
    statusAssigned: AppTone(
      fg: Color(0xFF3D3A8C),
      bg: Color(0xFFE4E2F8),
      border: Color(0xFFB9B5EC),
    ),
    statusOnTheWay: AppTone(
      fg: Color(0xFF0B6B4F),
      bg: Color(0xFFD5F2E6),
      border: Color(0xFF8FD9BC),
    ),
    statusDelivered: _lightSuccess,
    statusCancelled: _lightNeutral,
    statusRejected: _lightDanger,
    brandGradient: LinearGradient(
      colors: [AppPalette.teal, AppPalette.tealDeep],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroGradient: LinearGradient(
      colors: [AppPalette.ink, AppPalette.teal],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    softSurfaceGradient: LinearGradient(
      colors: [AppPalette.white, Color(0xFFE6F4F6)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    successGradient: LinearGradient(
      colors: [Color(0xFF1E6B2E), Color(0xFF2E8B57)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    warningGradient: LinearGradient(
      colors: [AppPalette.amber, Color(0xFFE9A93B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassFill: Color(0xB3FFFFFF),
    glassBorder: AppPalette.hairline,
    scrim: Color(0x66001A1F),
    shadowSoft: [
      BoxShadow(
        color: Color(0x1F007C91),
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
    ],
    shadowLifted: [
      BoxShadow(
        color: Color(0x33007C91),
        blurRadius: 36,
        offset: Offset(0, 16),
      ),
    ],
  );

  static const dark = AppColors(
    brightness: Brightness.dark,
    primary: AppPalette.tealLight,
    primaryDeep: AppPalette.teal,
    ink: AppPalette.ink,
    scaffold: AppPalette.darkScaffold,
    surface: AppPalette.darkSurface,
    hairline: AppPalette.darkHairline,
    mint: AppPalette.mint,
    amber: AppPalette.amber,
    onHero: AppPalette.white,
    success: _darkSuccess,
    warning: _darkWarning,
    danger: _darkDanger,
    info: _darkInfo,
    neutral: _darkNeutral,
    statusPending: _darkWarning,
    statusAccepted: _darkInfo,
    statusAssigned: AppTone(
      fg: Color(0xFFC5C3F5),
      bg: Color(0xFF2A2850),
      border: Color(0xFF4A4785),
    ),
    statusOnTheWay: AppTone(
      fg: Color(0xFF9BE8C4),
      bg: Color(0xFF10382A),
      border: Color(0xFF24604A),
    ),
    statusDelivered: _darkSuccess,
    statusCancelled: _darkNeutral,
    statusRejected: _darkDanger,
    // Deeper than the light-mode teal stop so white text (onHero) passes AA.
    brandGradient: LinearGradient(
      colors: [AppPalette.teal, AppPalette.tealDeep],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroGradient: LinearGradient(
      colors: [AppPalette.darkScaffold, Color(0xFF1B5A66)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    softSurfaceGradient: LinearGradient(
      colors: [AppPalette.darkSurface, Color(0xFF0F2024)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    successGradient: LinearGradient(
      colors: [Color(0xFF2E8B57), Color(0xFF1E6B2E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    warningGradient: LinearGradient(
      colors: [Color(0xFFE9A93B), Color(0xFF8A5A00)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassFill: Color(0x14FFFFFF),
    glassBorder: Color(0x1FFFFFFF),
    scrim: Color(0xB30B1B1E),
    shadowSoft: [],
    shadowLifted: [],
  );

  static const _lightSuccess = AppTone(
    fg: Color(0xFF1E6B2E),
    bg: Color(0xFFDDF3DF),
    border: Color(0xFF9ED9A4),
  );
  static const _lightWarning = AppTone(
    fg: Color(0xFF7A4B00),
    bg: Color(0xFFFDF1D2),
    border: Color(0xFFF2D48A),
  );
  static const _lightDanger = AppTone(
    fg: AppPalette.coral,
    bg: Color(0xFFFDEEEA),
    border: Color(0xFFF1B3A5),
  );
  static const _lightInfo = AppTone(
    fg: AppPalette.tealDeep,
    bg: Color(0xFFD6F0F4),
    border: AppPalette.teal200,
  );
  static const _lightNeutral = AppTone(
    fg: Color(0xFF3F5256),
    bg: Color(0xFFEEF4F4),
    border: AppPalette.hairline,
  );

  static const _darkSuccess = AppTone(
    fg: Color(0xFFA7E8AE),
    bg: Color(0xFF173B1C),
    border: Color(0xFF2E6236),
  );
  static const _darkWarning = AppTone(
    fg: AppPalette.amber,
    bg: Color(0xFF3A2E12),
    border: Color(0xFF6B5420),
  );
  static const _darkDanger = AppTone(
    fg: AppPalette.coralDark,
    bg: Color(0xFF3F1D17),
    border: Color(0xFF6E3229),
  );
  static const _darkInfo = AppTone(
    fg: Color(0xFF8EE3EE),
    bg: Color(0xFF0F3840),
    border: Color(0xFF1F5A66),
  );
  static const _darkNeutral = AppTone(
    fg: Color(0xFFC7D8DA),
    bg: Color(0xFF1A3236),
    border: AppPalette.darkHairline,
  );

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? primary,
    Color? primaryDeep,
    Color? ink,
    Color? scaffold,
    Color? surface,
    Color? hairline,
    Color? mint,
    Color? amber,
    Color? onHero,
    AppTone? success,
    AppTone? warning,
    AppTone? danger,
    AppTone? info,
    AppTone? neutral,
    AppTone? statusPending,
    AppTone? statusAccepted,
    AppTone? statusAssigned,
    AppTone? statusOnTheWay,
    AppTone? statusDelivered,
    AppTone? statusCancelled,
    AppTone? statusRejected,
    LinearGradient? brandGradient,
    LinearGradient? heroGradient,
    LinearGradient? softSurfaceGradient,
    LinearGradient? successGradient,
    LinearGradient? warningGradient,
    Color? glassFill,
    Color? glassBorder,
    Color? scrim,
    List<BoxShadow>? shadowSoft,
    List<BoxShadow>? shadowLifted,
  }) =>
      AppColors(
        brightness: brightness ?? this.brightness,
        primary: primary ?? this.primary,
        primaryDeep: primaryDeep ?? this.primaryDeep,
        ink: ink ?? this.ink,
        scaffold: scaffold ?? this.scaffold,
        surface: surface ?? this.surface,
        hairline: hairline ?? this.hairline,
        mint: mint ?? this.mint,
        amber: amber ?? this.amber,
        onHero: onHero ?? this.onHero,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        info: info ?? this.info,
        neutral: neutral ?? this.neutral,
        statusPending: statusPending ?? this.statusPending,
        statusAccepted: statusAccepted ?? this.statusAccepted,
        statusAssigned: statusAssigned ?? this.statusAssigned,
        statusOnTheWay: statusOnTheWay ?? this.statusOnTheWay,
        statusDelivered: statusDelivered ?? this.statusDelivered,
        statusCancelled: statusCancelled ?? this.statusCancelled,
        statusRejected: statusRejected ?? this.statusRejected,
        brandGradient: brandGradient ?? this.brandGradient,
        heroGradient: heroGradient ?? this.heroGradient,
        softSurfaceGradient: softSurfaceGradient ?? this.softSurfaceGradient,
        successGradient: successGradient ?? this.successGradient,
        warningGradient: warningGradient ?? this.warningGradient,
        glassFill: glassFill ?? this.glassFill,
        glassBorder: glassBorder ?? this.glassBorder,
        scrim: scrim ?? this.scrim,
        shadowSoft: shadowSoft ?? this.shadowSoft,
        shadowLifted: shadowLifted ?? this.shadowLifted,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDeep: Color.lerp(primaryDeep, other.primaryDeep, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      success: success.lerp(other.success, t),
      warning: warning.lerp(other.warning, t),
      danger: danger.lerp(other.danger, t),
      info: info.lerp(other.info, t),
      neutral: neutral.lerp(other.neutral, t),
      statusPending: statusPending.lerp(other.statusPending, t),
      statusAccepted: statusAccepted.lerp(other.statusAccepted, t),
      statusAssigned: statusAssigned.lerp(other.statusAssigned, t),
      statusOnTheWay: statusOnTheWay.lerp(other.statusOnTheWay, t),
      statusDelivered: statusDelivered.lerp(other.statusDelivered, t),
      statusCancelled: statusCancelled.lerp(other.statusCancelled, t),
      statusRejected: statusRejected.lerp(other.statusRejected, t),
      brandGradient:
          LinearGradient.lerp(brandGradient, other.brandGradient, t)!,
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
      softSurfaceGradient: LinearGradient.lerp(
        softSurfaceGradient,
        other.softSurfaceGradient,
        t,
      )!,
      successGradient:
          LinearGradient.lerp(successGradient, other.successGradient, t)!,
      warningGradient:
          LinearGradient.lerp(warningGradient, other.warningGradient, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      shadowSoft: BoxShadow.lerpList(shadowSoft, other.shadowSoft, t)!,
      shadowLifted: BoxShadow.lerpList(shadowLifted, other.shadowLifted, t)!,
    );
  }
}

/// Access the design colors from any widget: `context.colors.primary`.
extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
