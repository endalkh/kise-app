/// The month's headline: the total spent, how it compares with last month, the fixed/dynamic split,
/// and — when a budget is set — a ring showing how much of it is gone.
///
/// This card floats over the hero gradient, so unlike the other sections it carries a shadow. When
/// the month changes the total slides in, so the eye is told what moved.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../platform/settings.dart';
import '../../../../platform/theme.dart';
import '../../../../shared_kernel/money.dart';
import '../../sample_data.dart';

class SpendSummaryCard extends StatelessWidget {
  const SpendSummaryCard({
    super.key,
    required this.month,
    required this.previous,
    required this.settings,
  });

  final SampleMonth month;
  final SampleMonth previous;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.extension<KiseColors>()!.accent;
    final total = month.grandTotal;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.say(
                        'የወሩ ጠቅላላ ወጪ  ·  ${month.expenseCount} ወጪዎች',
                        'Spent this month  ·  ${month.expenseCount} expenses',
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _AnimatedTotal(total: total),
                    const SizedBox(height: 8),
                    _ChangeLine(
                      current: total,
                      previous: previous.grandTotal,
                      settings: settings,
                    ),
                  ],
                ),
              ),
              if (settings.hasBudget) ...[
                const SizedBox(width: 16),
                BudgetRing(
                  share: total.shareOf(settings.monthlyBudget),
                  caption: settings.say('ከገደብ', 'of budget'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          SplitBar(fixedShare: month.committed.shareOf(total)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _LegendEntry(
                  color: scheme.primary,
                  label: settings.say('ቋሚ', 'Fixed'),
                  amount: month.committed,
                  note: month.outstanding.isZero
                      ? settings.say('ተከፍሏል', 'settled')
                      : settings.say(
                          '${month.outstanding.formatRounded(withCurrency: false)} ይቀራል',
                          '${month.outstanding.formatRounded(withCurrency: false)} outstanding',
                        ),
                ),
              ),
              Expanded(
                child: _LegendEntry(
                  color: accent,
                  label: settings.say('ተለዋዋጭ', 'Dynamic'),
                  amount: month.dynamicTotal,
                  note: settings.say('በየቀኑ', 'day to day'),
                ),
              ),
            ],
          ),
          if (settings.hasBudget) ...[
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 14),
            _BudgetLine(spent: total, budget: settings.monthlyBudget, settings: settings),
          ],
        ],
      ),
    );
  }
}

/// The hero figure. A new month's total slides up into place; the old one fades out.
class _AnimatedTotal extends StatelessWidget {
  const _AnimatedTotal({required this.total});

  final Money total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, if (current != null) current],
      ),
      child: KeyedSubtree(
        key: ValueKey('${total.minorUnits}-${total.currency}'),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            total.formatRounded(),
            key: const Key('grand-total'),
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              height: 1.1,
              letterSpacing: -1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// One quiet line under the total: direction against last month. Hidden when there is nothing to
/// compare against.
class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.current, required this.previous, required this.settings});

  final Money current;
  final Money previous;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    if (previous.isZero) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    final change = ((current.minorUnits - previous.minorUnits) / previous.minorUnits * 100).round();
    final (icon, tint) = switch (change.sign) {
      1 => (Icons.north_east_rounded, scheme.error),
      -1 => (Icons.south_east_rounded, scheme.primary),
      _ => (Icons.east_rounded, scheme.onSurfaceVariant),
    };
    final magnitude = change.abs();
    final changeText = switch (change.sign) {
      1 => settings.say('ከባለፈው ወር $magnitude% በላይ', '$magnitude% more than last month'),
      -1 => settings.say('ከባለፈው ወር $magnitude% በታች', '$magnitude% less than last month'),
      _ => settings.say('እንደ ባለፈው ወር', 'same as last month'),
    };

    return Row(
      children: [
        Icon(icon, size: 14, color: tint),
        const SizedBox(width: 4),
        Flexible(child: Text(changeText, style: style)),
      ],
    );
  }
}

/// A ring meter. The track is a lighter step of the same colour as the fill, so the whole ring reads
/// as one gauge; the fill turns to the error colour once the budget is exceeded.
class BudgetRing extends StatelessWidget {
  const BudgetRing({super.key, required this.share, required this.caption, this.size = 88});

  /// Spent as a fraction of the budget; may exceed 1.
  final double share;
  final String caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final over = share > 1;
    final fill = over ? scheme.error : scheme.primary;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: share.clamp(0, 1).toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => CustomPaint(
        painter: _RingPainter(value: value, fill: fill, track: fill.withValues(alpha: 0.14)),
        child: child,
      ),
      child: SizedBox.square(
        dimension: size,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${(share * 100).round()}%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: over ? scheme.error : scheme.onSurface,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.fill, required this.track});

  final double value;
  final Color fill;
  final Color track;

  static const double _stroke = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final arcRect = (Offset.zero & size).deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, 0, math.pi * 2, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, paint..color = fill);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.fill != fill || oldDelegate.track != track;
}

/// Fixed and dynamic spending as a single bar, separated by a gap in the surface colour rather than
/// a stroke. The split eases to its new proportion when the month changes.
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.fixedShare});

  final double fixedShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.extension<KiseColors>()!.accent;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: fixedShare, end: fixedShare),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, share, _) {
        final fixedFlex = (share * 1000).round().clamp(1, 999);
        return Row(
          children: [
            Expanded(
              flex: fixedFlex,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(999)),
                ),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              flex: 1000 - fixedFlex,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(999)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.color,
    required this.label,
    required this.amount,
    required this.note,
  });

  final Color color;
  final String label;
  final Money amount;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: muted),
              Text(
                amount.formatRounded(withCurrency: false),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(note, style: muted),
            ],
          ),
        ),
      ],
    );
  }
}

/// The budget as words: the target on the left, what is left (or by how much it is over) on the
/// right. The ring above carries the percentage, so it is not repeated here.
class _BudgetLine extends StatelessWidget {
  const _BudgetLine({required this.spent, required this.budget, required this.settings});

  final Money spent;
  final Money budget;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final over = spent > budget;
    final difference = over ? spent - budget : budget - spent;
    final differenceText = difference.formatRounded(withCurrency: false);

    return Row(
      children: [
        Icon(
          over ? Icons.warning_amber_rounded : Icons.savings_outlined,
          size: 18,
          color: over ? scheme.error : scheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            settings.say('ገደብ ${budget.formatRounded()}', 'Budget ${budget.formatRounded()}'),
            key: const Key('budget-progress'),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          over
              ? settings.say('በ$differenceText አልፈዋል', '$differenceText over')
              : settings.say('$differenceText ይቀራል', '$differenceText left'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: over ? scheme.error : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
