/// The Kise theme.
///
/// Material 3 from a seed colour, chosen by the Owner in Settings. Four palettes: the Ethiopian
/// flag's green (the default), a sunset orange, a wine burgundy and an ocean blue. Around whichever
/// is chosen sit the same neutrals — a faintly tinted page, white cards, near-black ink — so the app
/// keeps its character and only its colour changes.
///
/// Everything that is *not* derivable from the seed lives in [KiseColors], a theme extension: the
/// hero gradient, the text colour on it, and the accent that marks day-to-day spending against the
/// primary colour of commitments. Widgets read it with `Theme.of(context).extension<KiseColors>()`.
library;

import 'package:flutter/material.dart';

/// Light, dark, or follow the device. [wire] is what gets persisted; a value that no longer parses
/// falls back to [system], so the app never crashes on an old or corrupt preference.
enum AppThemeMode {
  system(wire: 'system', nameAm: 'እንደ ስልኩ', nameEn: 'System'),
  light(wire: 'light', nameAm: 'ብርሃን', nameEn: 'Light'),
  dark(wire: 'dark', nameAm: 'ጨለማ', nameEn: 'Dark');

  const AppThemeMode({required this.wire, required this.nameAm, required this.nameEn});

  final String wire;
  final String nameAm;
  final String nameEn;

  String name(bool amharic) => amharic ? nameAm : nameEn;

  ThemeMode get material => switch (this) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  static AppThemeMode parse(String? value) => AppThemeMode.values.firstWhere(
        (mode) => mode.wire == value?.trim().toLowerCase(),
        orElse: () => AppThemeMode.system,
      );
}

/// The selectable palettes. [wire] is what gets persisted, so renaming a value is safe but reordering
/// or changing a wire string is not.
enum AppTheme {
  forest(
    wire: 'forest',
    nameAm: 'አረንጓዴ',
    nameEn: 'Forest',
    seed: Color(0xFF078930),
    heroLight: [Color(0xFF0B5A34), Color(0xFF1B944F)],
    heroDark: [Color(0xFF0A3A24), Color(0xFF12603A)],
    accent: Color(0xFFC98500),
  ),
  sunset(
    wire: 'sunset',
    nameAm: 'ብርቱካናማ',
    nameEn: 'Sunset',
    seed: Color(0xFFE65100),
    heroLight: [Color(0xFF9A3400), Color(0xFFE0641A)],
    heroDark: [Color(0xFF5C1E00), Color(0xFFA34410)],
    accent: Color(0xFF0E8A7B),
  ),
  wine(
    wire: 'wine',
    nameAm: 'ወይን ጠጅ',
    nameEn: 'Burgundy',
    seed: Color(0xFF7B1E3A),
    heroLight: [Color(0xFF4E0F24), Color(0xFF962C4C)],
    heroDark: [Color(0xFF330A18), Color(0xFF6B1D36)],
    accent: Color(0xFFC98500),
  ),
  ocean(
    wire: 'ocean',
    nameAm: 'ሰማያዊ',
    nameEn: 'Ocean',
    seed: Color(0xFF1E5AA8),
    heroLight: [Color(0xFF0F3A73), Color(0xFF2A6FD1)],
    heroDark: [Color(0xFF0A2547), Color(0xFF1B4C8F)],
    accent: Color(0xFFC98500),
  );

  const AppTheme({
    required this.wire,
    required this.nameAm,
    required this.nameEn,
    required this.seed,
    required this.heroLight,
    required this.heroDark,
    required this.accent,
  });

  final String wire;
  final String nameAm;
  final String nameEn;
  final Color seed;
  final List<Color> heroLight;
  final List<Color> heroDark;
  final Color accent;

  String name(bool amharic) => amharic ? nameAm : nameEn;

  List<Color> heroGradient(Brightness brightness) =>
      brightness == Brightness.dark ? heroDark : heroLight;

  /// A stored value that no longer parses falls back to the default rather than crashing the app.
  static AppTheme parse(String? value) => AppTheme.values.firstWhere(
        (theme) => theme.wire == value?.trim().toLowerCase(),
        orElse: () => AppTheme.forest,
      );
}

/// Colours the seed cannot produce, carried on the [ThemeData] so widgets need no other import.
class KiseColors extends ThemeExtension<KiseColors> {
  const KiseColors({
    required this.heroGradient,
    required this.heroForeground,
    required this.accent,
  });

  /// Top-left to bottom-right, behind the dashboard and settings headers.
  final List<Color> heroGradient;

  /// Text and icons on the gradient. White in every palette: each gradient is deep enough.
  final Color heroForeground;

  /// The second colour of the fixed/dynamic split, distinct from the primary under colour-vision
  /// deficiency.
  final Color accent;

  @override
  KiseColors copyWith({List<Color>? heroGradient, Color? heroForeground, Color? accent}) =>
      KiseColors(
        heroGradient: heroGradient ?? this.heroGradient,
        heroForeground: heroForeground ?? this.heroForeground,
        accent: accent ?? this.accent,
      );

  @override
  KiseColors lerp(KiseColors? other, double t) {
    if (other == null) return this;
    return KiseColors(
      heroGradient: [
        for (var i = 0; i < heroGradient.length; i++)
          Color.lerp(heroGradient[i], other.heroGradient[i % other.heroGradient.length], t)!,
      ],
      heroForeground: Color.lerp(heroForeground, other.heroForeground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

ThemeData buildTheme({
  AppTheme theme = AppTheme.forest,
  Brightness brightness = Brightness.light,
}) {
  final dark = brightness == Brightness.dark;
  // Fidelity keeps the primary close to the seed; the default tonal-spot variant would turn the
  // sunset orange into a brown.
  var scheme = ColorScheme.fromSeed(
    seedColor: theme.seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  if (!dark) {
    // A faint wash of the seed on the page so the white cards lift off it and the hero feels at
    // home. Derived, so a new palette needs no hand-picked neutrals.
    Color wash(double amount) => Color.alphaBlend(theme.seed.withValues(alpha: amount), Colors.white);
    scheme = scheme.copyWith(
      surface: wash(0.02),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: wash(0.06),
      surfaceContainerHighest: wash(0.13),
      onSurface: const Color(0xFF191B1A),
      onSurfaceVariant: const Color(0xFF5C625E),
      outlineVariant: wash(0.22),
    );
  }
  final page = dark ? scheme.surface : scheme.surfaceContainerLow;
  final card = dark ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest;

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    extensions: [
      KiseColors(
        heroGradient: theme.heroGradient(brightness),
        heroForeground: Colors.white,
        accent: theme.accent,
      ),
    ],
    scaffoldBackgroundColor: page,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: page,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      elevation: 0,
      height: 72,
      // The selected tab wears the palette's primary, like the action button, rather than
      // Material's default near-black on a pastel pill.
      indicatorColor: scheme.primary.withValues(alpha: dark ? 0.22 : 0.14),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: card,
    ),
  );
}
