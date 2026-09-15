/// Sample figures for the dashboard.
///
/// TEMPORARY. The API that answers "how much did I spend in ሐምሌ" is the next piece of work; until
/// then the dashboard needs something shaped like real data so the layout can be judged. Everything
/// here is deterministic — derived from the Period — so screenshots and tests are stable.
library;

import 'package:flutter/material.dart';

import '../../shared_kernel/money.dart';
import '../../shared_kernel/period.dart';

/// Category colours, in a fixed order that has been checked for colour-vision deficiency: each
/// adjacent pair stays distinguishable under protan, deutan and tritan simulation. The colour
/// belongs to the category, not to its rank, so a month where Food outgrows Transport does not
/// repaint either of them.
class CategoryPalette {
  CategoryPalette._();

  static const Color blue = Color(0xFF2A78D6);
  static const Color orange = Color(0xFFEB6834);
  static const Color aqua = Color(0xFF1BAF7A);
  static const Color yellow = Color(0xFFEDA100);
  static const Color magenta = Color(0xFFE87BA4);
}

class SampleCategory {
  const SampleCategory({
    required this.nameAm,
    required this.nameEn,
    required this.color,
    required this.icon,
    required this.amountMinor,
    this.fixed = false,
  });

  final String nameAm;
  final String nameEn;
  final Color color;
  final IconData icon;
  final int amountMinor;

  /// A monthly commitment (rent, internet) rather than day-to-day spending.
  final bool fixed;

  String name(bool amharic) => amharic ? nameAm : nameEn;
}

class SampleMonth {
  const SampleMonth({
    required this.committed,
    required this.settled,
    required this.dynamicTotal,
    required this.expenseCount,
    required this.categories,
    required this.daily,
  });

  final Money committed;
  final Money settled;
  final Money dynamicTotal;
  final int expenseCount;
  final List<SampleCategory> categories;

  /// One entry per day of the month, in minor units. Dynamic spending only.
  final List<int> daily;

  Money get outstanding => committed - settled;

  Money get grandTotal => committed + dynamicTotal;

  /// The categories, largest first — the order every breakdown on the dashboard uses.
  List<SampleCategory> get categoriesBySize =>
      [...categories]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));

  int get peakDaily => daily.reduce((a, b) => a > b ? a : b);

  /// Zero-based index of the busiest day.
  int get peakDayIndex => daily.indexOf(peakDaily);

  int get averageDaily => daily.reduce((a, b) => a + b) ~/ daily.length;
}

/// Build a plausible month. The shape varies a little with the Period so paging feels alive.
SampleMonth sampleMonthFor(Period period, String currency) {
  final seed = period.index % 7;
  final categories = <SampleCategory>[
    SampleCategory(
      nameAm: 'ቤት ኪራይ',
      nameEn: 'Rent',
      color: CategoryPalette.blue,
      icon: Icons.home_rounded,
      amountMinor: 800000,
      fixed: true,
    ),
    SampleCategory(
      nameAm: 'ምግብ',
      nameEn: 'Food',
      color: CategoryPalette.orange,
      icon: Icons.restaurant_rounded,
      amountMinor: 62000 + seed * 3100,
    ),
    SampleCategory(
      nameAm: 'ትራንስፖርት',
      nameEn: 'Transport',
      color: CategoryPalette.aqua,
      icon: Icons.directions_bus_rounded,
      amountMinor: 31500 + seed * 1900,
    ),
    SampleCategory(
      nameAm: 'ካርድና ኢንተርኔት',
      nameEn: 'Airtime & Internet',
      color: CategoryPalette.yellow,
      icon: Icons.wifi_rounded,
      amountMinor: 20000,
      fixed: true,
    ),
    SampleCategory(
      nameAm: 'ጤና',
      nameEn: 'Health',
      color: CategoryPalette.magenta,
      icon: Icons.favorite_rounded,
      amountMinor: 9000 + seed * 800,
    ),
  ];

  final days = period.lengthInDays;
  // Dynamic spending only. A rent-sized payment on the due day would be twenty times any real
  // day's spending, flattening every other bar into a stub — and "day by day" is about the daily
  // rhythm, not the monthly commitment, which the fixed/dynamic split already reports.
  final daily = List<int>.generate(days, (index) {
    final base = 1800 + ((index * 37 + seed * 11) % 2600);
    final quiet = (index + seed) % 7 == 0; // a slower day each week
    final busy = (index + seed) % 11 == 0; // an occasional bigger shop
    if (quiet) return base ~/ 3;
    return busy ? base * 2 : base;
  });

  final committedMinor = categories
      .where((category) => category.fixed)
      .fold<int>(0, (total, category) => total + category.amountMinor);
  final settledMinor = seed.isEven ? committedMinor : 800000;
  final dynamicMinor = categories
      .where((category) => !category.fixed)
      .fold<int>(0, (total, category) => total + category.amountMinor);

  return SampleMonth(
    committed: Money(committedMinor, currency),
    settled: Money(settledMinor, currency),
    dynamicTotal: Money(dynamicMinor, currency),
    expenseCount: 17 + seed,
    categories: categories,
    daily: daily,
  );
}
