import 'package:flutter/material.dart';

/// Visual language for the mobile app: warm paper, deep moss ink, and coral
/// actions. Keeping these values here prevents individual screens from
/// drifting into slightly different versions of the brand.
class AppTheme {
  AppTheme._();

  static const paper = Color(0xFFF8F5EF);
  static const sand = Color(0xFFEEE8DD);
  static const ivory = Color(0xFFFFFDF9);
  static const moss = Color(0xFF1B4B43);
  static const coral = Color(0xFFF26B5E);
  static const coralTint = Color(0xFFFBE0D8);
  static const sage = Color(0xFFA9B9AC);
  static const line = Color(0xFFD9D0C4);
  static const cranberry = Color(0xFFA74443);

  static const spaceXs = 4.0;
  static const spaceSm = 8.0;
  static const spaceMd = 16.0;
  static const spaceLg = 24.0;
  static const spaceXl = 32.0;
  static const radiusMd = 16.0;
  static const radiusLarge = 22.0;

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: moss,
      onPrimary: ivory,
      primaryContainer: coralTint,
      onPrimaryContainer: moss,
      secondary: coral,
      onSecondary: ivory,
      secondaryContainer: sand,
      onSecondaryContainer: moss,
      surface: paper,
      onSurface: moss,
      surfaceContainerHighest: sand,
      outline: line,
      error: cranberry,
      onError: ivory,
    );

    final baseText = ThemeData.light().textTheme.apply(
          bodyColor: moss,
          displayColor: moss,
          fontFamily: 'sans-serif',
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      fontFamily: 'sans-serif',
      textTheme: baseText.copyWith(
        displayLarge: const TextStyle(
          fontFamily: 'serif',
          fontSize: 36,
          height: 1.08,
          fontWeight: FontWeight.w700,
          color: moss,
        ),
        displaySmall: const TextStyle(
          fontFamily: 'serif',
          fontSize: 30,
          height: 1.12,
          fontWeight: FontWeight.w700,
          color: moss,
        ),
        headlineSmall: const TextStyle(
          fontFamily: 'serif',
          fontSize: 25,
          height: 1.16,
          fontWeight: FontWeight.w700,
          color: moss,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: moss,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: moss,
        ),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.45, color: moss),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.4, color: moss),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: moss,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: moss,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'serif',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: moss,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: ivory,
        elevation: 1,
        shadowColor: const Color(0x221B4B43),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ivory,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        labelStyle: const TextStyle(color: moss, fontWeight: FontWeight.w700),
        hintStyle: TextStyle(color: moss.withValues(alpha: .5)),
        prefixIconColor: moss,
        suffixIconColor: moss,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: moss, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: cranberry),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: cranberry, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: coral,
          foregroundColor: ivory,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: moss,
          side: const BorderSide(color: line),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: moss,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ivory,
        surfaceTintColor: Colors.transparent,
        indicatorColor: coralTint,
        elevation: 8,
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? moss
                : moss.withValues(alpha: .55),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? moss
                : moss.withValues(alpha: .55),
            size: 22,
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: moss,
        unselectedLabelColor: sage,
        indicatorColor: coral,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: sand,
        selectedColor: coralTint,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(color: moss, fontWeight: FontWeight.w700),
        secondaryLabelStyle: const TextStyle(
          color: moss,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: coral),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: moss,
        contentTextStyle: TextStyle(color: ivory, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
