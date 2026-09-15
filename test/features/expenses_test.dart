/// Widget tests for registering and listing expenses.
///
/// They pump the real screens with the API faked, so no network is touched, and drive them the way
/// a person would: the list renders the month's expenses (and the item line), and the form validates
/// its inputs and sends the right payload to `record` — including the optional item line when the
/// "track an item" switch is on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kise/features/expenses/presentation/expense_form_sheet.dart';
import 'package:kise/features/expenses/presentation/expenses_screen.dart';
import 'package:kise/platform/settings.dart';
import 'package:kise/platform/theme.dart';
import 'package:kise/shared_kernel/period.dart';

import '../support/fake_api.dart';

Widget _host({
  required Widget child,
  required List<Override> overrides,
  AppSettings settings = const AppSettings(language: Language.english),
}) {
  return ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(InMemorySettingsStore(settings)),
      ...overrides,
    ],
    // Wrap in a Scaffold so form widgets (normally inside a bottom sheet) have a Material ancestor.
    child: MaterialApp(theme: buildTheme(), home: Scaffold(body: child)),
  );
}

void main() {
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

  group('expenses list', () {
    testWidgets('shows the month total and each expense', (tester) async {
      final expenses = FakeExpensesApi(
        page: pageOf([
          expenseRow(id: 'e1', amountMinor: 12500, categoryName: 'Taxi'),
          expenseRow(
            id: 'e2',
            amountMinor: 48000,
            categoryName: 'Groceries',
            item: {
              'item_id': 'i1',
              'item_name': 'Sugar',
              'item_name_am': null,
              'quantity': '12',
              'quantity_milli': 12000,
              'unit_id': 'u1',
              'unit_code': 'kg',
              'unit_name': 'Kilogram',
              'unit_name_am': null,
            },
          ),
        ]),
      );

      await tester.pumpWidget(_host(
        child: const ExpensesScreen(),
        overrides: fakeApiOverrides(expenses: expenses),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expenses-list')), findsOneWidget);
      expect(find.text('Taxi'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('2 expenses'), findsOneWidget);
      // The item line renders "12 kg · Sugar".
      expect(find.textContaining('12 kg'), findsOneWidget);
      expect(find.textContaining('Sugar'), findsOneWidget);
    });

    testWidgets('shows an empty state when there are no expenses', (tester) async {
      await tester.pumpWidget(_host(
        child: const ExpensesScreen(),
        overrides: fakeApiOverrides(),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expenses-empty')), findsOneWidget);
      expect(find.byKey(const Key('expenses-list')), findsNothing);
    });
  });

  group('expense form', () {
    testWidgets('validation blocks submit until amount and category are given', (tester) async {
      final expenses = FakeExpensesApi();
      await tester.pumpWidget(_host(
        child: const ExpenseFormSheet(),
        overrides: fakeApiOverrides(
          expenses: expenses,
          categories: FakeCategoriesApi([category('c1', 'Taxi')]),
        ),
      ));
      await tester.pumpAndSettle();

      // Submit with nothing filled in — nothing is recorded.
      await tester.tap(find.byKey(const Key('expense-submit')));
      await tester.pumpAndSettle();
      expect(expenses.lastRecord, isNull);
      expect(find.text('Enter a valid amount'), findsOneWidget);
    });

    testWidgets('records a plain expense with amount and category', (tester) async {
      final expenses = FakeExpensesApi();
      await tester.pumpWidget(_host(
        child: const ExpenseFormSheet(),
        overrides: fakeApiOverrides(
          expenses: expenses,
          categories: FakeCategoriesApi([category('c1', 'Taxi')]),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('expense-amount')), '125');
      await tester.tap(find.byKey(const Key('expense-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Taxi').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('expense-submit')));
      await tester.pumpAndSettle();

      expect(expenses.lastRecord, isNotNull);
      expect(expenses.lastRecord!['category_id'], 'c1');
      // 125 birr -> 12500 santim.
      expect(expenses.lastRecord!['amount_minor'], 12500);
      expect(expenses.lastRecord!['item_name'], isNull);
    });

    testWidgets('records an item line when tracking is switched on', (tester) async {
      final expenses = FakeExpensesApi();
      await tester.pumpWidget(_host(
        child: const ExpenseFormSheet(),
        overrides: fakeApiOverrides(
          expenses: expenses,
          categories: FakeCategoriesApi([category('c1', 'Groceries')]),
          units: FakeUnitsApi([unit('u1', 'kg', 'Kilogram')]),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('expense-amount')), '480');
      await tester.tap(find.byKey(const Key('expense-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Groceries').last);
      await tester.pumpAndSettle();

      // Turn on item tracking, fill item + quantity + unit.
      await tester.tap(find.byKey(const Key('expense-track-item')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('expense-item-name')), 'Sugar');
      await tester.enterText(find.byKey(const Key('expense-quantity')), '12');
      await tester.tap(find.byKey(const Key('expense-unit')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('kg').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('expense-submit')));
      await tester.pumpAndSettle();

      expect(expenses.lastRecord, isNotNull);
      expect(expenses.lastRecord!['amount_minor'], 48000);
      expect(expenses.lastRecord!['item_name'], 'Sugar');
      expect(expenses.lastRecord!['quantity'], '12');
      expect(expenses.lastRecord!['unit_id'], 'u1');
    });
  });
}
