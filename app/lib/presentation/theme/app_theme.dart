import 'package:flutter/material.dart';

import '../../core/brand.dart';

/// Design tokens for the Ruangin auth design (docs/design/*.jpg).
abstract final class AppColors {
  static const accent = BrandColors.primary;
  static const ink = Color(0xFF151515);

  /// Plain white surface (Welcome background, buttons, fields).
  static const surface = Colors.white;
  static const screen = Color(0xFFF9F8FC);
  static const appBar = Color(0xFFF4F4F6);
  static const field = surface;
  static const fieldBorder = Color(0xFFF1F1F5);
  static const outline = Color(0xFFC9CCDF);
  static const muted = Color(0xFF6B6B76);
  static const icon = Color(0xFF9A9AA5);
}

/// Font families bundled in assets/fonts (OFL). Both are variable fonts, so
/// weights are applied through the `wght` axis as well as [FontWeight].
abstract final class AppFonts {
  static const sans = 'Jost';
  static const serif = 'SourceSerif4';

  static TextStyle sansStyle(double size, int weight, {Color? color}) =>
      TextStyle(
        fontFamily: sans,
        fontSize: size,
        fontWeight: _weight(weight),
        fontVariations: [FontVariation.weight(weight.toDouble())],
        color: color,
      );

  static TextStyle serifStyle(double size, int weight, {Color? color}) =>
      TextStyle(
        fontFamily: serif,
        fontSize: size,
        fontWeight: _weight(weight),
        fontVariations: [FontVariation.weight(weight.toDouble())],
        color: color,
        height: 1.1,
      );

  static FontWeight _weight(int w) =>
      FontWeight.values[((w ~/ 100) - 1).clamp(0, 8)];
}

abstract final class AppTheme {
  static const radius = 12.0;
  static const buttonHeight = 52.0;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      surface: Colors.white,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final textTheme = base.textTheme.apply(
      fontFamily: AppFonts.sans,
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.screen,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.appBar,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppFonts.sansStyle(20, 600, color: const Color(0xFF55555E)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        hintStyle: AppFonts.sansStyle(16, 400, color: AppColors.icon),
        errorStyle: AppFonts.sansStyle(13, 400, color: scheme.error),
        border: border(AppColors.fieldBorder),
        enabledBorder: border(AppColors.fieldBorder),
        focusedBorder: border(AppColors.accent, 1.4),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 1.4),
        disabledBorder: border(AppColors.fieldBorder),
        suffixIconColor: AppColors.icon,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.ink.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(buttonHeight),
          shape: shape,
          textStyle: AppFonts.sansStyle(18, 600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.outline),
          shape: shape,
          textStyle: AppFonts.sansStyle(17, 600),
        ),
      ),
      // Chevron back button as in the image/ui-ux headers.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) =>
            const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: AppFonts.sansStyle(15, 400, color: Colors.white),
      ),
    );
  }
}
