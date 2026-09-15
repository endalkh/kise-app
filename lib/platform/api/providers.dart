/// Riverpod wiring for the API client, so a feature reads `ref.watch(expensesApiProvider)` and gets
/// a data source backed by the one configured client — base URL, token interceptor and all.
///
/// [apiConfigProvider] and [authTokenStoreProvider] are the two seams a host app overrides: point
/// the base URL at the right environment in `main()` via a `ProviderScope(overrides: [...])`, and
/// swap the token store for an in-memory one in a test. Everything else derives from them.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'auth_token_store.dart';
import 'resources/auth_api.dart';
import 'resources/categories_api.dart';
import 'resources/expenses_api.dart';
import 'resources/items_api.dart';
import 'resources/reports_api.dart';
import 'resources/units_api.dart';

/// The backend base URL.
///
/// Set it at build/run time with `--dart-define=KISE_API_URL=...`, which is how a physical device
/// reaches the backend on the developer's machine (a phone cannot use `localhost` or the Android
/// emulator's `10.0.2.2`; it needs the Mac's LAN IP, e.g. `http://192.168.1.4:27707`).
///
/// The default is the Android emulator's host alias, which is the common case when no define is
/// passed. A test or `main()` can still override this provider directly.
const _defaultApiUrl = String.fromEnvironment(
  'KISE_API_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

final apiConfigProvider = Provider<ApiConfig>(
  (ref) => const ApiConfig(baseUrl: _defaultApiUrl),
);

final authTokenStoreProvider = Provider<AuthTokenStore>(
  (ref) => SecureAuthTokenStore(),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    config: ref.watch(apiConfigProvider),
    tokenStore: ref.watch(authTokenStoreProvider),
  ),
);

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider), ref.watch(authTokenStoreProvider)),
);

final categoriesApiProvider = Provider<CategoriesApi>(
  (ref) => CategoriesApi(ref.watch(apiClientProvider)),
);

final expensesApiProvider = Provider<ExpensesApi>(
  (ref) => ExpensesApi(ref.watch(apiClientProvider)),
);

final unitsApiProvider = Provider<UnitsApi>(
  (ref) => UnitsApi(ref.watch(apiClientProvider)),
);

final itemsApiProvider = Provider<ItemsApi>(
  (ref) => ItemsApi(ref.watch(apiClientProvider)),
);

final itemUsageReportsApiProvider = Provider<ItemUsageReportsApi>(
  (ref) => ItemUsageReportsApi(ref.watch(apiClientProvider)),
);
