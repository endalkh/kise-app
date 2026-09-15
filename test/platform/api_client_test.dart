/// Tests for the reusable API client.
///
/// No network and no extra package: a [_FakeAdapter] implements Dio's one-method [HttpClientAdapter]
/// interface and returns canned JSON, recording the request it saw. That is enough to prove the
/// three things the client promises — the bearer token is attached from the store, the wire JSON
/// round-trips into DTOs, and every failure surfaces as a typed [ApiException].
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kise/platform/api/api.dart';

/// A Dio adapter that returns a scripted response and remembers the last request options.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.statusCode, required this.body});

  int statusCode;
  Object? body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final payload = body == null ? '' : jsonEncode(body);
    return ResponseBody.fromString(
      payload,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _clientWith(
  _FakeAdapter adapter, {
  AuthTokenStore? tokenStore,
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ApiClient(
    config: const ApiConfig(baseUrl: 'http://test.local'),
    tokenStore: tokenStore ?? InMemoryAuthTokenStore(),
    dio: dio,
  );
}

void main() {
  group('token interceptor', () {
    test('attaches the stored bearer token to a request', () async {
      final adapter = _FakeAdapter(statusCode: 200, body: <Object?>[]);
      final client = _clientWith(
        adapter,
        tokenStore: InMemoryAuthTokenStore('a-token'),
      );

      await client.get('/api/categories');

      expect(adapter.lastRequest!.headers['Authorization'], 'Bearer a-token');
    });

    test('sends no Authorization header when there is no token', () async {
      final adapter = _FakeAdapter(statusCode: 200, body: <Object?>[]);
      final client = _clientWith(adapter);

      await client.get('/api/categories');

      expect(adapter.lastRequest!.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('error mapping', () {
    test('a 401 with the domain body becomes a typed ApiException', () async {
      final adapter = _FakeAdapter(
        statusCode: 401,
        body: {
          'code': 'invalid_credentials',
          'message': 'Email or password is incorrect',
          'detail': <String, Object?>{},
        },
      );
      final client = _clientWith(adapter);

      expect(
        () => client.post('/api/auth/login', body: {}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'invalid_credentials')
              .having((e) => e.statusCode, 'status', 401)
              .having((e) => e.isUnauthorized, 'isUnauthorized', true),
        ),
      );
    });

    test('a 409 keeps its code and detail', () async {
      final adapter = _FakeAdapter(
        statusCode: 409,
        body: {
          'code': 'category_name_taken',
          'message': "A category named 'Food' already exists",
          'detail': {'name': 'Food'},
        },
      );
      final client = _clientWith(adapter);

      try {
        await client.post('/api/categories', body: {'name': 'Food'});
        fail('expected an ApiException');
      } on ApiException catch (error) {
        expect(error.isConflict, isTrue);
        expect(error.code, 'category_name_taken');
        expect(error.detail['name'], 'Food');
      }
    });

    test('a connection failure becomes a network ApiException', () async {
      final dio = Dio()
        ..httpClientAdapter = _ThrowingAdapter();
      final client = ApiClient(
        config: const ApiConfig(baseUrl: 'http://test.local'),
        tokenStore: InMemoryAuthTokenStore(),
        dio: dio,
      );

      await expectLater(
        client.get('/api/categories'),
        throwsA(isA<ApiException>().having((e) => e.isNetworkError, 'network', true)),
      );
    });
  });

  group('auth data source', () {
    test('register round-trips the DTO and stores the token', () async {
      final adapter = _FakeAdapter(
        statusCode: 201,
        body: {
          'token': 'issued-token',
          'expires_at': '2026-09-12T00:00:00+00:00',
          'owner': {
            'id': 'abc',
            'email': 'abebe@example.com',
            'display_name': 'Abebe',
            'calendar': 'ethiopian',
            'language': 'am',
            'currency': 'ETB',
            'registered_at': '2026-09-05T00:00:00+00:00',
          },
        },
      );
      final store = InMemoryAuthTokenStore();
      final api = AuthApi(_clientWith(adapter, tokenStore: store), store);

      final result = await api.register(
        email: 'abebe@example.com',
        password: 'correct horse battery',
        displayName: 'Abebe',
      );

      expect(result.token, 'issued-token');
      expect(result.owner.email, 'abebe@example.com');
      expect(result.owner.calendar, 'ethiopian');
      // The side effect: the token is now in the store for the next request.
      expect(await store.read(), 'issued-token');
    });

    test('signOut clears the token', () async {
      final store = InMemoryAuthTokenStore('something');
      final adapter = _FakeAdapter(statusCode: 200, body: {});
      final api = AuthApi(_clientWith(adapter, tokenStore: store), store);

      await api.signOut();

      expect(await store.read(), isNull);
    });
  });

  group('expenses data source', () {
    test('decodes money as minor units and a dual-calendar date', () async {
      final adapter = _FakeAdapter(
        statusCode: 201,
        body: {
          'id': 'exp-1',
          'category_id': 'cat-1',
          'amount': {'amount_minor': 12500, 'currency': 'ETB'},
          'spent_on': {
            'gregorian': '2026-07-22',
            'ethiopian': '2018-11-15',
            'ethiopian_month_name_am': 'ሐምሌ',
            'ethiopian_month_name_en': 'Hamle',
            'ethiopian_month': 11,
            'entered_in': 'ethiopian',
          },
          'note': 'airport',
          'payment_method': 'cash',
          'category_name': 'Taxi',
          'category_name_am': 'ታክሲ',
        },
      );
      final api = ExpensesApi(_clientWith(adapter));

      final expense = await api.record(
        categoryId: 'cat-1',
        amountMinor: 12500,
        date: '2018-11-15',
        dateCalendar: 'ethiopian',
      );

      expect(expense.amount.minorUnits, 12500);
      expect(expense.amount.currency, 'ETB');
      expect(expense.spentOn.enteredIn, 'ethiopian');
      expect(expense.spentOn.ethiopianMonthNameAm, 'ሐምሌ');
      expect(expense.categoryName, 'Taxi');

      // The request sent the calendar-tagged date the server expects.
      final sent = (adapter.lastRequest!.data as Map).cast<String, Object?>();
      expect((sent['spent_on'] as Map)['calendar'], 'ethiopian');
    });

    test('a page decodes items and the total amount', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        body: {
          'items': [
            {
              'id': 'exp-1',
              'category_id': 'cat-1',
              'amount': {'amount_minor': 5000, 'currency': 'ETB'},
              'spent_on': {
                'gregorian': '2026-09-04',
                'ethiopian': '2018-12-29',
                'ethiopian_month_name_am': 'ነሐሴ',
                'ethiopian_month_name_en': 'Nehase',
                'entered_in': 'gregorian',
              },
              'note': null,
              'payment_method': 'cash',
              'category_name': 'Food',
              'category_name_am': 'ምግብ',
            },
          ],
          'total': 1,
          'limit': 50,
          'offset': 0,
          'total_amount': {'amount_minor': 5000, 'currency': 'ETB'},
        },
      );
      final api = ExpensesApi(_clientWith(adapter));

      final page = await api.list(periodYear: 2018, periodMonth: 12);

      expect(page.total, 1);
      expect(page.items.single.id, 'exp-1');
      expect(page.totalAmount.minorUnits, 5000);
    });
  });

  group('categories data source', () {
    test('remove returns null on 204 (deleted)', () async {
      final api = CategoriesApi(_clientWith(_FakeAdapter(statusCode: 204, body: null)));
      expect(await api.remove('cat-1'), isNull);
    });

    test('remove returns the archived category on 200 (in use)', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        body: {
          'id': 'cat-1',
          'name': 'Rent',
          'name_am': 'ቤት ኪራይ',
          'color': '#6D4C41',
          'icon': 'home',
          'is_archived': true,
          'is_default': false,
        },
      );
      final api = CategoriesApi(_clientWith(adapter));

      final result = await api.remove('cat-1');

      expect(result, isNotNull);
      expect(result!.isArchived, isTrue);
    });
  });

  group('units data source', () {
    test('list decodes units', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        body: [
          {'id': 'u1', 'code': 'kg', 'name': 'Kilogram', 'name_am': 'ኪሎግራም', 'is_system': true},
          {'id': 'u2', 'code': 'l', 'name': 'Litre', 'name_am': 'ሊትር', 'is_system': true},
        ],
      );
      final api = UnitsApi(_clientWith(adapter));
      final units = await api.list();
      expect(units.map((u) => u.code), ['kg', 'l']);
      expect(units.first.label(amharic: true), 'ኪሎግራም');
      expect(units.first.isSystem, isTrue);
    });

    test('create posts and decodes a custom unit', () async {
      final adapter = _FakeAdapter(
        statusCode: 201,
        body: {'id': 'u3', 'code': 'crate', 'name': 'Crate', 'name_am': null, 'is_system': false},
      );
      final api = UnitsApi(_clientWith(adapter));
      final unit = await api.create(code: 'crate', name: 'Crate');
      expect(unit.code, 'crate');
      expect(unit.isSystem, isFalse);
      final sent = (adapter.lastRequest!.data as Map).cast<String, Object?>();
      expect(sent['code'], 'crate');
    });
  });

  group('items data source', () {
    test('list decodes items', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        body: [
          {
            'id': 'i1',
            'name': 'Sugar',
            'name_am': 'ስኳር',
            'default_unit_id': 'u1',
            'is_archived': false,
          },
        ],
      );
      final api = ItemsApi(_clientWith(adapter));
      final items = await api.list();
      expect(items.single.name, 'Sugar');
      expect(items.single.defaultUnitId, 'u1');
    });

    test('remove returns null on 204 and the archived item on 200', () async {
      final deleted = ItemsApi(_clientWith(_FakeAdapter(statusCode: 204, body: null)));
      expect(await deleted.remove('i1'), isNull);

      final archived = ItemsApi(
        _clientWith(_FakeAdapter(statusCode: 200, body: {
          'id': 'i1',
          'name': 'Sugar',
          'name_am': null,
          'default_unit_id': null,
          'is_archived': true,
        })),
      );
      final result = await archived.remove('i1');
      expect(result!.isArchived, isTrue);
    });
  });

  group('expense item line', () {
    test('record sends the item block and decodes it back', () async {
      final adapter = _FakeAdapter(
        statusCode: 201,
        body: {
          'id': 'exp-1',
          'category_id': 'cat-1',
          'amount': {'amount_minor': 48000, 'currency': 'ETB'},
          'spent_on': {
            'gregorian': '2026-09-01',
            'ethiopian': '2018-12-26',
            'ethiopian_month_name_am': 'ነሐሴ',
            'ethiopian_month_name_en': 'Nehase',
            'entered_in': 'gregorian',
          },
          'note': null,
          'payment_method': 'cash',
          'category_name': 'Groceries',
          'category_name_am': null,
          'item': {
            'item_id': 'i1',
            'item_name': 'Sugar',
            'item_name_am': 'ስኳር',
            'quantity': '12',
            'quantity_milli': 12000,
            'unit_id': 'u1',
            'unit_code': 'kg',
            'unit_name': 'Kilogram',
            'unit_name_am': 'ኪሎግራም',
          },
        },
      );
      final api = ExpensesApi(_clientWith(adapter));
      final expense = await api.record(
        categoryId: 'cat-1',
        amountMinor: 48000,
        date: '2026-09-01',
        itemName: 'Sugar',
        quantity: '12',
        unitId: 'u1',
      );
      expect(expense.item, isNotNull);
      expect(expense.item!.itemName, 'Sugar');
      expect(expense.item!.quantity, '12');
      expect(expense.item!.quantityMilli, 12000);
      expect(expense.item!.unitCode, 'kg');

      final sent = (adapter.lastRequest!.data as Map).cast<String, Object?>();
      final item = (sent['item'] as Map).cast<String, Object?>();
      expect(item['item_name'], 'Sugar');
      expect(item['quantity'], '12');
      expect(item['unit_id'], 'u1');
    });

    test('an amount-only expense has a null item', () async {
      final adapter = _FakeAdapter(
        statusCode: 201,
        body: {
          'id': 'exp-2',
          'category_id': 'cat-1',
          'amount': {'amount_minor': 2000, 'currency': 'ETB'},
          'spent_on': {
            'gregorian': '2026-09-04',
            'ethiopian': '2018-12-29',
            'ethiopian_month_name_am': 'ነሐሴ',
            'ethiopian_month_name_en': 'Nehase',
            'entered_in': 'gregorian',
          },
          'note': null,
          'payment_method': 'cash',
          'category_name': 'Coffee',
          'category_name_am': null,
          'item': null,
        },
      );
      final api = ExpensesApi(_clientWith(adapter));
      final expense = await api.record(categoryId: 'cat-1', amountMinor: 2000, date: '2026-09-04');
      expect(expense.item, isNull);
    });
  });

  group('item-usage report data source', () {
    test('decodes lines with quantity and money', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        body: {
          'period': {
            'calendar': 'gregorian',
            'label_am': 'ሴፕቴምበር 2026',
            'label_en': 'September 2026',
            'first_day': '2026-09-01',
            'last_day': '2026-09-30',
          },
          'currency': 'ETB',
          'lines': [
            {
              'item_id': 'i2',
              'item_name': 'Oil',
              'item_name_am': null,
              'unit_id': 'u2',
              'unit_code': 'l',
              'unit_name': 'Litre',
              'unit_name_am': 'ሊትር',
              'total_quantity': '8',
              'total_quantity_milli': 8000,
              'total_amount': {'amount_minor': 64000, 'currency': 'ETB'},
              'entry_count': 1,
            },
            {
              'item_id': 'i1',
              'item_name': 'Sugar',
              'item_name_am': 'ስኳር',
              'unit_id': 'u1',
              'unit_code': 'kg',
              'unit_name': 'Kilogram',
              'unit_name_am': 'ኪሎግራም',
              'total_quantity': '15',
              'total_quantity_milli': 15000,
              'total_amount': {'amount_minor': 60000, 'currency': 'ETB'},
              'entry_count': 2,
            },
          ],
        },
      );
      final api = ItemUsageReportsApi(_clientWith(adapter));
      final report = await api.forPeriod(year: 2026, month: 9, calendar: 'gregorian');

      expect(report.isEmpty, isFalse);
      expect(report.periodLabel(), 'September 2026');
      expect(report.lines.first.itemName, 'Oil');
      expect(report.lines.first.totalQuantityMilli, 8000);
      expect(report.lines.first.totalAmount.minorUnits, 64000);
      expect(report.lines[1].itemLabel(amharic: true), 'ስኳር');
      expect(report.lines[1].totalQuantity, '15');
    });
  });
}

/// An adapter that always throws a connection error, to exercise the network path.
class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'connection refused',
    );
  }

  @override
  void close({bool force = false}) {}
}
