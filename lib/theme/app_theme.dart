import 'package:flutter/material.dart';

/// Invory brand theme — modern, premium, global-first.
///
/// Brand palette (per rebrand spec):
///   Primary    #2563EB  (blue-600)
///   Secondary  #3B82F6  (blue-500)
///   Accent     #10B981  (emerald-500)
///   Background #F8FAFC  (slate-50)
///   Surface    #FFFFFF
///   Text       #0F172A  (slate-900)
class AppTheme {
  AppTheme._();

  // Brand colors — single source of truth.
  static const Color _primary = Color(0xFF2563EB); // #2563EB
  static const Color _secondary = Color(0xFF3B82F6); // #3B82F6
  static const Color _accent = Color(0xFF10B981); // #10B981
  static const Color _background = Color(0xFFF8FAFC); // #F8FAFC
  static const Color _surface = Color(0xFFFFFFFF); // #FFFFFF
  static const Color _text = Color(0xFF0F172A); // #0F172A

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
      primary: _primary,
      secondary: _secondary,
      surface: _surface,
      onSurface: _text,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _background,
      appBarTheme: AppBarTheme(
        backgroundColor: _surface,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: _text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: _surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: _surface,
        selectedItemColor: _primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Color.lerp(_surface, _text, 0.05)!,
        labelStyle: const TextStyle(color: _text),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      extensions: [
        const AppColors(
          accent: _accent,
          success: Color(0xFF10B981), // emerald-500
          warning: Color(0xFFF59E0B), // amber-500
          danger: Color(0xFFEF4444), // red-500
        ),
      ],
    );
  }
}

/// Semantic colors not covered by Material 3's [ColorScheme].
class AppColors extends ThemeExtension<AppColors> {
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;

  const AppColors({
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
  });

  @override
  AppColors copyWith({
    Color? accent,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Convenience for reading [AppColors] off the theme.
AppColors appColors(BuildContext context) =>
    Theme.of(context).extension<AppColors>()!;

/// Subtle background tint, used wherever the design needs a "container higher
/// than surface" role. Uses [Color.lerp] so it works on Flutter 3.19+
/// (before `ColorScheme.surfaceContainerHighest` was added in 3.22).
extension ColorSchemeSurfaceTint on ColorScheme {
  Color get subtleContainer => Color.lerp(surface, onSurface, 0.05)!;
  Color get subtleContainerStrong => Color.lerp(surface, onSurface, 0.08)!;
}
