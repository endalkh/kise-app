/// The reusable API client, exported from one place.
///
/// A feature imports `package:kise/platform/api/api.dart` and gets the client, the exception type,
/// the token store and every resource data source — nothing else to remember.
library;

export 'api_client.dart';
export 'api_exception.dart';
export 'auth_token_store.dart';
export 'providers.dart';
export 'resources/auth_api.dart';
export 'resources/categories_api.dart';
export 'resources/expenses_api.dart';
export 'resources/items_api.dart';
export 'resources/reports_api.dart';
export 'resources/units_api.dart';
