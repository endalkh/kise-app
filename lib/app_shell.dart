/// The shell that holds the app's tabs.
///
/// `IndexedStack` rather than swapping widgets, so the dashboard keeps its scroll position and the
/// selected month when the person visits Settings and comes back.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/expenses/presentation/expenses_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'platform/settings.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          ExpensesScreen(),
          _ComingSoon(tab: 'fixed'),
          SettingsScreen(),
        ],
      ),
      // Flat, with a hairline above it: the headers carry the curves, the bar stays out of the way.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: settings.say('ማጠቃለያ', 'Summary'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: settings.say('ወጪዎች', 'Expenses'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.event_repeat_outlined),
              selectedIcon: const Icon(Icons.event_repeat),
              label: settings.say('ቋሚ ወጪ', 'Fixed'),
            ),
            NavigationDestination(
              key: const Key('settings-tab'),
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: settings.say('ማስተካከያ', 'Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A placeholder that says what is coming rather than pretending to be empty.
class _ComingSoon extends ConsumerWidget {
  const _ComingSoon({required this.tab});

  final String tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final (title, body) = switch (tab) {
      'expenses' => (
        settings.say('ወጪዎች', 'Expenses'),
        settings.say(
          'የተመዘገቡ ወጪዎች ዝርዝር በዚህ ይታያል።',
          'Your recorded expenses will be listed here.',
        ),
      ),
      _ => (
        settings.say('ቋሚ ወርሃዊ ወጪ', 'Fixed monthly expenses'),
        settings.say(
          'ቤት ኪራይ፣ ኢንተርኔት እና ሌሎች ወርሃዊ ክፍያዎች።',
          'Rent, internet and other monthly commitments.',
        ),
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hourglass_empty_outlined,
                size: 44,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
