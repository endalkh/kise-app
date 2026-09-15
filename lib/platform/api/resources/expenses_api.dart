/// Expenses data source: list (by period or date range, in either calendar), record, get, update,
/// delete.
///
/// Two wire conventions from the backend are honoured here:
///
/// * **Money** comes back as `{amount_minor, currency}` and is decoded with the shared kernel's
///   [Money.fromJson], the same value object the rest of the app uses — no parallel money type.
/// * **Dates** come back in both calendars at once ([SpendDateDto]); they go up as a
///   `{calendar, value}` pair, so the app sends the calendar the user typed in and the server keeps
///   Gregorian canonical.
library;

import '../../../shared_kernel/money.dart';
import '../api_client.dart';

/// A date as the API returns it: Gregorian canonical, with the Ethiopian rendering alongside.
class SpendDateDto {
  const SpendDateDto({
    required this.gregorian,
    required this.ethiopian,
    required this.ethiopianMonthNameAm,
    required this.ethiopianMonthNameEn,
    required this.enteredIn,
    this.raw = const {},
  });

  final String gregorian;
  final String ethiopian;
  final String ethiopianMonthNameAm;
  final String ethiopianMonthNameEn;
  final String enteredIn;

  /// The full describe() payload, kept so nothing is lost if a screen wants another field.
  final Map<String, Object?> raw;

  factory SpendDateDto.fromJson(Map<String, Object?> json) => SpendDateDto(
        gregorian: json['gregorian'] as String,
        ethiopian: json['ethiopian'] as String,
        ethiopianMonthNameAm: json['ethiopian_month_name_am'] as String,
        ethiopianMonthNameEn: json['ethiopian_month_name_en'] as String,
        enteredIn: json['entered_in'] as String,
        raw: json,
      );
}

/// The optional item line on an expense: what was bought, how much, in what unit.
class ItemLineDto {
  const ItemLineDto({
    required this.itemId,
    required this.itemName,
    required this.itemNameAm,
    required this.quantity,
    required this.quantityMilli,
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.unitNameAm,
  });

  final String itemId;
  final String? itemName;
  final String? itemNameAm;

  /// Tidy decimal string, e.g. "1.5".
  final String quantity;

  /// Integer thousandths, e.g. 1500 — for exact arithmetic.
  final int quantityMilli;
  final String unitId;
  final String? unitCode;
  final String? unitName;
  final String? unitNameAm;

  factory ItemLineDto.fromJson(Map<String, Object?> json) => ItemLineDto(
        itemId: json['item_id'] as String,
        itemName: json['item_name'] as String?,
        itemNameAm: json['item_name_am'] as String?,
        quantity: json['quantity'] as String,
        quantityMilli: (json['quantity_milli'] as num).toInt(),
        unitId: json['unit_id'] as String,
        unitCode: json['unit_code'] as String?,
        unitName: json['unit_name'] as String?,
        unitNameAm: json['unit_name_am'] as String?,
      );
}

class ExpenseDto {
  const ExpenseDto({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.spentOn,
    required this.note,
    required this.paymentMethod,
    required this.categoryName,
    required this.categoryNameAm,
    required this.item,
  });

  final String id;
  final String categoryId;
  final Money amount;
  final SpendDateDto spentOn;
  final String? note;
  final String paymentMethod;
  final String? categoryName;
  final String? categoryNameAm;

  /// The item line, or null for a plain amount-only expense.
  final ItemLineDto? item;

  factory ExpenseDto.fromJson(Map<String, Object?> json) {
    final rawItem = json['item'];
    return ExpenseDto(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      amount: Money.fromJson((json['amount'] as Map).cast<String, Object?>()),
      spentOn: SpendDateDto.fromJson((json['spent_on'] as Map).cast<String, Object?>()),
      note: json['note'] as String?,
      paymentMethod: json['payment_method'] as String,
      categoryName: json['category_name'] as String?,
      categoryNameAm: json['category_name_am'] as String?,
      item: rawItem is Map ? ItemLineDto.fromJson(rawItem.cast<String, Object?>()) : null,
    );
  }
}

class ExpensePageDto {
  const ExpensePageDto({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.totalAmount,
  });

  final List<ExpenseDto> items;
  final int total;
  final int limit;
  final int offset;
  final Money totalAmount;

  factory ExpensePageDto.fromJson(Map<String, Object?> json) => ExpensePageDto(
        items: (json['items'] as List)
            .map((item) => ExpenseDto.fromJson((item as Map).cast<String, Object?>()))
            .toList(),
        total: (json['total'] as num).toInt(),
        limit: (json['limit'] as num).toInt(),
        offset: (json['offset'] as num).toInt(),
        totalAmount: Money.fromJson((json['total_amount'] as Map).cast<String, Object?>()),
      );
}

class ExpensesApi {
  ExpensesApi(this._client);

  final ApiClient _client;

  /// List by an explicit Period (year/month/calendar), or a since/until range, or neither.
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
  }) async {
    final data = await _client.get('/api/expenses', query: {
      'period_year': periodYear,
      'period_month': periodMonth,
      'period_calendar': periodCalendar,
      'since': since,
      'until': until,
      'date_calendar': dateCalendar,
      if (categoryIds.isNotEmpty) 'category_id': categoryIds,
      'limit': limit,
      'offset': offset,
    });
    return ExpensePageDto.fromJson((data as Map).cast<String, Object?>());
  }

  Future<ExpenseDto> record({
    required String categoryId,
    required int amountMinor,
    required String date,
    String dateCalendar = 'gregorian',
    String? note,
    String? paymentMethod,
    // Optional item line: pick an existing item (itemId) or create one by name (itemName).
    String? itemId,
    String? itemName,
    String? itemNameAm,
    String? quantity,
    String? unitId,
  }) async {
    final item = _itemBody(
      itemId: itemId,
      itemName: itemName,
      itemNameAm: itemNameAm,
      quantity: quantity,
      unitId: unitId,
    );
    final data = await _client.post('/api/expenses', body: {
      'category_id': categoryId,
      'amount_minor': amountMinor,
      'spent_on': {'calendar': dateCalendar, 'value': date},
      if (note != null) 'note': note,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (item != null) 'item': item,
    });
    return ExpenseDto.fromJson((data as Map).cast<String, Object?>());
  }

  /// Build the `item` body block, or null when no item line was provided.
  Map<String, Object?>? _itemBody({
    String? itemId,
    String? itemName,
    String? itemNameAm,
    String? quantity,
    String? unitId,
  }) {
    final present = itemId != null || itemName != null || quantity != null || unitId != null;
    if (!present) return null;
    return {
      if (itemId != null) 'item_id': itemId,
      if (itemName != null) 'item_name': itemName,
      if (itemNameAm != null) 'item_name_am': itemNameAm,
      if (quantity != null) 'quantity': quantity,
      if (unitId != null) 'unit_id': unitId,
    };
  }

  Future<ExpenseDto> get(String id) async {
    final data = await _client.get('/api/expenses/$id');
    return ExpenseDto.fromJson((data as Map).cast<String, Object?>());
  }

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
  }) async {
    final item = _itemBody(
      itemId: itemId,
      itemName: itemName,
      itemNameAm: itemNameAm,
      quantity: quantity,
      unitId: unitId,
    );
    final data = await _client.patch('/api/expenses/$id', body: {
      if (categoryId != null) 'category_id': categoryId,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (date != null) 'spent_on': {'calendar': dateCalendar, 'value': date},
      if (note != null) 'note': note,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (item != null) 'item': item,
      if (clearItem) 'clear_item': true,
    });
    return ExpenseDto.fromJson((data as Map).cast<String, Object?>());
  }

  Future<void> delete(String id) => _client.delete('/api/expenses/$id');
}
