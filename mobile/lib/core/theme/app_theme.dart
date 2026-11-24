import 'package:flutter/material.dart';

/// Central palette. Calm, editorial, and deliberately low-saturation so that
/// the match-status colors carry the meaning.
class AppColors {
  const AppColors._();

  static const indigo = Color(0xFF4F46E5);
  static const indigoDeep = Color(0xFF312E81);
  static const ink = Color(0xFF0F172A);
  static const slate = Color(0xFF475569);
  static const muted = Color(0xFF64748B);
  static const canvas = Color(0xFFF6F7FB);
  static const border = Color(0xFFE2E8F0);
  static const field = Color(0xFFF8FAFC);

  static const matched = Color(0xFF047857);
  static const matchedSoft = Color(0xFFECFDF5);
  static const related = Color(0xFFB45309);
  static const relatedSoft = Color(0xFFFFFBEB);
  static const missing = Color(0xFFBE123C);
  static const missingSoft = Color(0xFFFFF1F2);
  static const info = Color(0xFF0369A1);
  static const infoSoft = Color(0xFFF0F9FF);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.indigo,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.indigo,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: AppColors.ink,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    error: AppColors.missing,
  );

  final baseText = ThemeData.light().textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      );

  final textTheme = baseText.copyWith(
    displaySmall: baseText.displaySmall?.copyWith(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.1,
      height: 1.1,
    ),
    headlineMedium: baseText.headlineMedium?.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.7,
      height: 1.2,
    ),
    headlineSmall: baseText.headlineSmall?.copyWith(
      fontSize: 21,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    titleLarge: baseText.titleLarge?.copyWith(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleMedium: baseText.titleMedium?.copyWith(
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: baseText.bodyLarge?.copyWith(
      fontSize: 15.5,
      height: 1.5,
      color: AppColors.slate,
    ),
    bodyMedium: baseText.bodyMedium?.copyWith(
      fontSize: 14,
      height: 1.5,
      color: AppColors.slate,
    ),
    bodySmall: baseText.bodySmall?.copyWith(
      fontSize: 12.5,
      height: 1.4,
      color: AppColors.muted,
    ),
    labelLarge: baseText.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 20),
      iconTheme: const IconThemeData(color: AppColors.ink),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.indigo,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
      labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.slate),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.indigo, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.missing),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.missing, width: 1.6),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.indigo.withValues(alpha: 0.10),
      height: 68,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11.5,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.indigo
              : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected)
              ? AppColors.indigo
              : AppColors.muted,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.field,
      side: const BorderSide(color: AppColors.border),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.slate,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.indigo,
      linearTrackColor: AppColors.border,
      linearMinHeight: 8,
    ),
  );
}
