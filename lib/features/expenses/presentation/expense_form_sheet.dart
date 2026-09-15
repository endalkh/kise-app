/// The expense entry form.
///
/// Presented as a modal bottom sheet from the dashboard's "Add expense" button and the expenses tab.
/// It captures what a person actually needs to record a spend:
///
/// * **amount** in major units (birr), converted to minor (santim) on submit;
/// * **category** — a required picker from the owner's categories;
/// * **date** — defaults to today, entered in the owner's calendar (the form sends the Gregorian
///   value with the calendar tag, and the backend keeps Gregorian canonical);
/// * **payment method** and an optional **note**;
/// * an optional **item line** — toggle it on to also record *what* was bought: an existing item or
///   a new name, a quantity, and the unit it is counted in. This is what feeds the month-end usage
///   report.
///
/// On success it invalidates the list + item providers so the new expense appears, and pops.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/api/api.dart';
import '../../../platform/settings.dart';
import '../../../shared_kernel/money.dart';
import 'expense_providers.dart';

/// Show the form as a modal sheet. Returns true when an expense was recorded.
Future<bool?> showExpenseForm(BuildContext context) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const ExpenseFormSheet(),
    );

class ExpenseFormSheet extends ConsumerStatefulWidget {
  const ExpenseFormSheet({super.key});

  @override
  ConsumerState<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _itemName = TextEditingController();
  final _quantity = TextEditingController();

  String? _categoryId;
  String _paymentMethod = 'cash';
  DateTime _date = DateTime.now();
  bool _trackItem = false;
  String? _unitId;
  bool _submitting = false;
  String? _submitError;

  static const _paymentMethods = ['cash', 'telebirr', 'bank', 'card', 'other'];

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _itemName.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _submitError = ref.read(settingsProvider).say(
            'ምድብ ይምረጡ', 'Choose a category'));
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final settings = ref.read(settingsProvider);
    final amountMinor = Money.fromMajor(
      num.tryParse(_amount.text.trim()) ?? 0,
      settings.currency,
    ).minorUnits;
    final date =
        '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
    try {
      await ref.read(expensesApiProvider).record(
            categoryId: _categoryId!,
            amountMinor: amountMinor,
            date: date,
            // The date picker returns a Gregorian date, so tag it gregorian regardless of the
            // owner's display calendar — the backend renders both calendars back.
            dateCalendar: 'gregorian',
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            paymentMethod: _paymentMethod,
            itemName: _trackItem && _itemName.text.trim().isNotEmpty
                ? _itemName.text.trim()
                : null,
            quantity: _trackItem && _quantity.text.trim().isNotEmpty
                ? _quantity.text.trim()
                : null,
            unitId: _trackItem ? _unitId : null,
          );
      // Refresh the list and the item suggestions so the new expense (and any new item) appears.
      ref.invalidate(expensesForPeriodProvider);
      ref.invalidate(itemsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() => _submitError = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + viewInsets),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                settings.say('ወጪ መዝግብ', 'Record an expense'),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('expense-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: settings.say('መጠን', 'Amount'),
                  suffixText: settings.currency,
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                validator: (v) {
                  final value = num.tryParse((v ?? '').trim());
                  if (value == null || value <= 0) {
                    return settings.say('ትክክለኛ መጠን ያስገቡ', 'Enter a valid amount');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              categories.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(
                  settings.say('ምድቦችን መጫን አልተቻለም', 'Could not load categories'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                data: (list) => DropdownButtonFormField<String>(
                  key: const Key('expense-category'),
                  initialValue: _categoryId,
                  decoration: InputDecoration(
                    labelText: settings.say('ምድብ', 'Category'),
                    prefixIcon: const Icon(Icons.category_outlined),
                  ),
                  items: [
                    for (final c in list)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(settings.isAmharic ? (c.nameAm ?? c.name) : c.name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ),
              const SizedBox(height: 14),
              _DateField(
                date: _date,
                label: settings.say('ቀን', 'Date'),
                onPick: (picked) => setState(() => _date = picked),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: const Key('expense-payment'),
                initialValue: _paymentMethod,
                decoration: InputDecoration(
                  labelText: settings.say('የክፍያ ዘዴ', 'Payment method'),
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                ),
                items: [
                  for (final m in _paymentMethods)
                    DropdownMenuItem(value: m, child: Text(_paymentLabel(m, settings))),
                ],
                onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('expense-note'),
                controller: _note,
                decoration: InputDecoration(
                  labelText: settings.say('ማስታወሻ (አማራጭ)', 'Note (optional)'),
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('expense-track-item'),
                contentPadding: EdgeInsets.zero,
                title: Text(settings.say('ዕቃ መዝግብ', 'Track an item')),
                subtitle: Text(
                  settings.say(
                    'ምን ያህል ኪሎ/ሊትር እንደገዙ ይመዝግቡ',
                    'Record how much (kg, litre…) you bought',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                value: _trackItem,
                onChanged: (v) => setState(() => _trackItem = v),
              ),
              if (_trackItem) _buildItemLine(settings, theme),
              if (_submitError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _submitError!,
                  key: const Key('expense-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('expense-submit'),
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(settings.say('መዝግብ', 'Save expense')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemLine(AppSettings settings, ThemeData theme) {
    final units = ref.watch(unitsProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('expense-item-name'),
            controller: _itemName,
            decoration: InputDecoration(
              labelText: settings.say('የዕቃ ስም', 'Item name'),
              hintText: settings.say('ለምሳሌ ስኳር', 'e.g. Sugar'),
              prefixIcon: const Icon(Icons.shopping_basket_outlined),
            ),
            validator: (v) {
              if (_trackItem && (v == null || v.trim().isEmpty)) {
                return settings.say('የዕቃ ስም ያስፈልጋል', 'Item name is required');
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('expense-quantity'),
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: settings.say('ብዛት', 'Quantity'),
                  ),
                  validator: (v) {
                    if (!_trackItem) return null;
                    final value = num.tryParse((v ?? '').trim());
                    if (value == null || value <= 0) {
                      return settings.say('ብዛት ያስገቡ', 'Enter a quantity');
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: units.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, _) => Text(
                    settings.say('ክፍሎችን መጫን አልተቻለም', 'Could not load units'),
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  ),
                  data: (list) => DropdownButtonFormField<String>(
                    key: const Key('expense-unit'),
                    initialValue: _unitId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: settings.say('ክፍል', 'Unit')),
                    items: [
                      for (final u in list)
                        DropdownMenuItem(
                          value: u.id,
                          child: Text('${u.code} · ${settings.isAmharic ? (u.nameAm ?? u.name) : u.name}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _unitId = v),
                    validator: (v) => (_trackItem && v == null)
                        ? settings.say('ክፍል ይምረጡ', 'Pick a unit')
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _paymentLabel(String method, AppSettings settings) => switch (method) {
        'cash' => settings.say('ጥሬ ገንዘብ', 'Cash'),
        'telebirr' => 'Telebirr',
        'bank' => settings.say('ባንክ', 'Bank'),
        'card' => settings.say('ካርድ', 'Card'),
        _ => settings.say('ሌላ', 'Other'),
      };
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.label, required this.onPick});

  final DateTime date;
  final String label;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final text =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return InkWell(
      key: const Key('expense-date'),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(text),
      ),
    );
  }
}
