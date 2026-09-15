/// Where the month went: one bar for the part-to-whole picture, then a row per category with its
/// icon, name, share and amount. Identity is carried by the icon and name beside each colour, never
/// by the colour alone.
library;

import 'package:flutter/material.dart';

import '../../../../platform/settings.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared_kernel/money.dart';
import '../../sample_data.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.month, required this.settings});

  final SampleMonth month;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final total = month.grandTotal;
    final sorted = month.categoriesBySize;

    return SectionCard(
      title: settings.say('በምድብ', 'By category'),
      subtitle: settings.say('የወሩ ወጪ ክፍፍል', 'Where the month went'),
      child: Column(
        children: [
          _ShareBar(categories: sorted, total: total),
          const SizedBox(height: 8),
          for (final category in sorted)
            _CategoryRow(category: category, total: total, settings: settings),
        ],
      ),
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.categories, required this.total});

  final List<SampleCategory> categories;
  final Money total;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Row(
        children: [
          for (var index = 0; index < categories.length; index++) ...[
            if (index > 0) const SizedBox(width: 3),
            Expanded(
              flex: (Money(categories[index].amountMinor, total.currency).shareOf(total) * 1000)
                  .round()
                  .clamp(6, 1000),
              child: Container(height: 10, color: categories[index].color),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.total, required this.settings});

  final SampleCategory category;
  final Money total;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final amount = Money(category.amountMinor, settings.currency);
    final percent = (amount.shareOf(total) * 100).round();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(category.icon, size: 20, color: category.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              category.name(settings.isAmharic),
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount.formatRounded(withCurrency: false),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '$percent%',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
