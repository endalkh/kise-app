/// Providers that feed the expense screens: the pickers' data (categories, units) and the list of
/// expenses for the month being viewed.
///
/// Each is a `FutureProvider` over the reusable API data sources, so a screen reads
/// `ref.watch(categoriesProvider)` and gets an `AsyncValue` it can render as loading / error / data
/// without owning any fetch logic. The expenses list is keyed to the selected period, so navigating
/// months refetches, and recording an expense invalidates it to refresh.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/api/api.dart';
import '../../../platform/settings.dart';

/// The owner's categories, for the category picker.
final categoriesProvider = FutureProvider<List<CategoryDto>>((ref) async {
  return ref.watch(categoriesApiProvider).list();
});

/// The units of measurement, for the unit picker on the item line.
final unitsProvider = FutureProvider<List<UnitDto>>((ref) async {
  return ref.watch(unitsApiProvider).list();
});

/// The owner's items, for the "pick an existing item" suggestions.
final itemsProvider = FutureProvider<List<ItemDto>>((ref) async {
  return ref.watch(itemsApiProvider).list();
});

/// The expenses for the month currently selected on the dashboard, newest first.
///
/// Depends on [selectedPeriodProvider], so changing month refetches. After recording an expense the
/// controller invalidates this provider to pull the fresh page.
final expensesForPeriodProvider = FutureProvider<ExpensePageDto>((ref) async {
  final period = ref.watch(selectedPeriodProvider);
  return ref.watch(expensesApiProvider).list(
        periodYear: period.year,
        periodMonth: period.month,
        periodCalendar: period.calendar.wire,
      );
});
