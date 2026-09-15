/// The expenses tab: the month's recorded spending, newest first.
///
/// Replaces the old "coming soon" placeholder. It reads [expensesForPeriodProvider] — keyed to the
/// month selected on the dashboard — and renders each expense with its amount, category, date (in
/// the owner's calendar) and, when present, the item line ("12 kg of Sugar"). A header shows the
/// month total; the "Add expense" button opens the form and the list refreshes on return. Empty and
/// error states are explicit rather than a blank screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/api/api.dart';
import '../../../platform/settings.dart';
import '../../../shared/widgets/gradient_action_button.dart';
import '../../../shared_kernel/money.dart';
import 'expense_form_sheet.dart';
import 'expense_providers.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final period = ref.watch(selectedPeriodProvider);
    final page = ref.watch(expensesForPeriodProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.say('ወጪዎች', 'Expenses')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              period.label(settings.language),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(expensesForPeriodProvider),
        child: page.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: error is ApiException
                ? error.message
                : settings.say('ወጪዎችን መጫን አልተቻለም', 'Could not load expenses'),
            onRetry: () => ref.invalidate(expensesForPeriodProvider),
            retryLabel: settings.say('እንደገና ሞክር', 'Retry'),
          ),
          data: (page) => page.items.isEmpty
              ? _EmptyState(settings: settings)
              : _ExpenseList(page: page, settings: settings),
        ),
      ),
      floatingActionButton: GradientActionButton(
        key: const Key('expenses-add'),
        icon: Icons.add_rounded,
        label: settings.say('ወጪ መዝግብ', 'Add expense'),
        onPressed: () => showExpenseForm(context),
      ),
    );
  }
}

class _ExpenseList extends StatelessWidget {
  const _ExpenseList({required this.page, required this.settings});

  final ExpensePageDto page;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      key: const Key('expenses-list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: page.items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  settings.say('${page.total} ወጪዎች', '${page.total} expenses'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  Money(page.totalAmount.minorUnits, page.totalAmount.currency).format(),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          );
        }
        return _ExpenseTile(expense: page.items[index - 1], settings: settings);
      },
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.settings});

  final ExpenseDto expense;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryName = settings.isAmharic
        ? (expense.categoryNameAm ?? expense.categoryName ?? '')
        : (expense.categoryName ?? '');
    final dateLabel = settings.isAmharic
        ? '${expense.spentOn.ethiopianMonthNameAm} · ${expense.spentOn.ethiopian}'
        : expense.spentOn.gregorian;
    final item = expense.item;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(
          categoryName.isEmpty ? settings.say('ወጪ', 'Expense') : categoryName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel, style: theme.textTheme.bodySmall),
            if (item != null)
              Text(
                '${item.quantity} ${item.unitCode ?? ''} · '
                '${settings.isAmharic ? (item.itemNameAm ?? item.itemName ?? '') : (item.itemName ?? '')}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
              ),
            if (expense.note != null && expense.note!.isNotEmpty)
              Text(expense.note!, style: theme.textTheme.bodySmall),
          ],
        ),
        trailing: Text(
          Money(expense.amount.minorUnits, expense.amount.currency).format(),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A ListView so RefreshIndicator still works when empty.
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(
          Icons.receipt_long_outlined,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          settings.say('በዚህ ወር ገና ወጪ የለም።', 'No expenses this month yet.'),
          key: const Key('expenses-empty'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Text(
          settings.say('ከታች ባለው ቁልፍ መዝግብ።', 'Add one with the button below.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry, required this.retryLabel});

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.cloud_off_outlined, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: 12),
        Text(
          message,
          key: const Key('expenses-error'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Center(child: OutlinedButton(onPressed: onRetry, child: Text(retryLabel))),
      ],
    );
  }
}
