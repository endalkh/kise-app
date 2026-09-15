/// A large, tappable choice card.
///
/// Used for the calendar and language pickers. A segmented button is compact but tiny: on a phone
/// the two most consequential settings in Kise deserve a target you can hit without aiming, and
/// room to show what the choice actually does.
library;

import 'package:flutter/material.dart';

class OptionCard extends StatelessWidget {
  const OptionCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String title;
  final String subtitle;

  /// Optional leading icon. When null, only the selection indicator is shown — the language picker
  /// omits it, since a generic translate/abc icon adds nothing next to "አማርኛ" / "English".
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null)
                    Icon(
                      icon,
                      size: 20,
                      color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                    ),
                  const Spacer(),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    size: 18,
                    color: selected ? scheme.primary : scheme.outlineVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small selectable pill, for currency and budget shortcuts.
class ChoiceChipPill extends StatelessWidget {
  const ChoiceChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
