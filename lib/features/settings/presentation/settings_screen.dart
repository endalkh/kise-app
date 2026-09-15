/// Personal settings.
///
/// Ordered by consequence: who you are, then the calendar and language that change every screen,
/// then currency and budget. The two big choices are cards rather than segmented buttons — each one
/// shows *today's date in that calendar*, so the effect of the choice is visible before making it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/session/session_controller.dart';
import '../../../platform/settings.dart';
import '../../../platform/theme.dart';
import '../../../shared/widgets/option_card.dart';
import '../../../shared_kernel/ethiopian_date.dart';
import '../../../shared_kernel/money.dart';
import '../../../shared_kernel/period.dart';

const supportedCurrencies = ['ETB', 'USD', 'EUR', 'GBP', 'AED'];
const budgetShortcutsMajor = [5000, 10000, 15000, 25000];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(settings: settings),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileCard(settings: settings),
                const SizedBox(height: 24),
                _CalendarPicker(settings: settings, today: today),
                const SizedBox(height: 24),
                _LanguagePicker(settings: settings),
                const SizedBox(height: 24),
                _ThemePicker(settings: settings),
                const SizedBox(height: 24),
                _CurrencyPicker(settings: settings),
                const SizedBox(height: 24),
                _BudgetPicker(settings: settings),
                const SizedBox(height: 32),
                _SignOutButton(settings: settings),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    settings.say('ኪሴ · ስሪት 0.1', 'Kise · version 0.1'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<KiseColors>()!;
    final onHero = colors.heroForeground;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.heroGradient,
        ),
        // Flat bottom edge: nothing overlaps this header, so it runs straight into the page.
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.say('ማስተካከያ', 'Settings'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: onHero,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                settings.say(
                  'ለውጦች ወዲያውኑ ተቀምጠው ይተገበራሉ።',
                  'Changes save and apply immediately.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onHero.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sign out, at the very end: the one action here that leaves the app rather than adjusting it.
/// Asks once, because a stray tap would drop the person on the login screen.
class _SignOutButton extends ConsumerWidget {
  const _SignOutButton({required this.settings});

  final AppSettings settings;

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.say('ይውጡ?', 'Sign out?')),
        content: Text(settings.say(
          'ወጪዎችዎ ተቀምጠዋል። እንደገና ለማየት መልሰው ይግቡ።',
          'Your expenses stay saved. Sign in again to see them.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(settings.say('ተመለስ', 'Cancel')),
          ),
          FilledButton(
            key: const Key('sign-out-confirm'),
            // The app-wide filled button stretches to full width, which reads oddly in a dialog.
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(settings.say('ውጣ', 'Sign out')),
          ),
        ],
      ),
    );
    if (leave == true) await ref.read(sessionProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: TextButton.icon(
        key: const Key('sign-out'),
        onPressed: () => _confirm(context, ref),
        style: TextButton.styleFrom(
          foregroundColor: scheme.error,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: Text(settings.say('ውጣ', 'Sign out')),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (hint != null)
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerStatefulWidget {
  const _ProfileCard({required this.settings});

  final AppSettings settings;

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.settings.ownerName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = widget.settings.ownerName;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: widget.settings.say('የእርስዎ መረጃ', 'About you')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    key: const Key('profile-initial'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    key: const Key('owner-name-field'),
                    controller: _controller,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: widget.settings.say('ስም', 'Your name'),
                      hintText: widget.settings.say('ለምሳሌ ሰላም', 'e.g. Selam'),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: ref.read(settingsProvider.notifier).setOwnerName,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarPicker extends ConsumerWidget {
  const _CalendarPicker({required this.settings, required this.today});

  final AppSettings settings;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ethiopian = EthiopianDate.fromGregorian(today);
    final gregorianLabel =
        '${gregorianMonthNamesEn[today.month - 1]} ${today.day}, ${today.year}';

    void choose(CalendarKind next) {
      if (next == settings.calendar) return;
      final period = ref.read(selectedPeriodProvider);
      ref.read(settingsProvider.notifier).setCalendar(next);
      // Keep the viewed month pointing at the same stretch of time.
      ref.read(selectedPeriodProvider.notifier).state = period.asCalendar(next);
    }

    return Column(
      key: const Key('calendar-selector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: settings.say('መቁጠሪያ', 'Calendar'),
          hint: settings.say(
            'ሁሉም ቀኖችና ወራት በዚህ መቁጠሪያ ይታያሉ።',
            'Every date and month is shown in this calendar.',
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OptionCard(
                title: settings.say('የኢትዮጵያ', 'Ethiopian'),
                subtitle: ethiopian.format(locale: settings.language.wire),
                icon: Icons.brightness_5_outlined,
                selected: settings.calendar == CalendarKind.ethiopian,
                onTap: () => choose(CalendarKind.ethiopian),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OptionCard(
                title: settings.say('ግሪጎሪያን', 'Gregorian'),
                subtitle: gregorianLabel,
                icon: Icons.public_outlined,
                selected: settings.calendar == CalendarKind.gregorian,
                onTap: () => choose(CalendarKind.gregorian),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PeriodPreview(settings: settings, today: today),
      ],
    );
  }
}

/// Shows how the month will be labelled, in both calendars, before the choice is committed.
class _PeriodPreview extends StatelessWidget {
  const _PeriodPreview({required this.settings, required this.today});

  final AppSettings settings;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final period = Period.fromDate(today, settings.calendar);
    final label = settings.calendar == CalendarKind.ethiopian
        ? EthiopianDate.fromGregorian(today).format(locale: settings.language.wire)
        : '${gregorianMonthNamesEn[today.month - 1]} ${today.day}, ${today.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  key: const Key('settings-preview-date'),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${period.label(settings.language)}  ·  '
                  '${period.counterpartLabel(settings.language)}',
                  key: const Key('settings-preview-period'),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsProvider.notifier);
    return Column(
      key: const Key('language-selector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: settings.say('ቋንቋ', 'Language')),
        Row(
          children: [
            Expanded(
              child: OptionCard(
                title: 'አማርኛ',
                subtitle: 'ሐምሌ · ነሐሴ · ጳጉሜን',
                selected: settings.isAmharic,
                onTap: () => controller.setLanguage(Language.amharic),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OptionCard(
                title: 'English',
                subtitle: 'Hamle · Nehase · Pagumen',
                selected: !settings.isAmharic,
                onTap: () => controller.setLanguage(Language.english),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Four palettes as swatches: each is a small version of its own hero gradient, so the choice is
/// visible before it is made. The whole app fades to the new colours on tap.
class _ThemePicker extends ConsumerWidget {
  const _ThemePicker({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsProvider.notifier);
    return Column(
      key: const Key('theme-selector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: settings.say('ገጽታ', 'Appearance'),
          hint: settings.say('የመተግበሪያው ቀለም።', 'The colour of the app.'),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
            child: Row(
              children: [
                for (final option in AppTheme.values)
                  Expanded(
                    child: _ThemeSwatch(
                      option: option,
                      selected: settings.theme == option,
                      label: option.name(settings.isAmharic),
                      onTap: () => controller.setTheme(option),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<AppThemeMode>(
          key: const Key('theme-mode-selector'),
          showSelectedIcon: false,
          segments: [
            for (final mode in AppThemeMode.values)
              ButtonSegment<AppThemeMode>(
                value: mode,
                icon: Icon(switch (mode) {
                  AppThemeMode.system => Icons.brightness_auto_outlined,
                  AppThemeMode.light => Icons.light_mode_outlined,
                  AppThemeMode.dark => Icons.dark_mode_outlined,
                }),
                label: Text(mode.name(settings.isAmharic)),
              ),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (selection) => controller.setThemeMode(selection.first),
        ),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.option,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final AppTheme option;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gradient = option.heroGradient(theme.brightness);

    return InkWell(
      key: Key('theme-option-${option.wire}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                border: Border.all(
                  color: selected ? scheme.onSurface : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: gradient.last.withValues(alpha: 0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : const [],
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 26)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyPicker extends ConsumerWidget {
  const _CurrencyPicker({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsProvider.notifier);
    return Column(
      key: const Key('currency-selector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: settings.say('ገንዘብ', 'Currency')),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final code in supportedCurrencies)
              ChoiceChipPill(
                label: code,
                selected: settings.currency == code,
                onTap: () => controller.setCurrency(code),
              ),
          ],
        ),
      ],
    );
  }
}

class _BudgetPicker extends ConsumerStatefulWidget {
  const _BudgetPicker({required this.settings});

  final AppSettings settings;

  @override
  ConsumerState<_BudgetPicker> createState() => _BudgetPickerState();
}

class _BudgetPickerState extends ConsumerState<_BudgetPicker> {
  late final TextEditingController _field = TextEditingController(
    text: widget.settings.hasBudget
        ? widget.settings.monthlyBudget.majorUnits.round().toString()
        : '',
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _apply(String text) {
    final controller = ref.read(settingsProvider.notifier);
    final major = double.tryParse(text);
    if (major == null || major <= 0) {
      controller.clearBudget();
      return;
    }
    controller.setMonthlyBudgetMinor(
      Money.fromMajor(major, widget.settings.currency).minorUnits,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: settings.say('የወሩ ገደብ', 'Monthly budget'),
          hint: settings.say(
            'ካልፈለጉ ባዶ ይተዉት፤ ማጠቃለያው ላይ አይታይም።',
            'Leave it empty and the summary will not show a target.',
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final amount in budgetShortcutsMajor)
              ChoiceChipPill(
                label: Money.fromMajor(amount, settings.currency)
                    .formatRounded(withCurrency: false),
                selected: settings.monthlyBudgetMinor ==
                    Money.fromMajor(amount, settings.currency).minorUnits,
                onTap: () {
                  _field.text = amount.toString();
                  _apply(_field.text);
                },
              ),
            if (settings.hasBudget)
              ChoiceChipPill(
                label: settings.say('አጥፋ', 'Clear'),
                selected: false,
                onTap: () {
                  _field.clear();
                  ref.read(settingsProvider.notifier).clearBudget();
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('budget-field'),
          controller: _field,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(
            labelText: settings.say('የራስዎ ገደብ', 'Custom amount'),
            prefixIcon: const Icon(Icons.savings_outlined),
            suffixText: settings.currency,
          ),
          onChanged: _apply,
        ),
        if (settings.hasBudget) ...[
          const SizedBox(height: 8),
          Text(
            settings.say(
              'ገደብ: ${settings.monthlyBudget.formatRounded()}',
              'Budget: ${settings.monthlyBudget.formatRounded()}',
            ),
            key: const Key('budget-summary'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
