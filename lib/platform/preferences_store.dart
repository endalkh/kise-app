/// The real settings store, backed by SharedPreferences.
///
/// Loaded once at startup so the rest of the app can read settings synchronously — a dashboard that
/// flickers from Gregorian to Ethiopian on launch would be worse than a few milliseconds of splash.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../shared_kernel/money.dart';
import '../shared_kernel/period.dart';
import 'settings.dart';
import 'theme.dart';

class PreferencesSettingsStore implements SettingsStore {
  PreferencesSettingsStore(this._preferences);

  static const _ownerName = 'owner_name';
  static const _calendar = 'calendar';
  static const _language = 'language';
  static const _currency = 'currency';
  static const _budget = 'monthly_budget_minor';
  static const _theme = 'theme';
  static const _themeMode = 'theme_mode';

  final SharedPreferences _preferences;

  static Future<PreferencesSettingsStore> open() async =>
      PreferencesSettingsStore(await SharedPreferences.getInstance());

  @override
  AppSettings load() {
    return AppSettings(
      ownerName: _preferences.getString(_ownerName) ?? '',
      calendar: _parseCalendar(_preferences.getString(_calendar)),
      language: _parseLanguage(_preferences.getString(_language)),
      currency: _preferences.getString(_currency) ?? defaultCurrency,
      monthlyBudgetMinor: _preferences.getInt(_budget) ?? 0,
      theme: AppTheme.parse(_preferences.getString(_theme)),
      themeMode: AppThemeMode.parse(_preferences.getString(_themeMode)),
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _preferences.setString(_ownerName, settings.ownerName);
    await _preferences.setString(_calendar, settings.calendar.wire);
    await _preferences.setString(_language, settings.language.wire);
    await _preferences.setString(_currency, settings.currency);
    await _preferences.setInt(_budget, settings.monthlyBudgetMinor);
    await _preferences.setString(_theme, settings.theme.wire);
    await _preferences.setString(_themeMode, settings.themeMode.wire);
  }

  // A stored value that no longer parses falls back to the default rather than crashing the app.
  static CalendarKind _parseCalendar(String? value) {
    if (value == null) return CalendarKind.ethiopian;
    try {
      return CalendarKind.parse(value);
    } on ArgumentError {
      return CalendarKind.ethiopian;
    }
  }

  static Language _parseLanguage(String? value) {
    if (value == null) return Language.amharic;
    try {
      return Language.parse(value);
    } on ArgumentError {
      return Language.amharic;
    }
  }
}
