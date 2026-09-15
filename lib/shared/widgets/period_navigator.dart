/// The month navigator: the control that makes the dual calendar visible.
///
/// It shows the Period in the active calendar (`ሐምሌ 2018`) with the same stretch of time named in
/// the other one beneath (`July - August 2026`), because an Ethiopian month straddles two Gregorian
/// ones and hiding that would confuse rather than simplify.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/settings.dart';
import '../../platform/theme.dart';
import '../../shared_kernel/period.dart';

class PeriodNavigator extends ConsumerWidget {
  const PeriodNavigator({super.key, this.onGradient = false});

  /// Frosted-glass styling for use over the dashboard's hero gradient, where a solid surface pill
  /// would punch a hole in the picture.
  final bool onGradient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final settings = ref.watch(settingsProvider);
    final today = ref.watch(todayProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final currentPeriod = Period.fromDate(today, settings.calendar);
    final isCurrent = period == currentPeriod;

    final onHero = theme.extension<KiseColors>()!.heroForeground;
    final foreground = onGradient ? onHero : scheme.onSurface;
    final secondary = onGradient ? onHero.withValues(alpha: 0.78) : scheme.onSurfaceVariant;
    final background =
        onGradient ? onHero.withValues(alpha: 0.16) : scheme.surfaceContainerHighest;
    final buttonBackground = onGradient ? onHero.withValues(alpha: 0.14) : theme.cardTheme.color;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.chevron_left_rounded,
            tooltip: settings.say('ያለፈው ወር', 'Previous month'),
            color: foreground,
            background: buttonBackground,
            onPressed: () =>
                ref.read(selectedPeriodProvider.notifier).state = period.previous,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  period.label(settings.language),
                  key: const Key('period-label'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  period.counterpartLabel(settings.language),
                  key: const Key('period-counterpart-label'),
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (!isCurrent)
            _StepButton(
              icon: Icons.today_rounded,
              tooltip: settings.say('ወደ አሁኑ ወር', 'Back to this month'),
              color: foreground,
              background: buttonBackground,
              onPressed: () =>
                  ref.read(selectedPeriodProvider.notifier).state = currentPeriod,
              buttonKey: const Key('jump-to-today'),
            ),
          _StepButton(
            icon: Icons.chevron_right_rounded,
            tooltip: settings.say('የሚቀጥለው ወር', 'Next month'),
            color: foreground,
            background: buttonBackground,
            onPressed: () => ref.read(selectedPeriodProvider.notifier).state = period.next,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.background,
    required this.onPressed,
    this.buttonKey,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final Color? background;
  final VoidCallback onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: color),
      style: IconButton.styleFrom(backgroundColor: background),
    );
  }
}
