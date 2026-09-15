/// The top of the dashboard: the gradient backdrop and the greeting that sits on it.
///
/// Split in two so the summary card can overlap the gradient's lower edge. [HeroBackdrop] is the
/// painted background; [HeroHeader] is the content — greeting, today in both calendars, and the
/// month navigator.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../platform/settings.dart';
import '../../../../platform/theme.dart';
import '../../../../shared/widgets/kise_logo.dart';
import '../../../../shared/widgets/period_navigator.dart';
import '../../../../shared_kernel/ethiopian_date.dart';
import '../../../../shared_kernel/period.dart';

class HeroBackdrop extends StatelessWidget {
  const HeroBackdrop({super.key});

  // A slight rounding of the bottom edge, the same as the Settings header.
  static const BorderRadius _radius = BorderRadius.vertical(bottom: Radius.circular(5));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KiseColors>()!;
    return ClipRRect(
      borderRadius: _radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.heroGradient,
          ),
        ),
        child: CustomPaint(
          painter: _HeroPatternPainter(color: colors.heroForeground),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// One soft glow in the top-right corner: just enough that the gradient does not read as a flat
/// block, faint enough to stay behind the text.
class _HeroPatternPainter extends CustomPainter {
  const _HeroPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width * 0.92, size.height * 0.05);
    final radius = math.max(size.width, size.height) * 0.6;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: centre, radius: radius));
    canvas.drawCircle(centre, radius, glow);
  }

  @override
  bool shouldRepaint(_HeroPatternPainter oldDelegate) => oldDelegate.color != color;
}

class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key, required this.today, required this.settings});

  final DateTime today;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ethiopian = EthiopianDate.fromGregorian(today);
    final weekday = ethiopianWeekdayNamesAm[today.weekday - 1];
    final gregorian = '${gregorianMonthNamesEn[today.month - 1]} ${today.day}, ${today.year}';
    // The headline is whichever calendar the Owner chose; the other one sits underneath. Showing
    // the Ethiopian date to someone who picked Gregorian contradicted the month navigator.
    final isEthiopian = settings.calendar == CalendarKind.ethiopian;
    final headline =
        isEthiopian ? ethiopian.format(locale: settings.language.wire) : gregorian;
    final secondary = isEthiopian ? gregorian : ethiopian.format(locale: settings.language.wire);
    final onHero = theme.extension<KiseColors>()!.heroForeground;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const KiseLogo(size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    settings.say('ኪሴ', 'Kise'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: onHero,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                _HeroAction(
                  icon: Icons.calendar_month_outlined,
                  tooltip: settings.say('መቁጠሪያ ቀይር', 'Switch calendar'),
                  semanticKey: const Key('toggle-calendar'),
                ),
                const SizedBox(width: 4),
                _HeroAction(
                  icon: Icons.translate_rounded,
                  // The Material translate icon draws a CJK glyph, which reads as "Chinese" here.
                  // Show a text label of the language the button switches *to* instead: አማ / EN.
                  glyph: settings.isAmharic ? 'EN' : 'አማ',
                  tooltip: settings.say('ቋንቋ ቀይር', 'Switch language'),
                  semanticKey: const Key('toggle-language'),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              _greeting(settings),
              key: const Key('greeting'),
              style: theme.textTheme.bodyLarge?.copyWith(color: onHero.withValues(alpha: 0.86)),
            ),
            const SizedBox(height: 4),
            Text(
              headline,
              key: const Key('today-primary'),
              style: theme.textTheme.displaySmall?.copyWith(
                color: onHero,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.today_outlined, size: 15, color: onHero.withValues(alpha: 0.8)),
                const SizedBox(width: 6),
                Text(
                  '$secondary  ·  $weekday',
                  key: const Key('today-secondary'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onHero.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: PeriodNavigator(onGradient: true),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _greeting(AppSettings settings) {
    final name = settings.ownerName;
    if (name.isEmpty) {
      return settings.say('እንደምን አሉ!', 'Welcome back!');
    }
    return settings.say('እንደምን አሉ, $name!', 'Welcome back, $name!');
  }
}

class _HeroAction extends ConsumerWidget {
  const _HeroAction({
    required this.icon,
    required this.tooltip,
    required this.semanticKey,
    this.glyph,
  });

  final IconData icon;
  final String tooltip;
  final Key semanticKey;

  /// When set, this short label is shown instead of [icon]. Used by the language toggle: the
  /// Material translate icon renders a CJK glyph, so a plain label (ሀ / EN) is clearer.
  final String? glyph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onHero = theme.extension<KiseColors>()!.heroForeground;
    return IconButton(
      key: semanticKey,
      tooltip: tooltip,
      icon: glyph != null
          ? Text(
              glyph!,
              style: theme.textTheme.titleMedium?.copyWith(
                height: 1,
                fontWeight: FontWeight.w800,
                color: onHero,
              ),
            )
          : Icon(icon),
      style: IconButton.styleFrom(
        foregroundColor: onHero,
        backgroundColor: onHero.withValues(alpha: 0.16),
      ),
      onPressed: () {
        final controller = ref.read(settingsProvider.notifier);
        final settings = ref.read(settingsProvider);
        if (semanticKey == const Key('toggle-language')) {
          controller.setLanguage(settings.isAmharic ? Language.english : Language.amharic);
          return;
        }
        final next = settings.calendar.other;
        final period = ref.read(selectedPeriodProvider);
        controller.setCalendar(next);
        // The viewed month has to follow the calendar, or the navigator would show a Gregorian
        // month while the labels claim Ethiopian.
        ref.read(selectedPeriodProvider.notifier).state = period.asCalendar(next);
      },
    );
  }
}
