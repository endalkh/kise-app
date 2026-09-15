/// Sign in, or create an account — the gate to everything else.
///
/// The palette's hero gradient fills the screen, the coin sits on it with the name and a one-line
/// promise, and the form lives in a sheet that rises from the bottom (or floats, on a wide window).
/// Signing in needs email + password; registering also needs a display name and adopts the
/// calendar/language the person has already chosen in Settings, so their first expense is in the
/// calendar they think in. Errors from the API (a wrong password, an email already taken) surface
/// inline via the [SessionController]'s async state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/api/api.dart';
import '../../../platform/session/session_controller.dart';
import '../../../platform/settings.dart';
import '../../../platform/theme.dart';
import '../../../shared/widgets/kise_logo.dart';
import '../../../shared/widgets/reveal.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  bool _registering = false;
  bool _showPassword = false;

  /// Past this width the sheet floats as a card instead of rising from the bottom edge.
  static const double _wideBreakpoint = 640;
  static const double _sheetWidth = 460;
  static const Duration _motion = Duration(milliseconds: 260);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final settings = ref.read(settingsProvider);
    final controller = ref.read(sessionProvider.notifier);
    if (_registering) {
      await controller.register(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _displayName.text.trim(),
        calendar: settings.calendar.wire,
        language: settings.language.wire,
        currency: settings.currency,
      );
    } else {
      await controller.signIn(email: _email.text.trim(), password: _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = theme.extension<KiseColors>()!.heroGradient;
    final session = ref.watch(sessionProvider);
    final busy = session.isLoading;

    return Scaffold(
      backgroundColor: gradient.first,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > _wideBreakpoint;
            final sheet = Reveal(
              order: 2,
              child: _Sheet(
                floating: wide,
                child: _form(context, busy: busy, error: session.error),
              ),
            );
            // Min-height + IntrinsicHeight lets the sheet stretch to the bottom edge when the form
            // is short, yet scroll when the keyboard takes the lower half of the screen.
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment:
                        wide ? MainAxisAlignment.center : MainAxisAlignment.start,
                    children: [
                      Reveal(child: _Brand(settings: ref.watch(settingsProvider))),
                      if (wide)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: _sheetWidth),
                            child: sheet,
                          ),
                        )
                      else
                        Expanded(child: sheet),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _form(BuildContext context, {required bool busy, required Object? error}) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _registering
                ? settings.say('አዲስ መለያ ይክፈቱ', 'Create your account')
                : settings.say('እንኳን ደህና መጡ', 'Welcome back'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _registering
                ? settings.say('ጥቂት ሰከንዶች ብቻ ይወስዳል', 'It only takes a moment')
                : settings.say('ለመቀጠል ይግቡ', 'Sign in to continue'),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          AnimatedSize(
            duration: _motion,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _registering
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextFormField(
                      key: const Key('signin-name'),
                      controller: _displayName,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration(
                        theme,
                        label: settings.say('ስም', 'Name'),
                        icon: Icons.person_outline_rounded,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? settings.say('ስም ያስፈልጋል', 'Name is required')
                          : null,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          TextFormField(
            key: const Key('signin-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: _decoration(
              theme,
              label: settings.say('ኢሜይል', 'Email'),
              icon: Icons.mail_outline_rounded,
            ),
            validator: (v) => (v == null || !v.contains('@'))
                ? settings.say('ትክክለኛ ኢሜይል ያስገቡ', 'Enter a valid email')
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('signin-password'),
            controller: _password,
            obscureText: !_showPassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: _decoration(
              theme,
              label: settings.say('የይለፍ ቃል', 'Password'),
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                key: const Key('signin-show-password'),
                tooltip: _showPassword
                    ? settings.say('የይለፍ ቃል ሰውር', 'Hide password')
                    : settings.say('የይለፍ ቃል አሳይ', 'Show password'),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            validator: (v) => (v == null || v.length < 8)
                ? settings.say('ቢያንስ 8 ፊደላት', 'At least 8 characters')
                : null,
          ),
          AnimatedSize(
            duration: _motion,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: error is ApiException
                ? _ErrorNote(message: error.message)
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('signin-submit'),
            onPressed: busy ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: AnimatedSwitcher(
              duration: _motion,
              child: busy
                  ? const SizedBox(
                      key: ValueKey('busy'),
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(
                      _registering
                          ? settings.say('መለያ ክፈት', 'Create account')
                          : settings.say('ግባ', 'Sign in'),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _registering
                    ? settings.say('መለያ አለዎት?', 'Have an account?')
                    : settings.say('መለያ የለዎትም?', 'No account yet?'),
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              TextButton(
                key: const Key('signin-toggle'),
                onPressed: busy ? null : () => setState(() => _registering = !_registering),
                child: Text(
                  _registering
                      ? settings.say('ይግቡ', 'Sign in')
                      : settings.say('ይክፈቱ', 'Create one'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Soft filled fields with no resting outline; the outline appears only on focus or error, so
  /// the sheet reads as a few calm shapes rather than a grid of boxes.
  InputDecoration _decoration(
    ThemeData theme, {
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: width == 0 ? BorderSide.none : BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
      border: border(Colors.transparent, 0),
      enabledBorder: border(Colors.transparent, 0),
      focusedBorder: border(scheme.primary, 1.6),
      errorBorder: border(scheme.error, 1.2),
      focusedErrorBorder: border(scheme.error, 1.6),
    );
  }
}

/// The coin, the name and a one-line promise on the gradient.
class _Brand extends StatelessWidget {
  const _Brand({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onHero = theme.extension<KiseColors>()!.heroForeground;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 44, 24, 36),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onHero.withValues(alpha: 0.14),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: KiseLogo(size: 68),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              settings.say('ኪሴ', 'Kise'),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: onHero,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              settings.say('ገንዘብዎን በራስዎ የቀን መቁጠሪያ ይከታተሉ', 'Your money, in your own calendar'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: onHero.withValues(alpha: 0.84)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card the form sits in. Rises from the bottom edge on phones; floats with all four corners
/// rounded on a wide window.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.floating, required this.child});

  final bool floating;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const radius = Radius.circular(28);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: floating
            ? const BorderRadius.all(radius)
            : const BorderRadius.vertical(top: radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _SignInScreenState._sheetWidth),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// An API error, inline under the fields, in the palette's error tint.
class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                key: const Key('signin-error'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
