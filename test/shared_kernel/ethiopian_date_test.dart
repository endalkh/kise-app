/// The Dart calendar engine, checked against the **same anchor table** as the Python one in
/// `backend/tests/unit/test_ethiopian_calendar.py`.
///
/// This is the point of the duplication: the app renders and picks Ethiopian dates offline, so the
/// two implementations must agree exactly. If either drifts, one of these fails.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kise/shared_kernel/ethiopian_date.dart';

/// (ethiopianYear, ethiopianMonth, ethiopianDay, gregorian)
final anchors = <({int year, int month, int day, DateTime gregorian})>[
  // Before 1900 the mapping sits a day earlier: Gregorian skipped the 1900 leap day but the
  // Ethiopian calendar has no century exception.
  (year: 1855, month: 1, day: 1, gregorian: DateTime.utc(1862, 9, 10)),
  (year: 1992, month: 4, day: 22, gregorian: DateTime.utc(2000, 1, 1)),
  (year: 2000, month: 1, day: 1, gregorian: DateTime.utc(2007, 9, 12)),
  (year: 2007, month: 5, day: 8, gregorian: DateTime.utc(2015, 1, 16)),
  (year: 2012, month: 7, day: 22, gregorian: DateTime.utc(2020, 3, 31)),
  (year: 2016, month: 4, day: 22, gregorian: DateTime.utc(2024, 1, 1)),
  (year: 2016, month: 6, day: 21, gregorian: DateTime.utc(2024, 2, 29)),
  (year: 2017, month: 13, day: 5, gregorian: DateTime.utc(2025, 9, 10)),
  (year: 2018, month: 12, day: 29, gregorian: DateTime.utc(2026, 9, 4)),
  (year: 2019, month: 13, day: 6, gregorian: DateTime.utc(2027, 9, 11)),
];

void main() {
  group('anchors', () {
    for (final anchor in anchors) {
      final label = '${anchor.year}-${anchor.month}-${anchor.day}';

      test('$label -> Gregorian', () {
        expect(
          ethiopianToGregorian(anchor.year, anchor.month, anchor.day),
          anchor.gregorian,
        );
      });

      test('$label <- Gregorian', () {
        final parts = gregorianToEthiopian(anchor.gregorian);
        expect(parts.year, anchor.year);
        expect(parts.month, anchor.month);
        expect(parts.day, anchor.day);
      });
    }
  });

  test('every day for 40 years survives a round trip', () {
    var current = DateTime.utc(1990, 1, 1);
    final end = DateTime.utc(2030, 1, 1);
    var checked = 0;
    while (!current.isAfter(end)) {
      final et = EthiopianDate.fromGregorian(current);
      expect(et.toGregorian(), current, reason: 'round trip failed for $current');
      current = current.add(const Duration(days: 1));
      checked++;
    }
    expect(checked, greaterThan(14600));
  });

  test('new year falls on 11 or 12 September, 12 before a Gregorian leap year', () {
    for (var gregorianYear = 1990; gregorianYear <= 2050; gregorianYear++) {
      final newYear = ethiopianToGregorian(gregorianYear - 7, 1, 1);
      expect(newYear.month, 9);
      final following = gregorianYear + 1;
      final followingIsLeap =
          following % 4 == 0 && (following % 100 != 0 || following % 400 == 0);
      expect(newYear.day, followingIsLeap ? 12 : 11, reason: 'year $gregorianYear');
    }
  });

  test('the pre-1900 shift is intentional', () {
    expect(ethiopianToGregorian(1889, 1, 1), DateTime.utc(1896, 9, 10));
    expect(ethiopianToGregorian(1891, 1, 1), DateTime.utc(1898, 9, 10));
    expect(ethiopianToGregorian(1892, 1, 1), DateTime.utc(1899, 9, 11));
    expect(ethiopianToGregorian(1896, 1, 1), DateTime.utc(1903, 9, 12));
    expect(ethiopianToGregorian(2018, 1, 1), DateTime.utc(2025, 9, 11));
  });

  test('leap years and Pagumen length', () {
    for (final year in [2011, 2015, 2019]) {
      expect(isEthiopianLeapYear(year), isTrue);
      expect(ethiopianMonthLength(year, 13), 6);
    }
    for (final year in [2016, 2017, 2018]) {
      expect(isEthiopianLeapYear(year), isFalse);
      expect(ethiopianMonthLength(year, 13), 5);
    }
  });

  test('the first twelve months have 30 days', () {
    for (var month = 1; month <= 12; month++) {
      expect(ethiopianMonthLength(2017, month), 30);
    }
  });

  test('month names are Amharic and complete', () {
    expect(ethiopianMonthNamesAm.length, 13);
    expect(ethiopianMonthNamesEn.length, 13);
    expect(ethiopianMonthNamesAm.first, 'መስከረም');
    expect(ethiopianMonthNamesAm[10], 'ሐምሌ');
    expect(ethiopianMonthNamesAm[11], 'ነሐሴ');
    expect(ethiopianMonthNamesAm[12], 'ጳጉሜን');
    expect(ethiopianMonthNamesEn[10], 'Hamle');
    expect(ethiopianMonthNamesEn[11], 'Nehase');
  });

  test('invalid dates are refused', () {
    expect(() => EthiopianDate(2017, 13, 6), throwsA(isA<EthiopianDateError>()));
    expect(() => EthiopianDate(2017, 14, 1), throwsA(isA<EthiopianDateError>()));
    expect(() => EthiopianDate(2017, 1, 31), throwsA(isA<EthiopianDateError>()));
    expect(() => EthiopianDate(2017, 1, 0), throwsA(isA<EthiopianDateError>()));
    expect(EthiopianDate(2019, 13, 6).day, 6); // leap year, so this one exists
  });

  test('month bounds', () {
    final hamle = ethiopianMonthBounds(2018, 11);
    expect(hamle.first, DateTime.utc(2026, 7, 8));
    expect(hamle.last, DateTime.utc(2026, 8, 6));

    final february = gregorianMonthBounds(2024, 2);
    expect(february.last, DateTime.utc(2024, 2, 29));
  });

  test('addMonths clamps into Pagumen and rolls the year', () {
    expect(EthiopianDate(2017, 12, 30).addMonths(1), EthiopianDate(2017, 13, 5));
    expect(EthiopianDate(2017, 13, 5).addMonths(1), EthiopianDate(2018, 1, 5));
  });

  test('addDays crosses the new year', () {
    expect(EthiopianDate(2017, 13, 5).addDays(1), EthiopianDate(2018, 1, 1));
  });

  test('parse and format', () {
    final date = EthiopianDate.parse('2018-11-15');
    expect(date.year, 2018);
    expect(date.iso, '2018-11-15');
    expect(date.format(locale: 'am'), 'ሐምሌ 15, 2018');
    expect(date.format(locale: 'en'), 'Hamle 15, 2018');
    expect(() => EthiopianDate.parse('2018/11/15'), throwsA(isA<EthiopianDateError>()));
  });

  test('describe carries both calendars', () {
    final payload = describe(DateTime.utc(2026, 9, 4));
    expect(payload['gregorian'], '2026-09-04');
    expect(payload['ethiopian'], '2018-12-29');
    expect(payload['ethiopian_month_name_am'], 'ነሐሴ');
    expect(payload['weekday_am'], 'ዓርብ'); // 4 September 2026 is a Friday
  });

  test('comparison', () {
    expect(EthiopianDate(2018, 11, 1) < EthiopianDate(2018, 11, 2), isTrue);
    expect(EthiopianDate(2018, 13, 5) < EthiopianDate(2019, 1, 1), isTrue);
    expect(EthiopianDate(2018, 11, 1) == EthiopianDate(2018, 11, 1), isTrue);
  });
}
