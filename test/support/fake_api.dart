/// Test doubles for the API layer, so widget tests never touch the network.
///
/// Widget tests that pump the app (or the expenses screen) pull in providers that would otherwise
/// build a real Dio client and fire HTTP requests — leaving pending timers and failing the test.
/// These fakes return canned data synchronously, and [fakeApiOverrides] wires them into a
/// ProviderScope. A test that wants specific data passes its own instances.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kise/platform/api/api.dart';
import 'package:kise/platform/session/session_controller.dart';

class FakeExpensesApi implements ExpensesApi {
  FakeExpensesApi({ExpensePageDto? page, this.onRecord}) : _page = page ?? emptyPage();

  ExpensePageDto _page;
  final Future<ExpenseDto> Function(Map<String, Object?> body)? onRecord;

  /// The last record() call's arguments, for assertions.
  Map<String, Object?>? lastRecord;

  static ExpensePageDto emptyPage() => ExpensePageDto.fromJson({
        'items': <Object?>[],
        'total': 0,
        'limit': 50,
        'offset': 0,
        'total_amount': {'amount_minor': 0, 'currency': 'ETB'},
      });

  void setPage(ExpensePageDto page) => _page = page;

  @override
  Future<ExpensePageDto> list({
    int? periodYear,
    int? periodMonth,
    String periodCalendar = 'ethiopian',
    String? since,
    String? until,
    String dateCalendar = 'gregorian',
    List<String> categoryIds = const [],
    int limit = 50,
    int offset = 0,
  }) async =>
      _page;

  @override
  Future<ExpenseDto> record({
    required String categoryId,
    required int amountMinor,
    required String date,
    String dateCalendar = 'gregorian',
    String? note,
    String? paymentMethod,
    String? itemId,
    String? itemName,
    String? itemNameAm,
    String? quantity,
    String? unitId,
  }) async {
    lastRecord = {
      'category_id': categoryId,
      'amount_minor': amountMinor,
      'date': date,
      'note': note,
      'payment_method': paymentMethod,
      'item_name': itemName,
      'quantity': quantity,
      'unit_id': unitId,
    };
    if (onRecord != null) return onRecord!(lastRecord!);
    return _expense(categoryId: categoryId, amountMinor: amountMinor, date: date);
  }

  @override
  Future<ExpenseDto> get(String id) async => throw UnimplementedError();

  @override
  Future<ExpenseDto> update(
    String id, {
    String? categoryId,
    int? amountMinor,
    String? date,
    String dateCalendar = 'gregorian',
    String? note,
    String? paymentMethod,
    String? itemId,
    String? itemName,
    String? itemNameAm,
    String? quantity,
    String? unitId,
    bool clearItem = false,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) async {}
}

class FakeCategoriesApi implements CategoriesApi {
  FakeCategoriesApi([this._items = const []]);
  final List<CategoryDto> _items;

  @override
  Future<List<CategoryDto>> list({bool includeArchived = false}) async => _items;

  @override
  Future<CategoryDto> create({
    required String name,
    String? nameAm,
    String? color,
    String? icon,
  }) async =>
      throw UnimplementedError();

  @override
  Future<CategoryDto> update(String id,
          {String? name, String? nameAm, String? color, String? icon}) async =>
      throw UnimplementedError();

  @override
  Future<CategoryDto?> remove(String id) async => null;
}

class FakeUnitsApi implements UnitsApi {
  FakeUnitsApi([this._items = const []]);
  final List<UnitDto> _items;

  @override
  Future<List<UnitDto>> list() async => _items;

  @override
  Future<UnitDto> create({required String code, required String name, String? nameAm}) async =>
      throw UnimplementedError();
}

class FakeItemsApi implements ItemsApi {
  FakeItemsApi([this._items = const []]);
  final List<ItemDto> _items;

  @override
  Future<List<ItemDto>> list({bool includeArchived = false}) async => _items;

  @override
  Future<ItemDto> create({required String name, String? nameAm, String? defaultUnitId}) async =>
      throw UnimplementedError();

  @override
  Future<ItemDto> get(String id) async => throw UnimplementedError();

  @override
  Future<ItemDto?> remove(String id) async => null;
}

CategoryDto category(String id, String name, {String? nameAm}) => CategoryDto.fromJson({
      'id': id,
      'name': name,
      'name_am': nameAm,
      'color': '#607D8B',
      'icon': null,
      'is_archived': false,
      'is_default': false,
    });

UnitDto unit(String id, String code, String name, {String? nameAm}) => UnitDto.fromJson({
      'id': id,
      'code': code,
      'name': name,
      'name_am': nameAm,
      'is_system': true,
    });

ExpenseDto _expense({
  required String categoryId,
  required int amountMinor,
  required String date,
  String? categoryName,
}) =>
    ExpenseDto.fromJson({
      'id': 'exp-${DateTime.now().microsecondsSinceEpoch}',
      'category_id': categoryId,
      'amount': {'amount_minor': amountMinor, 'currency': 'ETB'},
      'spent_on': {
        'gregorian': date,
        'ethiopian': '2018-12-29',
        'ethiopian_month_name_am': 'ነሐሴ',
        'ethiopian_month_name_en': 'Nehase',
        'entered_in': 'gregorian',
      },
      'note': null,
      'payment_method': 'cash',
      'category_name': categoryName,
      'category_name_am': null,
      'item': null,
    });

ExpenseDto expenseRow({
  required String id,
  required int amountMinor,
  String? categoryName,
  Map<String, Object?>? item,
}) =>
    ExpenseDto.fromJson({
      'id': id,
      'category_id': 'cat-1',
      'amount': {'amount_minor': amountMinor, 'currency': 'ETB'},
      'spent_on': {
        'gregorian': '2026-09-04',
        'ethiopian': '2018-12-29',
        'ethiopian_month_name_am': 'ነሐሴ',
        'ethiopian_month_name_en': 'Nehase',
        'entered_in': 'gregorian',
      },
      'note': null,
      'payment_method': 'cash',
      'category_name': categoryName,
      'category_name_am': null,
      'item': item,
    });

ExpensePageDto pageOf(List<ExpenseDto> items, {int? totalAmountMinor}) => ExpensePageDto.fromJson({
      'items': items.map((e) => {
            'id': e.id,
            'category_id': e.categoryId,
            'amount': {'amount_minor': e.amount.minorUnits, 'currency': e.amount.currency},
            'spent_on': e.spentOn.raw,
            'note': e.note,
            'payment_method': e.paymentMethod,
            'category_name': e.categoryName,
            'category_name_am': e.categoryNameAm,
            'item': e.item == null
                ? null
                : {
                    'item_id': e.item!.itemId,
                    'item_name': e.item!.itemName,
                    'item_name_am': e.item!.itemNameAm,
                    'quantity': e.item!.quantity,
                    'quantity_milli': e.item!.quantityMilli,
                    'unit_id': e.item!.unitId,
                    'unit_code': e.item!.unitCode,
                    'unit_name': e.item!.unitName,
                    'unit_name_am': e.item!.unitNameAm,
                  },
          }).toList(),
      'total': items.length,
      'limit': 50,
      'offset': 0,
      'total_amount': {
        'amount_minor': totalAmountMinor ??
            items.fold<int>(0, (sum, e) => sum + e.amount.minorUnits),
        'currency': 'ETB',
      },
    });

/// Provider overrides that replace the network-backed data sources with fakes, and force the
/// session to signed-in so gated screens render.
List<Override> fakeApiOverrides({
  FakeExpensesApi? expenses,
  FakeCategoriesApi? categories,
  FakeUnitsApi? units,
  FakeItemsApi? items,
}) =>
    [
      expensesApiProvider.overrideWithValue(expenses ?? FakeExpensesApi()),
      categoriesApiProvider.overrideWithValue(categories ?? FakeCategoriesApi()),
      unitsApiProvider.overrideWithValue(units ?? FakeUnitsApi()),
      itemsApiProvider.overrideWithValue(items ?? FakeItemsApi()),
      sessionProvider.overrideWith(_SignedInSession.new),
    ];

/// A session that is already signed in, so the gate lets the app through in tests.
class _SignedInSession extends SessionController {
  @override
  Future<SessionState> build() async => SignedIn(ProfileDto.fromJson({
        'id': 'owner-1',
        'email': 'test@example.com',
        'display_name': 'Test',
        'calendar': 'ethiopian',
        'language': 'am',
        'currency': 'ETB',
        'registered_at': '2026-09-01T00:00:00+00:00',
      }));
}
