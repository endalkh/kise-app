/// Reports data source: the month-end item-usage report.
///
/// [ItemUsageReportsApi.forPeriod] returns, for a month, how much of each item was bought in each
/// unit — the "12 kg of sugar" view — with the money spent. Each line carries the quantity both as
/// a tidy string ([ItemUsageLineDto.totalQuantity]) and as integer thousandths
/// ([ItemUsageLineDto.totalQuantityMilli]) so the chart can plot an exact number, and the money as
/// the shared [Money] value object.
library;

import '../../../shared_kernel/money.dart';
import '../api_client.dart';

class ItemUsageLineDto {
  const ItemUsageLineDto({
    required this.itemId,
    required this.itemName,
    required this.itemNameAm,
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.unitNameAm,
    required this.totalQuantity,
    required this.totalQuantityMilli,
    required this.totalAmount,
    required this.entryCount,
  });

  final String itemId;
  final String itemName;
  final String? itemNameAm;
  final String unitId;
  final String unitCode;
  final String unitName;
  final String? unitNameAm;

  /// Tidy decimal string, e.g. "15".
  final String totalQuantity;

  /// Integer thousandths, e.g. 15000 — for exact chart values.
  final int totalQuantityMilli;
  final Money totalAmount;
  final int entryCount;

  String itemLabel({bool amharic = false}) =>
      amharic && itemNameAm != null ? itemNameAm! : itemName;

  String unitLabel({bool amharic = false}) =>
      amharic && unitNameAm != null ? unitNameAm! : unitName;

  factory ItemUsageLineDto.fromJson(Map<String, Object?> json) => ItemUsageLineDto(
        itemId: json['item_id'] as String,
        itemName: json['item_name'] as String,
        itemNameAm: json['item_name_am'] as String?,
        unitId: json['unit_id'] as String,
        unitCode: json['unit_code'] as String,
        unitName: json['unit_name'] as String,
        unitNameAm: json['unit_name_am'] as String?,
        totalQuantity: json['total_quantity'] as String,
        totalQuantityMilli: (json['total_quantity_milli'] as num).toInt(),
        totalAmount: Money.fromJson((json['total_amount'] as Map).cast<String, Object?>()),
        entryCount: (json['entry_count'] as num).toInt(),
      );
}

class ItemUsageReportDto {
  const ItemUsageReportDto({
    required this.period,
    required this.currency,
    required this.lines,
  });

  /// The Period.labels() payload: calendar, label_am/label_en, first_day/last_day, etc.
  final Map<String, Object?> period;
  final String currency;
  final List<ItemUsageLineDto> lines;

  bool get isEmpty => lines.isEmpty;

  String periodLabel({bool amharic = false}) =>
      (period[amharic ? 'label_am' : 'label_en'] as String?) ?? '';

  factory ItemUsageReportDto.fromJson(Map<String, Object?> json) => ItemUsageReportDto(
        period: (json['period'] as Map).cast<String, Object?>(),
        currency: json['currency'] as String,
        lines: (json['lines'] as List)
            .map((line) => ItemUsageLineDto.fromJson((line as Map).cast<String, Object?>()))
            .toList(),
      );
}

class ItemUsageReportsApi {
  ItemUsageReportsApi(this._client);

  final ApiClient _client;

  Future<ItemUsageReportDto> forPeriod({
    required int year,
    required int month,
    String calendar = 'ethiopian',
  }) async {
    final data = await _client.get('/api/reports/item-usage', query: {
      'period_year': year,
      'period_month': month,
      'period_calendar': calendar,
    });
    return ItemUsageReportDto.fromJson((data as Map).cast<String, Object?>());
  }
}
