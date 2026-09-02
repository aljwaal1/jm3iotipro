export 'dart:typed_data';

import 'package:flutter/material.dart';

class AC {
  static const bg = Color(0xFF07110F);
  static const surface = Color(0xFF0B1714);
  static const card = Color(0xFF10201C);
  static const card2 = Color(0xFF172A25);
  static const border = Color(0xFF2A453D);
  static const borderSoft = Color(0xFF20372F);

  static const text = Color(0xFFF3F7F4);
  static const muted = Color(0xFFA9BCB5);
  static const hint = Color(0xFF708B82);

  static const primary = Color(0xFF70D2B2);
  static const cyan = Color(0xFF72D8CE);
  static const teal = Color(0xFF42CFA4);
  static const amber = Color(0xFFE8C46B);
  static const rose = Color(0xFFFF7B8D);
  static const violet = Color(0xFFC4A7D7);

  static const heroGrad = LinearGradient(
    colors: [Color(0xFF216653), Color(0xFF194B40), Color(0xFF12332D)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const cardGrad = LinearGradient(
    colors: [Color(0xFF173029), Color(0xFF10201C)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const successGrad = LinearGradient(
    colors: [Color(0xFF1B7159), Color(0xFF315B4C)],
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
      tertiary: AC.amber,
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
      indicatorColor: AC.primary.withValues(alpha: 0.14),
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
        foregroundColor: const Color(0xFF07251C),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
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
      selectedColor: AC.primary.withValues(alpha: 0.16),
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
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AC.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: AC.hint,
    ),
  );
}
