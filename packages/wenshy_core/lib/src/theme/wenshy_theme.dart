import 'package:flutter/material.dart';

export '../widgets/wenshy_widgets.dart';

/// Brand and semantic color palette for the Wenshy (ونشي) roadside-rescue
/// platform.
abstract final class WenshyColors {
  /// Primary Amber/Gold (`#F59E0B`).
  static const Color amber = Color(0xFFF59E0B);

  /// Darker Amber variant for legible text/badges on light backgrounds.
  static const Color amberDark = Color(0xFFB45309);

  /// Soft Amber tint for highlights and active selection surfaces.
  static const Color amberSoft = Color(0xFFFEF3C7);

  /// Deep Slate (`#0F172A`) for primary dark surfaces, typography, and headers.
  static const Color deepSlate = Color(0xFF0F172A);

  /// Elevated Slate (`#1E293B`) for dark-mode cards and sheets.
  static const Color slateElevated = Color(0xFF1E293B);

  /// Muted Slate (`#64748B`) for secondary labels and borders.
  static const Color slateMuted = Color(0xFF64748B);

  /// Emerald (`#10B981`) for success, approved drivers, and completed trips.
  static const Color emerald = Color(0xFF10B981);

  /// Red (`#EF4444`) for errors, rejections, cancellations, and emergency SOS.
  static const Color red = Color(0xFFEF4444);

  /// Informational Blue (`#2563EB`) for active dispatch / under-review states.
  static const Color info = Color(0xFF2563EB);

  /// Light canvas background (`#F8FAFC`).
  static const Color lightBackground = Color(0xFFF8FAFC);

  /// Light card surface (`#FFFFFF`).
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Subtle neutral border (`#E2E8F0`).
  static const Color lightBorder = Color(0xFFE2E8F0);
}

/// Material 3, RTL-friendly theme factory for Wenshy Customer & Driver apps.
abstract final class WenshyTheme {
  /// Default Arabic-friendly brand font family.
  static const String defaultFontFamily = 'Cairo';

  /// Cross-platform Arabic + Latin fallback font stack that works cleanly
  /// offline and in headless widget tests without network font downloads.
  static const List<String> defaultFontFamilyFallback = <String>[
    'Cairo',
    'Tajawal',
    'Noto Sans Arabic',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  /// Light Material 3 theme featuring Amber/Gold `#F59E0B` primary accents,
  /// Deep Slate `#0F172A` typography/headers, and crisp high-contrast surfaces.
  static ThemeData light({String? fontFamily}) {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: WenshyColors.amber,
      onPrimary: WenshyColors.deepSlate,
      primaryContainer: WenshyColors.amberSoft,
      onPrimaryContainer: WenshyColors.deepSlate,
      secondary: WenshyColors.deepSlate,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE2E8F0),
      onSecondaryContainer: WenshyColors.deepSlate,
      tertiary: WenshyColors.emerald,
      onTertiary: Colors.white,
      error: WenshyColors.red,
      onError: Colors.white,
      surface: WenshyColors.lightSurface,
      onSurface: WenshyColors.deepSlate,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: WenshyColors.lightBackground,
      surfaceContainer: Color(0xFFF1F5F9),
      surfaceContainerHigh: Color(0xFFE2E8F0),
      onSurfaceVariant: WenshyColors.slateMuted,
      outline: WenshyColors.lightBorder,
      outlineVariant: Color(0xFFCBD5E1),
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: WenshyColors.lightBackground,
      fontFamily: fontFamily,
    );
  }

  /// Dark Material 3 theme built on Deep Slate `#0F172A` and Amber `#F59E0B`.
  static ThemeData dark({String? fontFamily}) {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: WenshyColors.amber,
      onPrimary: WenshyColors.deepSlate,
      primaryContainer: Color(0xFF78350F),
      onPrimaryContainer: WenshyColors.amberSoft,
      secondary: WenshyColors.emerald,
      onSecondary: WenshyColors.deepSlate,
      secondaryContainer: WenshyColors.slateElevated,
      onSecondaryContainer: Colors.white,
      tertiary: WenshyColors.emerald,
      onTertiary: WenshyColors.deepSlate,
      error: WenshyColors.red,
      onError: Colors.white,
      surface: WenshyColors.slateElevated,
      onSurface: Color(0xFFF8FAFC),
      surfaceContainerLowest: WenshyColors.deepSlate,
      surfaceContainerLow: Color(0xFF162032),
      surfaceContainer: WenshyColors.slateElevated,
      surfaceContainerHigh: Color(0xFF334155),
      onSurfaceVariant: Color(0xFF94A3B8),
      outline: Color(0xFF334155),
      outlineVariant: Color(0xFF475569),
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: WenshyColors.deepSlate,
      fontFamily: fontFamily,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    String? fontFamily,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(14);
    final resolvedFontFamily =
        (fontFamily != null && fontFamily.trim().isNotEmpty)
            ? fontFamily.trim()
            : defaultFontFamily;
    final textTheme = _buildTextTheme(
      colorScheme: colorScheme,
      fontFamily: resolvedFontFamily,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      fontFamily: resolvedFontFamily,
      fontFamilyFallback: defaultFontFamilyFallback,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? WenshyColors.deepSlate : Colors.white,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          height: 1.35,
          fontWeight: FontWeight.w700,
          fontFamily: resolvedFontFamily,
          fontFamilyFallback: defaultFontFamilyFallback,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF162032) : Colors.white,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: WenshyColors.amber, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: WenshyColors.red, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: WenshyColors.red, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          textStyle: TextStyle(
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w700,
            fontFamily: resolvedFontFamily,
            fontFamilyFallback: defaultFontFamilyFallback,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          textStyle: TextStyle(
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w700,
            fontFamily: resolvedFontFamily,
            fontFamilyFallback: defaultFontFamilyFallback,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          textStyle: TextStyle(
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w600,
            fontFamily: resolvedFontFamily,
            fontFamilyFallback: defaultFontFamilyFallback,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: colorScheme.outline),
        labelStyle: textTheme.labelMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
      ),
    );
  }

  static TextTheme _buildTextTheme({
    required ColorScheme colorScheme,
    required String fontFamily,
  }) {
    TextStyle style({
      required double size,
      required FontWeight weight,
      required double height,
      Color? color,
      double? letterSpacing,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: defaultFontFamilyFallback,
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? colorScheme.onSurface,
        letterSpacing: letterSpacing,
      );
    }

    return TextTheme(
      displaySmall: style(size: 30, weight: FontWeight.w800, height: 1.25),
      headlineLarge: style(size: 26, weight: FontWeight.w800, height: 1.3),
      headlineMedium: style(size: 22, weight: FontWeight.w700, height: 1.3),
      headlineSmall: style(size: 20, weight: FontWeight.w700, height: 1.35),
      titleLarge: style(size: 18, weight: FontWeight.w700, height: 1.35),
      titleMedium: style(size: 16, weight: FontWeight.w700, height: 1.4),
      titleSmall: style(size: 14, weight: FontWeight.w600, height: 1.4),
      bodyLarge: style(size: 16, weight: FontWeight.w400, height: 1.5),
      bodyMedium: style(size: 14, weight: FontWeight.w400, height: 1.5),
      bodySmall: style(
        size: 12,
        weight: FontWeight.w400,
        height: 1.45,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: style(size: 14, weight: FontWeight.w700, height: 1.35),
      labelMedium: style(size: 12, weight: FontWeight.w600, height: 1.35),
      labelSmall: style(
        size: 11,
        weight: FontWeight.w600,
        height: 1.35,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
