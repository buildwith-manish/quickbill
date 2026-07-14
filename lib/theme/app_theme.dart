import 'package:flutter/material.dart';

/// Material 3 theme tuned for an invoicing app — calm, business-formal,
/// with a single accent color (deep indigo) and clear hierarchy.
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF1F4E8C); // deep indigo-blue
  static const Color _accent = Color(0xFFEF8A17); // saffron accent

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
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
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
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
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Color.lerp(scheme.surface, scheme.onSurface, 0.05)!,
        labelStyle: TextStyle(color: scheme.onSurface),
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
        AppColors(
          accent: _accent,
          success: const Color(0xFF2E7D32),
          warning: const Color(0xFFB26A00),
          danger: const Color(0xFFC62828),
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
