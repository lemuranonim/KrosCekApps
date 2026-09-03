// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. BRAND COLORS
// ─────────────────────────────────────────────────────────────────────────────
class AdvantaColors {
  AdvantaColors._();

  static const Color kcNavy       = Color(0xFF0D3A62);
  static const Color deepForest   = Color(0xFF0D3D2B);
  static const Color primaryGreen = Color(0xFF1A5E3F);
  static const Color midGreen     = Color(0xFF2E7D52);
  static const Color lightGreen   = Color(0xFF4CAF79);
  static const Color paleGreen    = Color(0xFFE8F5EE);

  static const Color gold         = Color(0xFFD4A017);
  static const Color goldLight    = Color(0xFFF2C84B);
  static const Color goldPale     = Color(0xFFFFF8E1);

  static const Color cream        = Color(0xFFFAF7F0);
  static const Color charcoal     = Color(0xFF1C2526);

  // Pastikan baris di bawah ini ada!
  static const Color softGrey     = Color(0xFFF4F5F4);

  static const Color dividerGrey  = Color(0xFFE0E3E0);
  static const Color mutedGrey    = Color(0xFF8E9A8E);

  static const Color success      = Color(0xFF2E7D52);
  static const Color successLight = Color(0xFFE8F5EE);
  static const Color error        = Color(0xFFD32F2F);
  static const Color errorLight   = Color(0xFFFFEBEE);
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. TYPOGRAPHY
// ─────────────────────────────────────────────────────────────────────────────
class AdvantaText {
  AdvantaText._();
  static const String _fontFamily = 'Nunito';

  static const TextStyle display = TextStyle(fontFamily: _fontFamily, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.2);
  static const TextStyle heading1 = TextStyle(fontFamily: _fontFamily, fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);
  static const TextStyle heading2 = TextStyle(fontFamily: _fontFamily, fontSize: 18, fontWeight: FontWeight.w700, height: 1.35);
  static const TextStyle heading3 = TextStyle(fontFamily: _fontFamily, fontSize: 15, fontWeight: FontWeight.w700, height: 1.4);
  static const TextStyle body1    = TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static const TextStyle body2    = TextStyle(fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w400, height: 1.5);
  static const TextStyle bodyBold = TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600, height: 1.5);
  static const TextStyle label    = TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w600, height: 1.4);
  static const TextStyle caption  = TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w400, height: 1.4);
  static const TextStyle button   = TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.2, height: 1.0);

  static const TextStyle brandTitle = TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5);
  static const TextStyle brandSubtitle = TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: 1.5);
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. RADII & SHADOWS
// ─────────────────────────────────────────────────────────────────────────────
class AdvantaRadius {
  AdvantaRadius._();
  static const BorderRadius cardRadius   = BorderRadius.all(Radius.circular(12.0));
  static const BorderRadius inputRadius  = BorderRadius.all(Radius.circular(12.0));
  static const BorderRadius chipRadius   = BorderRadius.all(Radius.circular(100.0));
  static const BorderRadius sheetRadius  = BorderRadius.vertical(top: Radius.circular(20.0));
  static const BorderRadius dialogRadius = BorderRadius.all(Radius.circular(16.0));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(12.0));
}

class AdvantaShadows {
  AdvantaShadows._();
  static List<BoxShadow> card(bool isDark) => [
    BoxShadow(
      color     : isDark ? Colors.black.withAlpha(80) : AdvantaColors.deepForest.withAlpha(18),
      blurRadius: 12,
      offset    : const Offset(0, 4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. THEME DATA (Light & Dark)
// ─────────────────────────────────────────────────────────────────────────────
class AdvantaTheme {
  AdvantaTheme._();

  // 🌞 LIGHT MODE: High Outdoor Readability
  static ThemeData light() {
    final colorScheme = const ColorScheme.light(
      primary         : AdvantaColors.primaryGreen,
      onPrimary       : Colors.white,
      secondary       : AdvantaColors.gold,
      onSecondary     : AdvantaColors.charcoal,
      surface         : AdvantaColors.cream,
      onSurface       : AdvantaColors.deepForest, // High contrast text
      error           : AdvantaColors.error,
      onError         : Colors.white,
    );

    return _buildTheme(colorScheme, AdvantaColors.softGrey);
  }

  // 🌙 DARK MODE: Corporate Luxury & Golden Harvest
  static ThemeData dark() {
    final colorScheme = const ColorScheme.dark(
      primary         : AdvantaColors.primaryGreen,
      onPrimary       : Colors.white,
      secondary       : AdvantaColors.goldLight,
      onSecondary     : AdvantaColors.deepForest,
      surface         : AdvantaColors.midGreen, // Cards/surfaces are midGreen
      onSurface       : AdvantaColors.goldLight, // Text/accents are goldLight
      error           : AdvantaColors.error,
      onError         : Colors.white,
    );

    return _buildTheme(colorScheme, AdvantaColors.deepForest); // Background is deepForest
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, Color scaffoldBgColor) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Nunito',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBgColor,

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AdvantaColors.deepForest : AdvantaColors.primaryGreen,
        foregroundColor: isDark ? AdvantaColors.goldLight : Colors.white,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: AdvantaText.brandTitle.copyWith(
          color: isDark ? AdvantaColors.goldLight : Colors.white,
        ),
        iconTheme: IconThemeData(color: isDark ? AdvantaColors.goldLight : Colors.white, size: 22),
      ),

      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AdvantaRadius.cardRadius,
          side: BorderSide(color: isDark ? AdvantaColors.goldLight.withAlpha(30) : AdvantaColors.charcoal.withAlpha(12)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: AdvantaText.button,
          shape: const RoundedRectangleBorder(borderRadius: AdvantaRadius.buttonRadius),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AdvantaColors.deepForest.withAlpha(150) : AdvantaColors.softGrey,
        labelStyle: AdvantaText.body2.copyWith(color: isDark ? AdvantaColors.goldLight.withAlpha(180) : AdvantaColors.mutedGrey),
        hintStyle: AdvantaText.body2.copyWith(color: isDark ? AdvantaColors.goldLight.withAlpha(150) : AdvantaColors.mutedGrey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: AdvantaRadius.inputRadius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: AdvantaRadius.inputRadius,
          borderSide: BorderSide(color: isDark ? AdvantaColors.goldLight.withAlpha(50) : AdvantaColors.charcoal.withAlpha(18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AdvantaRadius.inputRadius,
          borderSide: BorderSide(color: isDark ? AdvantaColors.goldLight : colorScheme.primary, width: 1.5),
        ),
      ),

      textTheme: TextTheme(
        displayLarge: AdvantaText.display.copyWith(color: colorScheme.onSurface),
        headlineLarge: AdvantaText.heading1.copyWith(color: colorScheme.onSurface),
        headlineMedium: AdvantaText.heading2.copyWith(color: colorScheme.onSurface),
        headlineSmall: AdvantaText.heading3.copyWith(color: colorScheme.onSurface),
        bodyLarge: AdvantaText.body1.copyWith(color: colorScheme.onSurface),
        bodyMedium: AdvantaText.body2.copyWith(color: colorScheme.onSurface),
        labelMedium: AdvantaText.label.copyWith(color: colorScheme.onSurface),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. REUSABLE WIDGETS (Context-Aware)
// ─────────────────────────────────────────────────────────────────────────────
class AdvantaBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const AdvantaBanner.error({super.key, required this.message}) : isError = true;
  const AdvantaBanner.info({super.key, required this.message}) : isError = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isError
        ? (isDark ? AdvantaColors.error.withAlpha(40) : AdvantaColors.errorLight)
        : (isDark ? AdvantaColors.midGreen.withAlpha(80) : AdvantaColors.paleGreen);

    final fg = isError
        ? (isDark ? const Color(0xFFFF8A80) : AdvantaColors.error)
        : (isDark ? AdvantaColors.goldLight : AdvantaColors.primaryGreen);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(color: fg.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline : Icons.info_outline, color: fg, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AdvantaText.body2.copyWith(color: fg, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
