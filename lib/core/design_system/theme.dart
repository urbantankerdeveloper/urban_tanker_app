import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

import 'app_colors.dart';
import 'palette.dart';
import 'tokens.dart';
import 'typography.dart';

/// Light theme: FlexColorScheme gives the base ColorScheme, then the component
/// themes below are rebuilt from the design tokens.
ThemeData buildLightTheme() => _buildTheme(Brightness.light);

ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final c = dark ? AppColors.dark : AppColors.light;
  final base = (dark
          ? FlexColorScheme.dark(
              primary: c.primary,
              secondary: c.mint,
              surface: c.surface,
              error: AppPalette.coralDark,
              appBarBackground: c.scaffold,
              scaffoldBackground: c.scaffold,
            )
          : FlexColorScheme.light(
              primary: c.primary,
              secondary: c.primaryDeep,
              surface: AppPalette.white,
              error: AppPalette.coral,
              scaffoldBackground: c.scaffold,
              appBarBackground: c.scaffold,
            ))
      .toTheme;
  final scheme = base.colorScheme;

  return base.copyWith(
    extensions: [...base.extensions.values, c],
    textTheme: buildAppTextTheme(
      base.textTheme,
      ink: dark ? scheme.onSurface : c.ink,
      muted: scheme.onSurfaceVariant,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.scaffold,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: c.hairline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? c.surface : AppPalette.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: BorderSide(color: c.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: BorderSide(color: c.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: BorderSide(color: c.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, AppSize.buttonHeight),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.inputBorder,
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, AppSize.buttonHeight),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.inputBorder,
        ),
        side: BorderSide(color: c.hairline),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(AppSize.minTouchTarget, AppSize.minTouchTarget),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: dark ? c.hairline : c.mint,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetBorder),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.inputBorder),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.chipBorder,
        side: BorderSide(color: c.hairline),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.xs,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.inputBorder),
    ),
    dividerTheme: DividerThemeData(
      color: c.hairline,
      space: 1,
      thickness: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.hairline,
    ),
    // Fade-upwards on every platform. A true shared-axis builder is a later step.
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
