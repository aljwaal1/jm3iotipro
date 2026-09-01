import 'package:flutter/material.dart';

class AC {
  static const bg = Color(0xFF060915);
  static const surface = Color(0xFF0B1123);
  static const card = Color(0xFF101A32);
  static const card2 = Color(0xFF16233F);
  static const border = Color(0xFF243657);
  static const borderSoft = Color(0xFF1B2A48);

  static const text = Color(0xFFF7F9FF);
  static const muted = Color(0xFFA6B5D1);
  static const hint = Color(0xFF667A9F);

  static const primary = Color(0xFF6C8CFF);
  static const cyan = Color(0xFF22D3EE);
  static const teal = Color(0xFF35E0B2);
  static const amber = Color(0xFFFFC857);
  static const rose = Color(0xFFFF6B8B);
  static const violet = Color(0xFFB388FF);

  static const heroGrad = LinearGradient(
    colors: [Color(0xFF5B6CFF), Color(0xFF2C4DB8), Color(0xFF087D8C)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const cardGrad = LinearGradient(
    colors: [Color(0xFF15284D), Color(0xFF101A32)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const successGrad = LinearGradient(
    colors: [Color(0xFF0C8B75), Color(0xFF116A89)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AC.bg,
    colorScheme: const ColorScheme.dark(
      surface: AC.card,
      primary: AC.primary,
      secondary: AC.teal,
      tertiary: AC.violet,
      error: AC.rose,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AC.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AC.text,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: AC.muted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: AC.surface,
      indicatorColor: AC.primary.withValues(alpha: 0.20),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected) ? AC.primary : AC.hint,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected) ? AC.text : AC.muted,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w500,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AC.card2,
      labelStyle: const TextStyle(color: AC.muted),
      hintStyle: const TextStyle(color: AC.hint),
      prefixIconColor: AC.muted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AC.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AC.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AC.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AC.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AC.text,
        side: const BorderSide(color: AC.border),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AC.card2,
      selectedColor: AC.primary.withValues(alpha: 0.22),
      side: const BorderSide(color: AC.border),
      labelStyle: const TextStyle(color: AC.text, fontSize: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AC.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AC.card2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
