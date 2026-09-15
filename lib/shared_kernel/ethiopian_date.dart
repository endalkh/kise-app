/// Ethiopian (Ge'ez) <-> Gregorian calendar conversion.
///
/// A line-for-line port of `backend/src/kise/shared_kernel/domain/calendar/ethiopian.py`, tested
/// against the same anchor dates. The duplication is deliberate: the app labels and picks dates
/// offline, and a second implementation that drifts from the server's would be worse than no
/// implementation at all — hence the shared test vector.
///
/// The Ethiopian calendar has 13 months: 12 of 30 days, plus ጳጉሜን of 5 days, or 6 when
/// `year % 4 == 3`. Conversion runs through the Julian Day Number, which keeps it exact across
/// Gregorian leap years and century boundaries.
library;

/// JDN of Ethiopian 1-1-1 (Amete Mihret era), less the algorithm's offsets.
const int _jdEpochOffsetAmeteMihret = 1723856;

/// JDN of proleptic Gregorian 0001-01-01 is 1721426, whose ordinal day number is 1.
const int _gregorianOrdinalToJdn = 1721425;

const int monthsPerEthiopianYear = 13;

/// Amharic month names, index 0 == መስከረም (month 1).
const List<String> ethiopianMonthNamesAm = [
  'መስከረም',
  'ጥቅምት',
  'ኅዳር',
  'ታኅሣሥ',
  'ጥር',
  'የካቲት',
  'መጋቢት',
  'ሚያዝያ',
  'ግንቦት',
  'ሰኔ',
  'ሐምሌ',
  'ነሐሴ',
  'ጳጉሜን',
];

/// Latin transliteration of the Ethiopian month names.
const List<String> ethiopianMonthNamesEn = [
  'Meskerem',
  'Tikimt',
  'Hidar',
  'Tahsas',
  'Tir',
  'Yekatit',
  'Megabit',
  'Miyazia',
  'Ginbot',
  'Sene',
  'Hamle',
  'Nehase',
  'Pagumen',
];

/// Amharic weekday names, index 0 == Monday, matching `DateTime.weekday - 1`.
const List<String> ethiopianWeekdayNamesAm = [
  'ሰኞ',
  'ማክሰኞ',
  'ረቡዕ',
  'ሐሙስ',
  'ዓርብ',
  'ቅዳሜ',
  'እሁድ',
];

const List<String> gregorianMonthNamesEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Amharic renderings of the Gregorian month names, for the counterpart label.
const List<String> gregorianMonthNamesAm = [
  'ጃንዩወሪ',
  'ፌብሩወሪ',
  'ማርች',
  'ኤፕሪል',
  'ሜይ',
  'ጁን',
  'ጁላይ',
  'ኦገስት',
  'ሴፕቴምበር',
  'ኦክቶበር',
  'ኖቬምበር',
  'ዲሴምበር',
];

/// Thrown when an Ethiopian date does not exist.
class EthiopianDateError implements Exception {
  const EthiopianDateError(this.message);

  final String message;

  @override
  String toString() => 'EthiopianDateError: $message';
}

/// Ethiopian leap years are those where `year % 4 == 3`; ጳጉሜን then has 6 days.
bool isEthiopianLeapYear(int year) => year % 4 == 3;

int ethiopianMonthLength(int year, int month) {
  _validateMonth(month);
  if (month == 13) return isEthiopianLeapYear(year) ? 6 : 5;
  return 30;
}

int gregorianMonthLength(int year, int month) {
  if (month < 1 || month > 12) {
    throw EthiopianDateError('Gregorian month must be 1..12, got $month');
  }
  // Day 0 of the next month is the last day of this one.
  return DateTime(year, month + 1, 0).day;
}

void _validateMonth(int month) {
  if (month < 1 || month > monthsPerEthiopianYear) {
    throw EthiopianDateError('Ethiopian month must be between 1 and 13, got $month');
  }
}

void validateEthiopianDate(int year, int month, int day) {
  if (year < 1) {
    throw EthiopianDateError('Ethiopian year must be >= 1, got $year');
  }
  _validateMonth(month);
  final length = ethiopianMonthLength(year, month);
  if (day < 1 || day > length) {
    throw EthiopianDateError(
      '${ethiopianMonthNamesEn[month - 1]} $year has $length days, got day $day',
    );
  }
}

/// A UTC-midnight `DateTime`, which is how every date in this library is represented.
DateTime dateOnly(int year, int month, int day) => DateTime.utc(year, month, day);

int _toOrdinal(DateTime value) {
  // Days since 0001-01-01, matching Python's date.toordinal().
  final epoch = DateTime.utc(1, 1, 1);
  final utc = DateTime.utc(value.year, value.month, value.day);
  return utc.difference(epoch).inDays + 1;
}

DateTime _fromOrdinal(int ordinal) =>
    DateTime.utc(1, 1, 1).add(Duration(days: ordinal - 1));

/// Convert an Ethiopian date to its Gregorian equivalent.
DateTime ethiopianToGregorian(int year, int month, int day) {
  validateEthiopianDate(year, month, day);
  final jdn = (_jdEpochOffsetAmeteMihret + 365) +
      365 * (year - 1) +
      (year ~/ 4) +
      30 * month +
      day -
      31;
  return _fromOrdinal(jdn - _gregorianOrdinalToJdn);
}

/// Convert a Gregorian date to an Ethiopian `(year, month, day)`.
({int year, int month, int day}) gregorianToEthiopian(DateTime value) {
  final jdn = _toOrdinal(value) + _gregorianOrdinalToJdn;
  final daysSinceEpoch = jdn - _jdEpochOffsetAmeteMihret;
  final r = daysSinceEpoch % 1461;
  final n = (r % 365) + 365 * (r ~/ 1460);
  final year = 4 * (daysSinceEpoch ~/ 1461) + (r ~/ 365) - (r ~/ 1460);
  return (year: year, month: n ~/ 30 + 1, day: n % 30 + 1);
}

/// An Ethiopian calendar date.
class EthiopianDate implements Comparable<EthiopianDate> {
  EthiopianDate(this.year, this.month, this.day) {
    validateEthiopianDate(year, month, day);
  }

  factory EthiopianDate.fromGregorian(DateTime value) {
    final parts = gregorianToEthiopian(value);
    return EthiopianDate(parts.year, parts.month, parts.day);
  }

  factory EthiopianDate.today() => EthiopianDate.fromGregorian(DateTime.now());

  /// Parse `YYYY-MM-DD` written in the Ethiopian calendar.
  factory EthiopianDate.parse(String text) {
    final parts = text.trim().split('-');
    if (parts.length != 3) {
      throw EthiopianDateError('Expected an Ethiopian date as YYYY-MM-DD, got "$text"');
    }
    final numbers = parts.map(int.tryParse).toList();
    if (numbers.any((n) => n == null)) {
      throw EthiopianDateError('Invalid Ethiopian date "$text"');
    }
    return EthiopianDate(numbers[0]!, numbers[1]!, numbers[2]!);
  }

  final int year;
  final int month;
  final int day;

  DateTime toGregorian() => ethiopianToGregorian(year, month, day);

  String get monthNameAm => ethiopianMonthNamesAm[month - 1];

  String get monthNameEn => ethiopianMonthNamesEn[month - 1];

  String get iso =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// e.g. `ሐምሌ 15, 2018` or `Hamle 15, 2018`.
  String format({String locale = 'am'}) {
    final name = locale == 'am' ? monthNameAm : monthNameEn;
    return '$name $day, $year';
  }

  EthiopianDate addDays(int days) =>
      EthiopianDate.fromGregorian(toGregorian().add(Duration(days: days)));

  /// Add months, clamping the day to the target month's length — day 30 lands on ጳጉሜን 5.
  EthiopianDate addMonths(int months) {
    final total = year * monthsPerEthiopianYear + (month - 1) + months;
    final targetYear = total ~/ monthsPerEthiopianYear;
    final targetMonth = total % monthsPerEthiopianYear + 1;
    final length = ethiopianMonthLength(targetYear, targetMonth);
    return EthiopianDate(targetYear, targetMonth, day < length ? day : length);
  }

  @override
  int compareTo(EthiopianDate other) => toGregorian().compareTo(other.toGregorian());

  bool operator <(EthiopianDate other) => compareTo(other) < 0;

  bool operator <=(EthiopianDate other) => compareTo(other) <= 0;

  bool operator >(EthiopianDate other) => compareTo(other) > 0;

  bool operator >=(EthiopianDate other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is EthiopianDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => iso;
}

/// Gregorian `(first, last)` day of an Ethiopian month, inclusive.
({DateTime first, DateTime last}) ethiopianMonthBounds(int year, int month) {
  _validateMonth(month);
  return (
    first: ethiopianToGregorian(year, month, 1),
    last: ethiopianToGregorian(year, month, ethiopianMonthLength(year, month)),
  );
}

/// Gregorian `(first, last)` day of a Gregorian month, inclusive.
({DateTime first, DateTime last}) gregorianMonthBounds(int year, int month) {
  if (month < 1 || month > 12) {
    throw EthiopianDateError('Gregorian month must be between 1 and 12, got $month');
  }
  return (
    first: dateOnly(year, month, 1),
    last: dateOnly(year, month, gregorianMonthLength(year, month)),
  );
}

/// Both calendar representations of one Gregorian date, as the API returns them.
Map<String, Object?> describe(DateTime value) {
  final et = EthiopianDate.fromGregorian(value);
  return {
    'gregorian': isoDate(value),
    'gregorian_month_name': gregorianMonthNamesEn[value.month - 1],
    'ethiopian': et.iso,
    'ethiopian_year': et.year,
    'ethiopian_month': et.month,
    'ethiopian_day': et.day,
    'ethiopian_month_name_am': et.monthNameAm,
    'ethiopian_month_name_en': et.monthNameEn,
    'weekday_am': ethiopianWeekdayNamesAm[value.weekday - 1],
  };
}

/// `YYYY-MM-DD`, without the time part `DateTime.toIso8601String` adds.
String isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
