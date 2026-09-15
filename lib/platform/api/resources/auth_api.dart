/// Auth data source: register, login, and the signed-in profile.
///
/// DTOs are the wire shape, and they never leave `infrastructure/` — a screen sees a domain type,
/// mapped from these. Here they are kept deliberately small: enough to round-trip the API's JSON and
/// hand back typed values. The data source owns the token side effect: on register and login it
/// writes the returned token to the [AuthTokenStore], so a subsequent request is authenticated with
/// no extra step.
library;

import '../api_client.dart';
import '../auth_token_store.dart';

class ProfileDto {
  const ProfileDto({
    required this.id,
    required this.email,
    required this.displayName,
    required this.calendar,
    required this.language,
    required this.currency,
    required this.registeredAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String calendar;
  final String language;
  final String currency;
  final String registeredAt;

  factory ProfileDto.fromJson(Map<String, Object?> json) => ProfileDto(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String,
        calendar: json['calendar'] as String,
        language: json['language'] as String,
        currency: json['currency'] as String,
        registeredAt: json['registered_at'] as String,
      );
}

class AuthResultDto {
  const AuthResultDto({
    required this.token,
    required this.expiresAt,
    required this.owner,
  });

  final String token;
  final String expiresAt;
  final ProfileDto owner;

  factory AuthResultDto.fromJson(Map<String, Object?> json) => AuthResultDto(
        token: json['token'] as String,
        expiresAt: json['expires_at'] as String,
        owner: ProfileDto.fromJson((json['owner'] as Map).cast<String, Object?>()),
      );
}

class AuthApi {
  AuthApi(this._client, this._tokenStore);

  final ApiClient _client;
  final AuthTokenStore _tokenStore;

  Future<AuthResultDto> register({
    required String email,
    required String password,
    required String displayName,
    String? calendar,
    String? language,
    String? currency,
  }) async {
    final data = await _client.post('/api/auth/register', body: {
      'email': email,
      'password': password,
      'display_name': displayName,
      if (calendar != null) 'calendar': calendar,
      if (language != null) 'language': language,
      if (currency != null) 'currency': currency,
    });
    final result = AuthResultDto.fromJson((data as Map).cast<String, Object?>());
    await _tokenStore.write(result.token);
    return result;
  }

  Future<AuthResultDto> login({required String email, required String password}) async {
    final data = await _client.post('/api/auth/login', body: {
      'email': email,
      'password': password,
    });
    final result = AuthResultDto.fromJson((data as Map).cast<String, Object?>());
    await _tokenStore.write(result.token);
    return result;
  }

  Future<ProfileDto> me() async {
    final data = await _client.get('/api/auth/me');
    return ProfileDto.fromJson((data as Map).cast<String, Object?>());
  }

  Future<ProfileDto> updateMe({String? displayName, String? calendar, String? language}) async {
    final data = await _client.patch('/api/auth/me', body: {
      if (displayName != null) 'display_name': displayName,
      if (calendar != null) 'calendar': calendar,
      if (language != null) 'language': language,
    });
    return ProfileDto.fromJson((data as Map).cast<String, Object?>());
  }

  /// Forget the token. The next request goes out unauthenticated.
  Future<void> signOut() => _tokenStore.clear();
}
