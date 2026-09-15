/// Period — one month in a named calendar. A port of the backend's `Period`.
///
/// The trick that keeps the two calendars from tangling: inside its own calendar a Period collapses
/// to a single integer [index], so ordering and range checks are integer comparisons. Comparing
/// *across* calendars only ever happens by overlapping the Gregorian spans, in [overlaps] and
/// [asCalendar], exactly as on the server.
library;

import 'ethiopian_date.dart';

enum CalendarKind {
  ethiopian('ethiopian'),
  gregorian('gregorian');

  const CalendarKind(this.wire);

  /// The value the API uses.
  final String wire;

  int get monthsPerYear => this == CalendarKind.ethiopian ? 13 : 12;

  CalendarKind get other =>
      this == CalendarKind.ethiopian ? CalendarKind.gregorian : CalendarKind.ethiopian;

  static CalendarKind parse(String value) => CalendarKind.values.firstWhere(
        (kind) => kind.wire == value.trim().toLowerCase(),
        orElse: () => throw ArgumentError('Unknown calendar "$value"'),
      );
}

enum Language {
  amharic('am'),
  english('en');

  const Language(this.wire);

  final String wire;

  bool get isAmharic => this == Language.amharic;

  static Language parse(String value) => Language.values.firstWhere(
        (language) => language.wire == value.trim().toLowerCase(),
        orElse: () => throw ArgumentError('Unknown language "$value"'),
      );
}

class Period implements Comparable<Period> {
  Period(this.calendar, this.year, this.month) {
    if (year < 1) {
      throw ArgumentError('Period year must be positive, got $year');
    }
    if (month < 1 || month > calendar.monthsPerYear) {
      throw ArgumentError(
        '${calendar.wire} months run 1..${calendar.monthsPerYear}, got $month',
      );
    }
  }

  /// The Period of [calendar] that contains a Gregorian date.
  factory Period.fromDate(DateTime value, CalendarKind calendar) {
    if (calendar == CalendarKind.ethiopian) {
      final parts = gregorianToEthiopian(value);
      return Period(calendar, parts.year, parts.month);
    }
    return Period(calendar, value.year, value.month);
  }

  factory Period.fromIndex(CalendarKind calendar, int index) => Period(
        calendar,
        index ~/ calendar.monthsPerYear,
        index % calendar.monthsPerYear + 1,
      );

  /// The Period containing today.
  factory Period.current(CalendarKind calendar, {DateTime? now}) =>
      Period.fromDate(now ?? DateTime.now(), calendar);

  final CalendarKind calendar;
  final int year;
  final int month;

  /// Absolute month number, which makes ordering an integer comparison.
  int get index => year * calendar.monthsPerYear + (month - 1);

  void _assertSameCalendar(Period other) {
    if (other.calendar != calendar) {
      throw ArgumentError(
        'Cannot order a ${calendar.wire} Period against a ${other.calendar.wire} one; '
        'use overlaps() instead',
      );
    }
  }

  Period shift(int months) => Period.fromIndex(calendar, index + months);

  Period get next => shift(1);

  Period get previous => shift(-1);

  int get lengthInDays => calendar == CalendarKind.ethiopian
      ? ethiopianMonthLength(year, month)
      : gregorianMonthLength(year, month);

  /// The Gregorian date of a day in this Period, clamped to the month's length — which is what
  /// makes "due on the 30th" behave in ጳጉሜን (5 days) and in February.
  DateTime day(int dayOfMonth) {
    if (dayOfMonth < 1) {
      throw ArgumentError('Day of month must be >= 1, got $dayOfMonth');
    }
    final clamped = dayOfMonth < lengthInDays ? dayOfMonth : lengthInDays;
    return calendar == CalendarKind.ethiopian
        ? ethiopianToGregorian(year, month, clamped)
        : dateOnly(year, month, clamped);
  }

  ({DateTime first, DateTime last}) get gregorianSpan =>
      calendar == CalendarKind.ethiopian
          ? ethiopianMonthBounds(year, month)
          : gregorianMonthBounds(year, month);

  bool contains(DateTime value) {
    final span = gregorianSpan;
    final day = DateTime.utc(value.year, value.month, value.day);
    return !day.isBefore(span.first) && !day.isAfter(span.last);
  }

  /// Which day of this month (1-based, in this calendar) a Gregorian date falls on, or null when
  /// the date is outside the month. Lets the dashboard mark "today" on a chart of days.
  int? dayOf(DateTime value) {
    if (!contains(value)) return null;
    return calendar == CalendarKind.ethiopian
        ? gregorianToEthiopian(value).day
        : value.day;
  }

  /// Do the two Periods share a day? The only cross-calendar comparison.
  bool overlaps(Period other) {
    final a = gregorianSpan;
    final b = other.gregorianSpan;
    return !a.first.isAfter(b.last) && !b.first.isAfter(a.last);
  }

  /// How many days the two Periods share.
  int overlapDays(Period other) {
    final a = gregorianSpan;
    final b = other.gregorianSpan;
    final first = a.first.isAfter(b.first) ? a.first : b.first;
    final last = a.last.isBefore(b.last) ? a.last : b.last;
    final days = last.difference(first).inDays + 1;
    return days > 0 ? days : 0;
  }

  /// This stretch of time named in another calendar — the counterpart sharing the most days.
  Period asCalendar(CalendarKind target) {
    if (target == calendar) return this;
    final span = gregorianSpan;
    final candidates = <Period>{
      Period.fromDate(span.first, target),
      Period.fromDate(span.last, target),
    }.toList();
    candidates.sort((a, b) {
      final byOverlap = b.overlapDays(this).compareTo(a.overlapDays(this));
      return byOverlap != 0 ? byOverlap : a.index.compareTo(b.index);
    });
    return candidates.first;
  }

  String get monthNameAm => calendar == CalendarKind.ethiopian
      ? ethiopianMonthNamesAm[month - 1]
      : gregorianMonthNamesAm[month - 1];

  String get monthNameEn => calendar == CalendarKind.ethiopian
      ? ethiopianMonthNamesEn[month - 1]
      : gregorianMonthNamesEn[month - 1];

  /// e.g. `ሐምሌ 2018` or `July 2026`.
  String label(Language language) =>
      '${language.isAmharic ? monthNameAm : monthNameEn} $year';

  /// The same stretch named in the other calendar, e.g. `July - August 2026`.
  String counterpartLabel(Language language) {
    final span = gregorianSpan;
    final target = calendar.other;
    final start = Period.fromDate(span.first, target);
    final end = Period.fromDate(span.last, target);
    if (start == end) return start.label(language);
    final startName = language.isAmharic ? start.monthNameAm : start.monthNameEn;
    final endName = language.isAmharic ? end.monthNameAm : end.monthNameEn;
    if (start.year == end.year) return '$startName - $endName ${end.year}';
    return '${start.label(language)} - ${end.label(language)}';
  }

  @override
  int compareTo(Period other) {
    _assertSameCalendar(other);
    return index.compareTo(other.index);
  }

  bool operator <(Period other) => compareTo(other) < 0;

  bool operator <=(Period other) => compareTo(other) <= 0;

  bool operator >(Period other) => compareTo(other) > 0;

  bool operator >=(Period other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Period &&
      other.calendar == calendar &&
      other.year == year &&
      other.month == month;

  @override
  int get hashCode => Object.hash(calendar, year, month);

  @override
  String toString() => '${calendar.wire} $year-${month.toString().padLeft(2, '0')}';
}
