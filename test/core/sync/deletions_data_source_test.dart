import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/sync/deletions_data_source.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Fake [HttpClientAdapter] that returns a canned body/status without
/// touching the network, and records the [RequestOptions] it was called
/// with so tests can assert on the query string.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.body, this.statusCode = 200});
  final String body;
  final int statusCode;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Fake adapter that simulates a connection failure (offline).
class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'simulated offline',
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Mocktail double for a registered entity's local mirror — used to prove
/// tombstones route to the correct entry in [DeletionsDataSource.stores]
/// without needing a second real drift-backed data source per entity.
class _MockLocalStore extends Mock implements LocalSyncStore<SyncableModel> {}

/// Minimal [SyncableModel] returned by a mocked `getByServerId`, just enough
/// to exercise the no-client_uuid fallback (`local.syncClientUuid`).
class _FakeSyncableModel extends Fake implements SyncableModel {
  _FakeSyncableModel(this.syncClientUuid);

  @override
  final String syncClientUuid;
}

LandModel _land({required String clientUuid, required String id}) {
  final now = DateTime.utc(2026);
  return LandModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: 'North Field',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late AppDatabase db;
  late LandLocalDataSource landLocal;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    landLocal = LandLocalDataSource(db);
  });

  tearDown(() async {
    await db.close();
  });

  Dio dioWith(HttpClientAdapter adapter) {
    return Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
  }

  test('hard-deletes the local row for a land tombstone', () async {
    await landLocal.upsert(_land(clientUuid: 'cu-1', id: '1'), pending: false);
    final adapter = _FakeAdapter(
      body:
          '[{"entity":"land","id":1,"client_uuid":"cu-1",'
          '"deleted_at":"2026-01-02T00:00:00Z"}]',
    );
    final source = DeletionsDataSource(
      dio: dioWith(adapter),
      stores: {'land': landLocal},
    );

    await source.applyDeletions(null);

    expect(await landLocal.getByClientUuid('cu-1'), isNull);
  });

  test('ignores tombstones for entities other than land', () async {
    await landLocal.upsert(_land(clientUuid: 'cu-2', id: '2'), pending: false);
    final adapter = _FakeAdapter(
      body:
          '[{"entity":"plant","id":2,"client_uuid":"cu-2",'
          '"deleted_at":"2026-01-02T00:00:00Z"}]',
    );
    final source = DeletionsDataSource(
      dio: dioWith(adapter),
      stores: {'land': landLocal},
    );

    await source.applyDeletions(null);

    expect(await landLocal.getByClientUuid('cu-2'), isNotNull);
  });

  test('falls back to matching by server id when client_uuid is empty', () async {
    await landLocal.upsert(_land(clientUuid: 'cu-3', id: '3'), pending: false);
    final adapter = _FakeAdapter(
      body:
          '[{"entity":"land","id":3,"client_uuid":"",'
          '"deleted_at":"2026-01-02T00:00:00Z"}]',
    );
    final source = DeletionsDataSource(
      dio: dioWith(adapter),
      stores: {'land': landLocal},
    );

    await source.applyDeletions(null);

    expect(await landLocal.getByClientUuid('cu-3'), isNull);
  });

  test('is idempotent: hard-deleting an already-gone row is a no-op', () async {
    final adapter = _FakeAdapter(
      body:
          '[{"entity":"land","id":99,"client_uuid":"missing",'
          '"deleted_at":"2026-01-02T00:00:00Z"}]',
    );
    final source = DeletionsDataSource(
      dio: dioWith(adapter),
      stores: {'land': landLocal},
    );

    await source.applyDeletions(null);
    await source.applyDeletions(null);

    expect(await landLocal.getByClientUuid('missing'), isNull);
  });

  test('sends updated_since as an RFC3339 query param when given', () async {
    final adapter = _FakeAdapter(body: '[]');
    final source = DeletionsDataSource(
      dio: dioWith(adapter),
      stores: {'land': landLocal},
    );

    await source.applyDeletions(DateTime.utc(2026, 3, 4));

    expect(
      adapter.lastOptions!.uri.queryParameters['updated_since'],
      '2026-03-04T00:00:00.000Z',
    );
  });

  test('omits the query param when since is null', () async {
    final adapter = _FakeAdapter(body: '[]');
    final source = DeletionsDataSource(
      dio: dioWith(adapter),
      stores: {'land': landLocal},
    );

    await source.applyDeletions(null);

    expect(adapter.lastOptions!.uri.queryParameters.containsKey('updated_since'), isFalse);
  });

  test('propagates a NetworkException on connection failure', () async {
    final source = DeletionsDataSource(
      dio: dioWith(_ThrowingAdapter()),
      stores: {'land': landLocal},
    );

    await expectLater(
      source.applyDeletions(null),
      throwsA(isA<NetworkException>()),
    );
  });

  test('propagates a ServerException on a non-200 response', () async {
    final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 500);
    final source = DeletionsDataSource(
      dio: dioWith(adapter),
      stores: {'land': landLocal},
    );

    await expectLater(
      source.applyDeletions(null),
      throwsA(isA<ServerException>()),
    );
  });

  group('entity-keyed routing (two registered entities)', () {
    late _MockLocalStore landStore;
    late _MockLocalStore plantStore;

    setUp(() {
      landStore = _MockLocalStore();
      plantStore = _MockLocalStore();
      when(() => landStore.hardDelete(any())).thenAnswer((_) async {});
      when(() => plantStore.hardDelete(any())).thenAnswer((_) async {});
    });

    DeletionsDataSource sourceWith(HttpClientAdapter adapter) {
      return DeletionsDataSource(
        dio: dioWith(adapter),
        stores: {'land': landStore, 'plant': plantStore},
      );
    }

    test('a land tombstone hard-deletes on the land store only', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"entity":"land","id":1,"client_uuid":"cu-land-1",'
            '"deleted_at":"2026-01-02T00:00:00Z"}]',
      );

      await sourceWith(adapter).applyDeletions(null);

      verify(() => landStore.hardDelete('cu-land-1')).called(1);
      verifyNever(() => plantStore.hardDelete(any()));
    });

    test('a plant tombstone hard-deletes on the plant store only', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"entity":"plant","id":2,"client_uuid":"cu-plant-1",'
            '"deleted_at":"2026-01-02T00:00:00Z"}]',
      );

      await sourceWith(adapter).applyDeletions(null);

      verify(() => plantStore.hardDelete('cu-plant-1')).called(1);
      verifyNever(() => landStore.hardDelete(any()));
    });

    test(
      'a tombstone for an unregistered entity is a no-op on every store',
      () async {
        final adapter = _FakeAdapter(
          body:
              '[{"entity":"animal","id":3,"client_uuid":"cu-animal-1",'
              '"deleted_at":"2026-01-02T00:00:00Z"}]',
        );

        await sourceWith(adapter).applyDeletions(null);

        verifyNever(() => landStore.hardDelete(any()));
        verifyNever(() => plantStore.hardDelete(any()));
      },
    );

    test(
      'the no-client_uuid fallback resolves via getByServerId then hard-deletes '
      'on the right store',
      () async {
        when(
          () => plantStore.getByServerId('5'),
        ).thenAnswer((_) async => _FakeSyncableModel('resolved-cu'));
        final adapter = _FakeAdapter(
          body:
              '[{"entity":"plant","id":5,"client_uuid":"",'
              '"deleted_at":"2026-01-02T00:00:00Z"}]',
        );

        await sourceWith(adapter).applyDeletions(null);

        verify(() => plantStore.getByServerId('5')).called(1);
        verify(() => plantStore.hardDelete('resolved-cu')).called(1);
        verifyNever(() => landStore.hardDelete(any()));
      },
    );
  });
}
