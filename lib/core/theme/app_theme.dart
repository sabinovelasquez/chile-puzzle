import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const seedColor = Color(0xFF1B3A4B);
  static const trophyGold = Color(0xFFC9A961);
  static const accentGreen = Color(0xFF4CAF50);
  static const accentOrange = Color(0xFFE67E22);
  static const accentBlue = Color(0xFF3B82F6);
  static const accentPurple = Color(0xFF8B5CF6);
  static const ctaPurple = Color(0xFFB39DDB);
  static const surfaceGrey = Color(0xFFF5F5F7);
  static const creamBackground = Color(0xFFFAF5EA);

  static TextTheme get _textTheme {
    final body = GoogleFonts.plusJakartaSansTextTheme();
    final headings = GoogleFonts.spaceGroteskTextTheme();
    return body.copyWith(
      displayLarge: headings.displayLarge,
      displayMedium: headings.displayMedium,
      displaySmall: headings.displaySmall,
      headlineLarge: headings.headlineLarge,
      headlineMedium: headings.headlineMedium,
      headlineSmall: headings.headlineSmall,
      titleLarge: headings.titleLarge,
      titleMedium: headings.titleMedium,
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      surface: Colors.white,
    );

    final textTheme = _textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: surfaceGrey,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: seedColor,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: seedColor,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ctaPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: seedColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: Colors.grey.shade300),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
