/// Money as a value object, mirroring the backend's.
///
/// Integer minor units (santim for ETB) so no arithmetic in the app can drift. The currency is part
/// of the value: adding ETB to USD throws rather than silently converting.
library;

import 'package:intl/intl.dart';

const int minorUnitsPerMajor = 100;
const String defaultCurrency = 'ETB';

class CurrencyMismatch implements Exception {
  const CurrencyMismatch(this.left, this.right);

  final String left;
  final String right;

  @override
  String toString() => 'CurrencyMismatch: cannot combine $left with $right';
}

class Money implements Comparable<Money> {
  const Money(this.minorUnits, [this.currency = defaultCurrency]);

  const Money.zero([this.currency = defaultCurrency]) : minorUnits = 0;

  /// From a major-unit amount: `Money.fromMajor(1250.75)` -> 125075 santim.
  factory Money.fromMajor(num amount, [String currency = defaultCurrency]) =>
      Money((amount * minorUnitsPerMajor).round(), currency);

  /// From the API, which always sends integer minor units.
  factory Money.fromJson(Map<String, Object?> json) => Money(
        (json['amount_minor'] as num).toInt(),
        (json['currency'] as String?) ?? defaultCurrency,
      );

  final int minorUnits;
  final String currency;

  double get majorUnits => minorUnits / minorUnitsPerMajor;

  bool get isPositive => minorUnits > 0;

  bool get isZero => minorUnits == 0;

  void _assertSameCurrency(Money other) {
    if (other.currency != currency) {
      throw CurrencyMismatch(currency, other.currency);
    }
  }

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currency);
  }

  Money times(int factor) => Money(minorUnits * factor, currency);

  /// This amount as a fraction of [total]; 0 when the total is zero.
  double shareOf(Money total) {
    _assertSameCurrency(total);
    if (total.minorUnits == 0) return 0;
    return minorUnits / total.minorUnits;
  }

  /// `1,250.75 ETB`, with thousands separators.
  String format({bool withCurrency = true, String locale = 'en'}) {
    final formatted = NumberFormat('#,##0.00', locale).format(majorUnits);
    return withCurrency ? '$formatted $currency' : formatted;
  }

  /// `1,251 ETB` — for dashboard tiles where the santim are noise.
  String formatRounded({bool withCurrency = true, String locale = 'en'}) {
    final formatted = NumberFormat('#,##0', locale).format(majorUnits.round());
    return withCurrency ? '$formatted $currency' : formatted;
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  bool operator <(Money other) => compareTo(other) < 0;

  bool operator <=(Money other) => compareTo(other) <= 0;

  bool operator >(Money other) => compareTo(other) > 0;

  bool operator >=(Money other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Money && other.minorUnits == minorUnits && other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => format();
}

/// Total a list of amounts, returning zero in [currency] when the list is empty.
Money sumMoney(Iterable<Money> amounts, [String currency = defaultCurrency]) {
  var total = Money.zero(currency);
  for (final amount in amounts) {
    total = total + amount;
  }
  return total;
}
