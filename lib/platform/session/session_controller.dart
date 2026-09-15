/// The auth session: who is signed in, and the token that proves it.
///
/// The app cannot talk to the backend without a bearer token, so this is the gate everything else
/// sits behind. On boot it asks the [AuthTokenStore] whether a token is already saved (from a
/// previous run) and, if so, fetches the profile to confirm it is still valid. Signing in or
/// registering stores the token via the [AuthApi] (which writes it to the store) and flips the state
/// to authenticated; signing out clears it.
///
/// State is a small sealed-ish set of cases the UI switches on: unknown (still checking storage),
/// signedOut, and signedIn(profile).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';

/// The three states the session can be in.
sealed class SessionState {
  const SessionState();
}

/// Still checking whether a token is saved — show a splash, not a login form.
class SessionUnknown extends SessionState {
  const SessionUnknown();
}

class SignedOut extends SessionState {
  const SignedOut();
}

class SignedIn extends SessionState {
  const SignedIn(this.profile);

  final ProfileDto profile;
}

class SessionController extends AsyncNotifier<SessionState> {
  AuthApi get _auth => ref.read(authApiProvider);

  @override
  Future<SessionState> build() async {
    // A token from a previous run means we might already be signed in — confirm by fetching the
    // profile. A stale/rejected token just drops us to signed-out.
    final token = await ref.read(authTokenStoreProvider).read();
    if (token == null || token.isEmpty) {
      return const SignedOut();
    }
    try {
      final profile = await _auth.me();
      return SignedIn(profile);
    } on ApiException {
      await _auth.signOut();
      return const SignedOut();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await _auth.login(email: email, password: password);
      return SignedIn(result.owner);
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    String? calendar,
    String? language,
    String? currency,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await _auth.register(
        email: email,
        password: password,
        displayName: displayName,
        calendar: calendar,
        language: language,
        currency: currency,
      );
      return SignedIn(result.owner);
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AsyncData(SignedOut());
  }
}

final sessionProvider =
    AsyncNotifierProvider<SessionController, SessionState>(SessionController.new);
