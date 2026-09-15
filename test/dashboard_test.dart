/// Widget tests for the dashboard and settings.
///
/// These are the honest proof that the app runs: a real widget tree is built, pumped and interacted
/// with, without needing a simulator. `todayProvider` is pinned so assertions are about a fixed day
/// rather than whenever the suite happens to execute.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kise/app_shell.dart';
import 'package:kise/main.dart';
import 'package:kise/platform/settings.dart';
import 'package:kise/platform/theme.dart';
import 'package:kise/shared_kernel/period.dart';

import 'support/fake_api.dart';

/// 4 September 2026 is ነሐሴ 29, 2018 — one of the backend's anchor dates.
final _fixedToday = DateTime.utc(2026, 9, 4);

Widget _app({
  DateTime? today,
  AppSettings settings = const AppSettings(),
}) {
  return ProviderScope(
    overrides: [
      todayProvider.overrideWithValue(today ?? _fixedToday),
      settingsStoreProvider.overrideWithValue(InMemorySettingsStore(settings)),
      // The expenses tab is built eagerly inside the IndexedStack; fake the API so it does not
      // fire real network requests and leave pending timers.
      ...fakeApiOverrides(),
    ],
    child: MaterialApp(theme: buildTheme(), home: const AppShell()),
  );
}

String _textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('settings-tab')));
  await tester.pumpAndSettle();
}

void main() {
  // A tall surface so that lazily-built scroll children — the budget bar low in the spend card, the
  // budget field at the bottom of Settings — are actually laid out. Without it the finders miss
  // widgets that a real phone would simply scroll to.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 2600);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('dashboard', () {
    testWidgets('opens on the Ethiopian calendar in Amharic', (tester) async {
      await tester.pumpWidget(_app());

      expect(find.text('ኪሴ'), findsOneWidget);
      expect(_textOf(tester, 'today-primary'), 'ነሐሴ 29, 2018');
      expect(_textOf(tester, 'today-secondary'), contains('September 4, 2026'));
      expect(_textOf(tester, 'greeting'), 'እንደምን አሉ!'); // no name set yet
    });

    testWidgets('greets the owner by name once it is set', (tester) async {
      await tester.pumpWidget(_app(settings: const AppSettings(ownerName: 'ሰላም')));
      expect(_textOf(tester, 'greeting'), 'እንደምን አሉ, ሰላም!');
    });

    testWidgets('the headline date follows the chosen calendar', (tester) async {
      // In Ethiopian mode the big date is Ethiopian and the Gregorian one sits underneath.
      await tester.pumpWidget(_app());
      expect(_textOf(tester, 'today-primary'), 'ነሐሴ 29, 2018');
      expect(_textOf(tester, 'today-secondary'), startsWith('September 4, 2026'));
    });

    testWidgets('in Gregorian mode the two swap, so nothing contradicts the navigator',
        (tester) async {
      await tester.pumpWidget(
        _app(settings: const AppSettings(calendar: CalendarKind.gregorian)),
      );
      expect(_textOf(tester, 'today-primary'), 'September 4, 2026');
      expect(_textOf(tester, 'today-secondary'), startsWith('ነሐሴ 29, 2018'));
      expect(_textOf(tester, 'period-label'), 'ሴፕቴምበር 2026');
    });

    testWidgets('the navigator names the same stretch in both calendars', (tester) async {
      await tester.pumpWidget(_app());

      expect(_textOf(tester, 'period-label'), 'ነሐሴ 2018');
      // ነሐሴ 2018 runs 7 August - 5 September 2026.
      expect(_textOf(tester, 'period-counterpart-label'), 'ኦገስት - ሴፕቴምበር 2026');
    });

    testWidgets('stepping forward rolls ነሐሴ into ጳጉሜን, then into መስከረም', (tester) async {
      await tester.pumpWidget(_app());

      await tester.tap(find.byTooltip('የሚቀጥለው ወር'));
      await tester.pump();
      expect(_textOf(tester, 'period-label'), 'ጳጉሜን 2018');

      await tester.tap(find.byTooltip('የሚቀጥለው ወር'));
      await tester.pump();
      expect(_textOf(tester, 'period-label'), 'መስከረም 2019');
    });

    testWidgets('the navigator always opens on the month containing today', (tester) async {
      // A date deliberately far from whenever this suite runs. Before `selectedPeriodProvider` was
      // derived from `todayProvider`, the two read the clock separately and could disagree.
      await tester.pumpWidget(_app(today: DateTime.utc(2027, 3, 10)));

      expect(_textOf(tester, 'today-primary'), 'መጋቢት 1, 2019');
      expect(_textOf(tester, 'period-label'), 'መጋቢት 2019');
    });

    testWidgets('the calendar toggle switches labels and keeps the month aligned', (tester) async {
      await tester.pumpWidget(_app());
      expect(_textOf(tester, 'period-label'), 'ነሐሴ 2018');

      await tester.tap(find.byKey(const Key('toggle-calendar')));
      await tester.pump();

      // ነሐሴ 2018 overlaps August 2026 by 25 days and September by 5, so August is the counterpart.
      expect(_textOf(tester, 'period-label'), 'ኦገስት 2026');
      expect(_textOf(tester, 'period-counterpart-label'), 'ሐምሌ - ነሐሴ 2018');
    });

    testWidgets('the language toggle switches the interface to English', (tester) async {
      await tester.pumpWidget(_app());

      await tester.tap(find.byKey(const Key('toggle-language')));
      await tester.pump();

      expect(find.text('Kise'), findsOneWidget);
      expect(_textOf(tester, 'greeting'), 'Welcome back!');
      // Month names stay Ethiopian but transliterated: the calendar did not change.
      expect(_textOf(tester, 'period-label'), 'Nehase 2018');
    });

    testWidgets('the month total is the fixed plus dynamic split', (tester) async {
      await tester.pumpWidget(_app());

      // Sample data: 8,200 committed + 1,246.xx dynamic, rendered with a thousands separator.
      final total = _textOf(tester, 'grand-total');
      expect(total, contains(','));
      expect(total, endsWith('ETB'));
    });

    testWidgets('no budget bar when no budget is set', (tester) async {
      await tester.pumpWidget(_app());
      expect(find.byKey(const Key('budget-progress')), findsNothing);
    });

    testWidgets('a budget shows a progress bar with the target', (tester) async {
      // A separate test rather than re-pumping: a new ProviderScope over the same element tree
      // keeps the notifier's existing state, so the override would be ignored.
      await tester.pumpWidget(
        _app(settings: const AppSettings(monthlyBudgetMinor: 1500000)), // 15,000 ETB
      );
      expect(find.byKey(const Key('budget-progress')), findsOneWidget);
      expect(_textOf(tester, 'budget-progress'), contains('15,000 ETB'));
    });

    testWidgets('the currency setting is used throughout', (tester) async {
      await tester.pumpWidget(_app(settings: const AppSettings(currency: 'USD')));
      expect(_textOf(tester, 'grand-total'), endsWith('USD'));
    });
  });

  group('settings', () {
    testWidgets('reachable from the bottom navigation', (tester) async {
      await tester.pumpWidget(_app());
      await _openSettings(tester);

      expect(find.text('ማስተካከያ'), findsWidgets);
      expect(find.byKey(const Key('owner-name-field')), findsOneWidget);
      expect(find.byKey(const Key('calendar-selector')), findsOneWidget);
      expect(find.byKey(const Key('language-selector')), findsOneWidget);
      expect(find.byKey(const Key('currency-selector')), findsOneWidget);
      expect(find.byKey(const Key('budget-field')), findsOneWidget);
    });

    testWidgets('typing a name updates the dashboard greeting', (tester) async {
      await tester.pumpWidget(_app());
      await _openSettings(tester);

      await tester.enterText(find.byKey(const Key('owner-name-field')), '  Abebe  ');
      await tester.pumpAndSettle();

      // Back to the dashboard: the greeting picked it up, trimmed.
      await tester.tap(find.byIcon(Icons.dashboard_outlined));
      await tester.pumpAndSettle();
      expect(_textOf(tester, 'greeting'), 'እንደምን አሉ, Abebe!');
    });

    testWidgets('the preview shows what the calendar choice will look like', (tester) async {
      await tester.pumpWidget(_app());
      await _openSettings(tester);

      expect(_textOf(tester, 'settings-preview-date'), 'ነሐሴ 29, 2018');
      expect(_textOf(tester, 'settings-preview-period'), contains('ነሐሴ 2018'));
    });

    testWidgets('switching the calendar from settings changes the dashboard', (tester) async {
      await tester.pumpWidget(_app());
      await _openSettings(tester);

      await tester.tap(find.text('ግሪጎሪያን'));
      await tester.pumpAndSettle();
      expect(_textOf(tester, 'settings-preview-date'), 'September 4, 2026');

      await tester.tap(find.byIcon(Icons.dashboard_outlined));
      await tester.pumpAndSettle();
      expect(_textOf(tester, 'period-label'), 'ኦገስት 2026');
    });

    testWidgets('switching the language relabels the navigation itself', (tester) async {
      await tester.pumpWidget(_app());
      await _openSettings(tester);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Fixed'), findsOneWidget);
    });

    testWidgets('setting a budget makes the dashboard bar appear', (tester) async {
      await tester.pumpWidget(_app());
      await _openSettings(tester);

      await tester.enterText(find.byKey(const Key('budget-field')), '12000');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.dashboard_outlined));
      await tester.pumpAndSettle();
      expect(_textOf(tester, 'budget-progress'), contains('12,000 ETB'));
    });

    testWidgets('clearing the budget field removes it again', (tester) async {
      await tester.pumpWidget(_app(settings: const AppSettings(monthlyBudgetMinor: 1200000)));
      await _openSettings(tester);

      await tester.enterText(find.byKey(const Key('budget-field')), '');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.dashboard_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('budget-progress')), findsNothing);
    });

    testWidgets('settings survive being written to the store', (tester) async {
      final store = InMemorySettingsStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayProvider.overrideWithValue(_fixedToday),
            settingsStoreProvider.overrideWithValue(store),
            ...fakeApiOverrides(),
          ],
          child: MaterialApp(theme: buildTheme(), home: const AppShell()),
        ),
      );
      await _openSettings(tester);
      await tester.enterText(find.byKey(const Key('owner-name-field')), 'Selam');
      await tester.pumpAndSettle();

      // The store, not just the in-memory state, has the new value — so a restart keeps it.
      expect(store.load().ownerName, 'Selam');
    });
  });

  group('other tabs', () {
    testWidgets('expenses and fixed expenses say what is coming', (tester) async {
      await tester.pumpWidget(_app());

      await tester.tap(find.byIcon(Icons.receipt_long_outlined));
      await tester.pumpAndSettle();
      expect(find.textContaining('ወጪዎች'), findsWidgets);

      await tester.tap(find.byIcon(Icons.event_repeat_outlined));
      await tester.pumpAndSettle();
      expect(find.textContaining('ቤት ኪራይ'), findsOneWidget);
    });
  });

  group('appearance', () {
    testWidgets('choosing a palette in Settings is saved', (tester) async {
      final store = InMemorySettingsStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayProvider.overrideWithValue(_fixedToday),
            settingsStoreProvider.overrideWithValue(store),
            ...fakeApiOverrides(),
          ],
          child: MaterialApp(theme: buildTheme(), home: const AppShell()),
        ),
      );
      await _openSettings(tester);

      await tester.tap(find.byKey(const Key('theme-option-sunset')));
      await tester.pumpAndSettle();

      expect(store.load().theme, AppTheme.sunset);
    });

    testWidgets('the app is built in the saved palette', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayProvider.overrideWithValue(_fixedToday),
            settingsStoreProvider.overrideWithValue(
              InMemorySettingsStore(const AppSettings(theme: AppTheme.wine)),
            ),
            ...fakeApiOverrides(),
          ],
          child: const KiseApp(),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AppShell));
      expect(
        Theme.of(context).colorScheme.primary,
        buildTheme(theme: AppTheme.wine).colorScheme.primary,
      );
    });

    test('every palette builds and looks different from the default', () {
      final defaultPrimary = buildTheme().colorScheme.primary;
      for (final option in AppTheme.values.where((t) => t != AppTheme.forest)) {
        for (final brightness in Brightness.values) {
          final theme = buildTheme(theme: option, brightness: brightness);
          expect(theme.extension<KiseColors>(), isNotNull);
          if (brightness == Brightness.light) {
            expect(theme.colorScheme.primary, isNot(defaultPrimary), reason: option.wire);
          }
        }
      }
    });

    test('an unknown stored palette falls back to the default', () {
      expect(AppTheme.parse('neon'), AppTheme.forest);
      expect(AppTheme.parse(null), AppTheme.forest);
      expect(AppTheme.parse('Wine'), AppTheme.wine);
    });

    test('an unknown stored theme mode falls back to system', () {
      expect(AppThemeMode.parse('night'), AppThemeMode.system);
      expect(AppThemeMode.parse(null), AppThemeMode.system);
      expect(AppThemeMode.parse('Dark'), AppThemeMode.dark);
      expect(AppThemeMode.parse('light'), AppThemeMode.light);
    });

    testWidgets('choosing dark mode in Settings is saved', (tester) async {
      final store = InMemorySettingsStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayProvider.overrideWithValue(_fixedToday),
            settingsStoreProvider.overrideWithValue(store),
            ...fakeApiOverrides(),
          ],
          child: MaterialApp(theme: buildTheme(), home: const AppShell()),
        ),
      );
      await _openSettings(tester);

      // Pick Dark in the appearance mode selector.
      await tester.ensureVisible(find.byKey(const Key('theme-mode-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ጨለማ'));
      await tester.pumpAndSettle();

      expect(store.load().themeMode, AppThemeMode.dark);
    });

    testWidgets('the app renders dark when dark mode is saved', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayProvider.overrideWithValue(_fixedToday),
            settingsStoreProvider.overrideWithValue(
              InMemorySettingsStore(const AppSettings(themeMode: AppThemeMode.dark)),
            ),
            ...fakeApiOverrides(),
          ],
          child: const KiseApp(),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AppShell));
      expect(Theme.of(context).brightness, Brightness.dark);
    });
  });

  group('period arithmetic used by the UI', () {
    test('an Ethiopian period maps to the Gregorian month it shares most days with', () {
      final hamle = Period(CalendarKind.ethiopian, 2018, 11);
      expect(hamle.asCalendar(CalendarKind.gregorian),
          Period(CalendarKind.gregorian, 2026, 7));
      expect(hamle.overlapDays(Period(CalendarKind.gregorian, 2026, 7)), 24);
    });
  });
}
