import 'package:flutter/material.dart';

/// Shared visual language for the mobile learning experience.
///
/// The palette deliberately stays warm and quiet so translation content remains
/// the visual focus. Feature screens should prefer these theme tokens instead
/// of introducing one-off colors.
class AppTheme {
  static const pine = Color(0xFF1B4D3E);
  static const warmIvory = Color(0xFFFAF0E6);
  static const paper = Color(0xFFFFFDF9);
  static const caramel = Color(0xFFE5AA70);
  static const salmon = Color(0xFFF88379);
  static const ink = Color(0xFF263E35);
  static const warmLine = Color(0xFFDED5CA);
  static const sageWash = Color(0xFFDCEBE3);
  static const apricotWash = Color(0xFFF9E2C7);
  static const salmonWash = Color(0xFFFDE2DE);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: pine,
      brightness: Brightness.light,
    ).copyWith(
      primary: pine,
      onPrimary: Colors.white,
      primaryContainer: sageWash,
      onPrimaryContainer: ink,
      secondary: caramel,
      onSecondary: ink,
      secondaryContainer: apricotWash,
      onSecondaryContainer: ink,
      tertiary: salmon,
      onTertiary: ink,
      tertiaryContainer: salmonWash,
      onTertiaryContainer: ink,
      surface: paper,
      onSurface: ink,
      outline: warmLine,
    );

    final roundedShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: warmIvory,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: warmIvory,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: roundedShape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: warmLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: warmLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: pine, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: salmon),
        ),
        labelStyle: const TextStyle(color: Color(0xFF65756D)),
        floatingLabelStyle:
            const TextStyle(color: pine, fontWeight: FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paper,
        elevation: 8,
        height: 72,
        indicatorColor: sageWash,
        labelTextStyle: MaterialStatePropertyAll(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        iconTheme: MaterialStatePropertyAll(
          const IconThemeData(size: 22),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: sageWash,
        selectedColor: pine,
        secondarySelectedColor: pine,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
        color: warmLine,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
            color: ink),
        headlineSmall: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: ink),
        titleLarge:
            TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink),
        titleMedium:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
        bodyLarge: TextStyle(fontSize: 16, height: 1.35, color: ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.35, color: ink),
        labelLarge:
            TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink),
      ),
    );
  }
}
