import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 红果短剧风格：深色沉浸底、浅色「我的」、圆角标签、强调橙红。
class HgColors {
  static const bg = Color(0xFF0C0C0D);
  static const bgElevated = Color(0xFF161618);
  static const overlay = Color(0x99000000);
  static const text = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xCCFFFFFF);
  static const textMuted = Color(0x99FFFFFF);
  static const accent = Color(0xFFFF4D3A);
  static const chip = Color(0x33FFFFFF);
  static const mineBg = Color(0xFFF4F5F7);
  static const mineCard = Color(0xFFFFFFFF);
  static const mineText = Color(0xFF1A1A1A);
  static const mineMuted = Color(0xFF8A8A8A);
  static const navDark = Color(0xFF111113);
  static const navLight = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: HgColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: HgColors.accent,
        secondary: HgColors.accent,
        surface: HgColors.bg,
        onSurface: HgColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: HgColors.bg,
        foregroundColor: HgColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      dividerColor: const Color(0x22FFFFFF),
    );
  }
}
