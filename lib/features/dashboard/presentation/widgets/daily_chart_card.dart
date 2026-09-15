/// One column per day of the month, drawn with a painter.
///
/// Emphasis, not decoration: every day is a quiet tint of the brand colour, today (when the viewed
/// month contains it) and the tapped day are solid, and the busiest day carries the one direct
/// label. Tapping a column shows its value; changing month clears the selection and replays the
/// grow-in.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../platform/settings.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared_kernel/money.dart';
import '../../../../shared_kernel/period.dart';
import '../../sample_data.dart';

class DailyChartCard extends StatefulWidget {
  const DailyChartCard({
    super.key,
    required this.month,
    required this.settings,
    required this.period,
    this.todayIndex,
  });

  final SampleMonth month;
  final AppSettings settings;
  final Period period;

  /// Zero-based index of today within the month, or null when today is in another month.
  final int? todayIndex;

  @override
  State<DailyChartCard> createState() => _DailyChartCardState();
}

class _DailyChartCardState extends State<DailyChartCard> {
  int? _selected;

  @override
  void didUpdateWidget(covariant DailyChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = widget.settings;
    final month = widget.month;
    final currency = settings.currency;
    final peak = Money(month.peakDaily, currency);
    final average = Money(month.averageDaily, currency);
    final selected = _selected;

    return SectionCard(
      title: settings.say('በየቀኑ', 'Day by day'),
      subtitle: settings.say(
        'ተለዋዋጭ ወጪ ብቻ  ·  ከፍተኛ ${peak.formatRounded()}',
        'Dynamic spending only  ·  peak ${peak.formatRounded()}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 184,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return TweenAnimationBuilder<double>(
                  key: ValueKey(widget.period),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => _select(details.localPosition, size),
                    child: CustomPaint(
                      size: size,
                      painter: _DailyColumnsPainter(
                        values: month.daily,
                        niceMax: niceCeiling(month.peakDaily),
                        progress: progress,
                        solid: {
                          if (widget.todayIndex != null) widget.todayIndex!,
                          if (selected != null) selected,
                        },
                        labelIndex: progress == 1 ? (selected ?? month.peakDayIndex) : null,
                        labelText: _dayLabel(selected ?? month.peakDayIndex),
                        barColor: scheme.primary,
                        mutedBarColor: scheme.primary.withValues(alpha: 0.28),
                        gridColor: scheme.outlineVariant.withValues(alpha: 0.45),
                        tickStyle: theme.textTheme.labelSmall!.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        calloutStyle: theme.textTheme.labelSmall!.copyWith(
                          color: scheme.onInverseSurface,
                          fontWeight: FontWeight.w700,
                        ),
                        calloutColor: scheme.inverseSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: selected == null
                    ? Text(
                        settings.say(
                          'የቀን አማካይ ${average.formatRounded()}',
                          'avg ${average.formatRounded()} a day',
                        ),
                        key: const Key('daily-average'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    : Text(
                        '${settings.say('ቀን', 'Day')} ${selected + 1}  ·  '
                        '${Money(month.daily[selected], currency).formatRounded()}',
                        key: const Key('selected-day'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              if (selected != null)
                _FooterNote(
                  color: scheme.onSurfaceVariant,
                  label: settings.say('አጥፋ', 'Clear'),
                  icon: Icons.close_rounded,
                  onTap: () => setState(() => _selected = null),
                )
              else if (widget.todayIndex != null)
                _FooterNote(color: scheme.primary, label: settings.say('ዛሬ', 'Today')),
            ],
          ),
        ],
      ),
    );
  }

  String _dayLabel(int index) =>
      Money(widget.month.daily[index], widget.settings.currency).formatRounded(withCurrency: false);

  void _select(Offset position, Size size) {
    final index = _DailyColumnsPainter.indexAt(position, size, widget.month.daily.length);
    if (index == null) return;
    setState(() => _selected = _selected == index ? null : index);
  }
}

/// A dot or icon with a word, for the chart footer.
class _FooterNote extends StatelessWidget {
  const _FooterNote({required this.color, required this.label, this.icon, this.onTap});

  final Color color;
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 14, color: color)
        else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: content),
    );
  }
}

/// The smallest of 1, 2, 2.5, 5 or 10 times a power of ten that is at least [value], so the axis
/// tops out at a clean number (88 ETB peaks under a 100 ETB axis).
int niceCeiling(int value) {
  if (value <= 0) return 1;
  final magnitude = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
  for (final step in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    final candidate = (step * magnitude).ceil();
    if (candidate >= value) return candidate;
  }
  return value;
}

class _DailyColumnsPainter extends CustomPainter {
  const _DailyColumnsPainter({
    required this.values,
    required this.niceMax,
    required this.progress,
    required this.solid,
    required this.labelIndex,
    required this.labelText,
    required this.barColor,
    required this.mutedBarColor,
    required this.gridColor,
    required this.tickStyle,
    required this.calloutStyle,
    required this.calloutColor,
  });

  final List<int> values;
  final int niceMax;
  final double progress;
  final Set<int> solid;
  final int? labelIndex;
  final String labelText;
  final Color barColor;
  final Color mutedBarColor;
  final Color gridColor;
  final TextStyle tickStyle;
  final TextStyle calloutStyle;
  final Color calloutColor;

  static const double _axisWidth = 36;
  static const double _topPad = 30;
  static const double _axisBand = 22;
  static const double _gap = 2;
  static const double _maxBar = 24;

  static Rect plotRect(Size size) =>
      Rect.fromLTRB(0, _topPad, size.width - _axisWidth, size.height - _axisBand);

  static int? indexAt(Offset position, Size size, int count) {
    final plot = plotRect(size);
    if (position.dx < plot.left || position.dx > plot.right) return null;
    return ((position.dx - plot.left) / plot.width * count).floor().clamp(0, count - 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = plotRect(size);
    _paintGrid(canvas, plot);

    final slot = plot.width / values.length;
    final barWidth = (slot - _gap).clamp(3.0, _maxBar);
    final radius = Radius.circular(math.min(4, barWidth / 2));
    final paint = Paint();
    Rect? labelledBar;

    for (var index = 0; index < values.length; index++) {
      // Columns grow left to right: each starts a little after the one before.
      final stagger = ((progress - index / values.length * 0.35) / 0.65).clamp(0.0, 1.0);
      final height = plot.height * (values[index] / niceMax) * stagger;
      if (height <= 0) continue;
      final left = plot.left + index * slot + (slot - barWidth) / 2;
      final rect = Rect.fromLTRB(left, plot.bottom - height, left + barWidth, plot.bottom);
      paint.color = solid.contains(index) ? barColor : mutedBarColor;
      canvas.drawRRect(RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius), paint);
      if (index == labelIndex) labelledBar = rect;
    }

    _paintDayLabels(canvas, plot, slot);
    if (labelledBar != null) _paintCallout(canvas, plot, labelledBar);
  }

  void _paintGrid(Canvas canvas, Rect plot) {
    final line = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var step = 0; step <= 2; step++) {
      final value = niceMax * step ~/ 2;
      final y = plot.bottom - plot.height * (value / niceMax);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), line);
      final tick = _layout(_compactMajor(value), tickStyle);
      tick.paint(canvas, Offset(plot.right + 8, y - tick.height / 2));
    }
  }

  void _paintDayLabels(Canvas canvas, Rect plot, double slot) {
    for (var day = 1; day <= values.length; day += 7) {
      final text = _layout('$day', tickStyle);
      final centre = plot.left + (day - 0.5) * slot;
      text.paint(canvas, Offset(centre - text.width / 2, plot.bottom + 7));
    }
  }

  void _paintCallout(Canvas canvas, Rect plot, Rect bar) {
    final text = _layout(labelText, calloutStyle);
    const padX = 7.0;
    const padY = 4.0;
    final width = text.width + padX * 2;
    final height = text.height + padY * 2;
    final left = (bar.center.dx - width / 2).clamp(plot.left, plot.right - width);
    final top = bar.top - height - 8;
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(7),
    );
    canvas.drawRRect(box, Paint()..color = calloutColor);
    text.paint(canvas, Offset(left + padX, top + padY));
  }

  TextPainter _layout(String text, TextStyle style) => TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

  /// Minor units to a short major-unit label: 8800 -> "88", 150000 -> "1.5K".
  String _compactMajor(int minor) {
    final major = minor / minorUnitsPerMajor;
    if (major >= 1000) {
      final thousands = major / 1000;
      final text = thousands.toStringAsFixed(thousands == thousands.roundToDouble() ? 0 : 1);
      return '${text}K';
    }
    return major.round().toString();
  }

  @override
  bool shouldRepaint(_DailyColumnsPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.niceMax != niceMax ||
      oldDelegate.progress != progress ||
      oldDelegate.solid != solid ||
      oldDelegate.labelIndex != labelIndex ||
      oldDelegate.labelText != labelText ||
      oldDelegate.barColor != barColor ||
      oldDelegate.mutedBarColor != mutedBarColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.calloutColor != calloutColor;
}
