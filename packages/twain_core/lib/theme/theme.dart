import 'package:flutter/material.dart';
import 'tokens.dart';
import 'typography.dart';

class TTheme {
  TTheme._();

  static ThemeData light() {
    const primary = TTokens.primary900;
    const onPrimary = TTokens.neutral0;
    const surface = TTokens.neutral0;
    const onSurface = TTokens.neutral900;

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: TTokens.primary50,
      onPrimaryContainer: TTokens.primary900,
      secondary: TTokens.ai500,
      onSecondary: TTokens.neutral0,
      secondaryContainer: TTokens.ai50,
      onSecondaryContainer: TTokens.ai700,
      tertiary: TTokens.ai500,
      onTertiary: TTokens.neutral0,
      error: TTokens.danger,
      onError: TTokens.neutral0,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: TTokens.neutral0,
      surfaceContainerLow: TTokens.neutral50,
      surfaceContainer: TTokens.neutral100,
      surfaceContainerHigh: TTokens.neutral200,
      surfaceContainerHighest: TTokens.neutral200,
      outline: TTokens.neutral300,
      outlineVariant: TTokens.neutral200,
    );

    final textTheme = TTypography.textTheme(onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: TTokens.neutral50,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TTokens.r6),
          side: const BorderSide(color: TTokens.neutral200),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: TTokens.neutral200,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TTokens.r4),
          borderSide: const BorderSide(color: TTokens.neutral300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TTokens.r4),
          borderSide: const BorderSide(color: TTokens.neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TTokens.r4),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TTokens.r4),
          borderSide: const BorderSide(color: TTokens.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TTokens.r4),
          borderSide: const BorderSide(color: TTokens.danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TTokens.s4,
          vertical: TTokens.s3,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: TTokens.neutral500),
        hintStyle: textTheme.bodyMedium?.copyWith(color: TTokens.neutral400),
        helperStyle: textTheme.bodySmall?.copyWith(color: TTokens.neutral500),
        errorStyle: textTheme.bodySmall?.copyWith(color: TTokens.danger),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: TTokens.neutral100,
        selectedColor: TTokens.primary50,
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: TTokens.s3, vertical: TTokens.s1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TTokens.rFull),
          side: const BorderSide(color: Colors.transparent),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TTokens.neutral900,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: TTokens.neutral0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TTokens.r4),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
