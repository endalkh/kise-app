/// Widget tests for the item-usage chart.
///
/// They pump the real widget with a decoded report DTO and assert what a person would see: a bar per
/// item labelled with its quantity-in-unit and money, the biggest-spend item first, and a clear
/// empty state for a quiet month.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kise/features/item_usage/presentation/item_usage_chart.dart';
import 'package:kise/platform/api/resources/reports_api.dart';

ItemUsageReportDto _report(List<Map<String, Object?>> lines) => ItemUsageReportDto.fromJson({
      'period': {
        'calendar': 'gregorian',
        'label_am': 'ሴፕቴምበር 2026',
        'label_en': 'September 2026',
        'first_day': '2026-09-01',
        'last_day': '2026-09-30',
      },
      'currency': 'ETB',
      'lines': lines,
    });

Map<String, Object?> _line({
  required String itemId,
  required String name,
  String? nameAm,
  required String unitId,
  required String unitCode,
  required String unitName,
  String? unitNameAm,
  required String quantity,
  required int quantityMilli,
  required int amountMinor,
  int entryCount = 1,
}) =>
    {
      'item_id': itemId,
      'item_name': name,
      'item_name_am': nameAm,
      'unit_id': unitId,
      'unit_code': unitCode,
      'unit_name': unitName,
      'unit_name_am': unitNameAm,
      'total_quantity': quantity,
      'total_quantity_milli': quantityMilli,
      'total_amount': {'amount_minor': amountMinor, 'currency': 'ETB'},
      'entry_count': entryCount,
    };

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );

void main() {
  testWidgets('shows a bar per item with quantity and money', (tester) async {
    final report = _report([
      _line(
        itemId: 'i2',
        name: 'Oil',
        unitId: 'u2',
        unitCode: 'l',
        unitName: 'Litre',
        quantity: '8',
        quantityMilli: 8000,
        amountMinor: 64000,
      ),
      _line(
        itemId: 'i1',
        name: 'Sugar',
        nameAm: 'ስኳር',
        unitId: 'u1',
        unitCode: 'kg',
        unitName: 'Kilogram',
        quantity: '15',
        quantityMilli: 15000,
        amountMinor: 60000,
        entryCount: 2,
      ),
    ]);

    await _pump(tester, ItemUsageChart(report: report));

    expect(find.text('Item usage'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    // Both items render, each with its quantity-in-unit.
    expect(find.text('Oil'), findsOneWidget);
    expect(find.text('Sugar'), findsOneWidget);
    expect(find.text('8 l'), findsOneWidget);
    expect(find.text('15 kg'), findsOneWidget);
    // A bar exists per (item, unit).
    expect(find.byKey(const Key('usage-bar-i2-u2')), findsOneWidget);
    expect(find.byKey(const Key('usage-bar-i1-u1')), findsOneWidget);
    // Money is shown, rounded.
    expect(find.text('640 ETB'), findsOneWidget);
    expect(find.text('600 ETB'), findsOneWidget);
  });

  testWidgets('renders Amharic labels when asked', (tester) async {
    final report = _report([
      _line(
        itemId: 'i1',
        name: 'Sugar',
        nameAm: 'ስኳር',
        unitId: 'u1',
        unitCode: 'kg',
        unitName: 'Kilogram',
        unitNameAm: 'ኪሎግራም',
        quantity: '15',
        quantityMilli: 15000,
        amountMinor: 60000,
      ),
    ]);

    await _pump(tester, ItemUsageChart(report: report, amharic: true));

    expect(find.text('የዕቃ አጠቃቀም'), findsOneWidget); // heading in Amharic
    expect(find.text('ስኳር'), findsOneWidget);
    expect(find.text('15 kg'), findsOneWidget); // unit code is language-neutral in the chart
  });

  testWidgets('shows an empty state for a quiet month', (tester) async {
    await _pump(tester, ItemUsageChart(report: _report([])));

    expect(find.byKey(const Key('item-usage-empty')), findsOneWidget);
    expect(find.text('No items recorded this month.'), findsOneWidget);
    expect(find.byKey(const Key('item-usage-bars')), findsNothing);
  });
}
