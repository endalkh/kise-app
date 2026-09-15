/// The dashboard.
///
/// Four things, top to bottom: a gradient hero carrying the greeting, today in both calendars and
/// the month navigator; the summary card, overlapping the hero's lower edge; the day-by-day chart;
/// the category breakdown. Each section is its own widget under `widgets/`, so this file is only the
/// arrangement.
///
/// The figures are sample data until the API exists. The calendar behaviour is real and offline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/settings.dart';
import '../../../shared/widgets/gradient_action_button.dart';
import '../../../shared/widgets/reveal.dart';
import '../../expenses/presentation/expense_form_sheet.dart';
import '../sample_data.dart';
import 'widgets/category_card.dart';
import 'widgets/daily_chart_card.dart';
import 'widgets/hero_header.dart';
import 'widgets/spend_summary_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// How far the summary card hangs below the gradient. The gradient stops this many pixels above
  /// the bottom of the hero stack, so roughly half the card sits on it and half on the page.
  static const double _heroOverlap = 118;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final period = ref.watch(selectedPeriodProvider);
    final today = ref.watch(todayProvider);
    final month = sampleMonthFor(period, settings.currency);
    final previous = sampleMonthFor(period.previous, settings.currency);
    final todayDay = period.dayOf(today);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              const Positioned.fill(bottom: _heroOverlap, child: HeroBackdrop()),
              Column(
                children: [
                  HeroHeader(today: today, settings: settings),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Reveal(
                      order: 0,
                      child: SpendSummaryCard(
                        month: month,
                        previous: previous,
                        settings: settings,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            child: Column(
              children: [
                Reveal(
                  order: 1,
                  child: DailyChartCard(
                    month: month,
                    settings: settings,
                    period: period,
                    todayIndex: todayDay == null ? null : todayDay - 1,
                  ),
                ),
                const SizedBox(height: 16),
                Reveal(
                  order: 2,
                  child: CategoryCard(month: month, settings: settings),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: GradientActionButton(
        key: const Key('add-expense'),
        icon: Icons.add_rounded,
        label: settings.say('ወጪ መዝግብ', 'Add expense'),
        onPressed: () => showExpenseForm(context),
      ),
    );
  }
}
