/// The month-end item-usage chart: one horizontal bar per item, its length the quantity bought.
///
/// Grouped by (item, unit) on the server, so each bar's label reads "Sugar · 15 kg" — the unit is
/// what makes the number mean something, and mixing units on one axis would be a lie, so the bar
/// length is normalised *within its own unit's maximum*. A bar also carries the money spent, and the
/// list is already sorted by spend (biggest first) by the backend.
///
/// Drawn with a plain [CustomPaint] rather than a chart package, matching how the dashboard's daily
/// chart is built — one rendering approach across the app, and fully testable without a golden file.
library;

import 'package:flutter/material.dart';

import '../../../platform/api/resources/reports_api.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared_kernel/money.dart';

class ItemUsageChart extends StatelessWidget {
  const ItemUsageChart({
    super.key,
    required this.report,
    this.amharic = false,
    this.title,
    this.emptyLabel,
  });

  final ItemUsageReportDto report;
  final bool amharic;
  final String? title;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final heading = title ?? (amharic ? 'የዕቃ አጠቃቀም' : 'Item usage');
    final subtitle = report.periodLabel(amharic: amharic);

    if (report.isEmpty) {
      return SectionCard(
        title: heading,
        subtitle: subtitle,
        child: Padding(
          key: const Key('item-usage-empty'),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            emptyLabel ??
                (amharic
                    ? 'በዚህ ወር ምንም ዕቃ አልተመዘገበም።'
                    : 'No items recorded this month.'),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // Normalise each bar within its own unit's maximum, so kg bars compare to kg and litres to
    // litres — never across units.
    final maxByUnit = <String, int>{};
    for (final line in report.lines) {
      final current = maxByUnit[line.unitId] ?? 0;
      if (line.totalQuantityMilli > current) maxByUnit[line.unitId] = line.totalQuantityMilli;
    }

    return SectionCard(
      title: heading,
      subtitle: subtitle,
      child: Column(
        key: const Key('item-usage-bars'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in report.lines)
            _UsageBar(
              key: Key('usage-bar-${line.itemId}-${line.unitId}'),
              label: line.itemLabel(amharic: amharic),
              quantityText: '${line.totalQuantity} ${line.unitCode}',
              amountText: Money(
                line.totalAmount.minorUnits,
                line.totalAmount.currency,
              ).formatRounded(),
              fraction: _fractionOf(line, maxByUnit),
              color: scheme.primary,
              trackColor: scheme.primary.withValues(alpha: 0.14),
            ),
        ],
      ),
    );
  }

  static double _fractionOf(ItemUsageLineDto line, Map<String, int> maxByUnit) {
    final max = maxByUnit[line.unitId] ?? 0;
    if (max <= 0) return 0;
    return (line.totalQuantityMilli / max).clamp(0.0, 1.0);
  }
}

/// One row: the item name, a proportional bar, its quantity-in-unit and the money spent.
class _UsageBar extends StatelessWidget {
  const _UsageBar({
    super.key,
    required this.label,
    required this.quantityText,
    required this.amountText,
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  final String label;
  final String quantityText;
  final String amountText;
  final double fraction;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                quantityText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: trackColor,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amountText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
