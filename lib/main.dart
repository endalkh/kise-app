import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_shell.dart';
import 'features/auth/presentation/sign_in_screen.dart';
import 'platform/preferences_store.dart';
import 'platform/session/session_controller.dart';
import 'platform/settings.dart';
import 'platform/theme.dart';

Future<void> main() async {
  // Required before touching any plugin: SharedPreferences goes over a platform channel, and the
  // channel does not exist until the binding is up. Without this the app shows a white screen.
  WidgetsFlutterBinding.ensureInitialized();

  // Settings are read before the first frame, so the app never flickers from one calendar to the
  // other on launch.
  final store = await PreferencesSettingsStore.open();
  runApp(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        // The API base URL is not overridden here on purpose: apiConfigProvider reads it from
        // KISE_API_URL (a --dart-define), so a physical device can be pointed at the Mac's LAN IP
        // at run time without editing source. See platform/api/providers.dart.
      ],
      child: const KiseApp(),
    ),
  );
}

class KiseApp extends ConsumerWidget {
  const KiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final palette = ref.watch(appThemeProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Kise',
      debugShowCheckedModeBanner: false,
      // MaterialApp animates between themes, so picking a palette in Settings fades the whole app
      // to the new colours rather than snapping.
      theme: buildTheme(theme: palette),
      darkTheme: buildTheme(theme: palette, brightness: Brightness.dark),
      themeMode: themeMode.material,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('am'), Locale('en')],
      locale: Locale(language.wire),
      home: const SessionGate(),
    );
  }
}

/// Chooses what to show based on the auth session: a splash while checking storage, the sign-in
/// screen when signed out, and the app itself once signed in.
class SessionGate extends ConsumerWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return session.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      // A transport error at boot (backend unreachable) should still let the person try to sign in.
      error: (_, __) => const SignInScreen(),
      data: (state) => switch (state) {
        SessionUnknown() =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
        SignedOut() => const SignInScreen(),
        SignedIn() => const AppShell(),
      },
    );
  }
}
