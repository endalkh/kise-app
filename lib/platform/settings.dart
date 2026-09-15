/// The Owner's personal settings, and where they are kept.
///
/// Calendar and language are settings rather than device locale choices: an Ethiopian user on an
/// English phone still wants ሐምሌ, and someone abroad may want Gregorian while reading Amharic.
/// Guessing from the locale would get both wrong.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared_kernel/money.dart';
import '../shared_kernel/period.dart';
import 'theme.dart';

class AppSettings {
  const AppSettings({
    this.ownerName = '',
    this.calendar = CalendarKind.ethiopian,
    this.language = Language.amharic,
    this.currency = defaultCurrency,
    this.monthlyBudgetMinor = 0,
    this.theme = AppTheme.forest,
    this.themeMode = AppThemeMode.system,
  });

  /// Shown in the greeting. Empty until the person sets it, and the UI adapts rather than
  /// displaying an awkward blank.
  final String ownerName;
  final CalendarKind calendar;
  final Language language;
  final String currency;

  /// Optional. Zero means "no budget set", which the dashboard treats as "don't show a target"
  /// rather than "your target is nothing".
  final int monthlyBudgetMinor;

  /// The colour palette. Purely cosmetic, so it lives with the other personal preferences.
  final AppTheme theme;

  /// Light, dark, or follow the device. Independent of [theme]: any palette works in either mode.
  final AppThemeMode themeMode;

  bool get hasBudget => monthlyBudgetMinor > 0;

  Money get monthlyBudget => Money(monthlyBudgetMinor, currency);

  bool get isAmharic => language.isAmharic;

  AppSettings copyWith({
    String? ownerName,
    CalendarKind? calendar,
    Language? language,
    String? currency,
    int? monthlyBudgetMinor,
    AppTheme? theme,
    AppThemeMode? themeMode,
  }) {
    return AppSettings(
      ownerName: ownerName ?? this.ownerName,
      calendar: calendar ?? this.calendar,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      monthlyBudgetMinor: monthlyBudgetMinor ?? this.monthlyBudgetMinor,
      theme: theme ?? this.theme,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  /// Pick the Amharic or English string according to the chosen language.
  String say(String amharic, String english) => isAmharic ? amharic : english;
}

/// Where settings are read from and written to. An interface so tests need no plugins.
abstract class SettingsStore {
  AppSettings load();

  Future<void> save(AppSettings settings);
}

/// The default: nothing persisted. Tests use it as-is; `main()` overrides it.
class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore([this._settings = const AppSettings()]);

  AppSettings _settings;

  @override
  AppSettings load() => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;
}

final settingsStoreProvider = Provider<SettingsStore>((ref) => InMemorySettingsStore());

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsStoreProvider).load();

  void _update(AppSettings next) {
    state = next;
    // Fire and forget: a failed write must not block the UI, and the value is already applied.
    ref.read(settingsStoreProvider).save(next);
  }

  void setOwnerName(String name) => _update(state.copyWith(ownerName: name.trim()));

  void setCalendar(CalendarKind calendar) => _update(state.copyWith(calendar: calendar));

  void setLanguage(Language language) => _update(state.copyWith(language: language));

  void setCurrency(String currency) =>
      _update(state.copyWith(currency: currency.toUpperCase()));

  void setMonthlyBudgetMinor(int minorUnits) =>
      _update(state.copyWith(monthlyBudgetMinor: minorUnits < 0 ? 0 : minorUnits));

  void clearBudget() => _update(state.copyWith(monthlyBudgetMinor: 0));

  void setTheme(AppTheme theme) => _update(state.copyWith(theme: theme));

  void setThemeMode(AppThemeMode mode) => _update(state.copyWith(themeMode: mode));
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Convenience views, so widgets that only care about one thing do not rebuild on every change.
final calendarProvider = Provider<CalendarKind>((ref) => ref.watch(settingsProvider).calendar);
final languageProvider = Provider<Language>((ref) => ref.watch(settingsProvider).language);
final appThemeProvider = Provider<AppTheme>((ref) => ref.watch(settingsProvider).theme);
final themeModeProvider = Provider<AppThemeMode>((ref) => ref.watch(settingsProvider).themeMode);

/// Today, as a plain date. The single source of "now": nothing else may call `DateTime.now()`,
/// so a test can pin the date and every derived value follows.
final todayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day);
});

/// The month being viewed. Starts at the month containing [todayProvider] — not `DateTime.now()` —
/// so the navigator can never disagree with the "today" card about which month it is.
final selectedPeriodProvider = StateProvider<Period>(
  (ref) => Period.fromDate(ref.watch(todayProvider), ref.watch(calendarProvider)),
);
