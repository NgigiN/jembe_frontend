import 'dart:async';

import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:flutter_test/flutter_test.dart';

LandModel _land({
  required String clientUuid,
  String id = '',
  String name = 'North Field',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return LandModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    createdAt: at,
    updatedAt: updatedAt ?? at,
  );
}

void main() {
  late AppDatabase db;
  late LandLocalDataSource dataSource;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dataSource = LandLocalDataSource(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('upsert + watchLands', () {
    test('watchLands emits reactively as rows are upserted', () async {
      // Subscribe and wait for the initial (empty) emission *before*
      // writing, so the assertion isn't racing the write against drift's
      // first query (which could otherwise coalesce into a single
      // already-up-to-date emission).
      final emissions = <List<LandModel>>[];
      var afterEmission = Completer<void>();
      final subscription = dataSource.watchLands().listen((lands) {
        emissions.add(lands);
        afterEmission.complete();
      });

      await afterEmission.future;
      expect(emissions, hasLength(1));
      expect(emissions.single, isEmpty);

      afterEmission = Completer<void>();
      await dataSource.upsert(_land(clientUuid: 'cu-1'), pending: true);
      await afterEmission.future;

      expect(emissions, hasLength(2));
      expect(emissions[1], hasLength(1));
      expect(emissions[1].single.clientUuid, 'cu-1');

      await subscription.cancel();
    });

    test(
      'upserting twice with the same clientUuid replaces the row',
      () async {
        await dataSource.upsert(
          _land(clientUuid: 'cu-1', name: 'Old name'),
          pending: true,
        );
        await dataSource.upsert(
          _land(clientUuid: 'cu-1', name: 'New name'),
          pending: false,
        );

        final lands = await dataSource.watchLands().first;

        expect(lands, hasLength(1));
        expect(lands.single.clientUuid, 'cu-1');
        expect(lands.single.name, 'New name');
      },
    );

    test('orders by createdAt ascending', () async {
      await dataSource.upsert(
        _land(clientUuid: 'newer', createdAt: DateTime.utc(2026, 3)),
        pending: true,
      );
      await dataSource.upsert(
        _land(clientUuid: 'older', createdAt: DateTime.utc(2026)),
        pending: true,
      );

      final lands = await dataSource.watchLands().first;

      expect(lands.map((l) => l.clientUuid).toList(), ['older', 'newer']);
    });
  });

  group('markDeleted', () {
    test(
      'hides the row from watchLands, but the row still exists as a '
      'tombstone',
      () async {
        await dataSource.upsert(_land(clientUuid: 'cu-1'), pending: false);

        await dataSource.markDeleted('cu-1');

        final lands = await dataSource.watchLands().first;
        expect(lands, isEmpty);

        final row = await (db.select(
          db.lands,
        )..where((r) => r.clientUuid.equals('cu-1'))).getSingle();
        expect(row.deletedLocally, isTrue);
        expect(row.pending, isTrue);

        final stillThere = await dataSource.getByClientUuid('cu-1');
        expect(stillThere, isNotNull);
        expect(stillThere!.clientUuid, 'cu-1');
      },
    );
  });

  group('hardDelete', () {
    test('physically removes the row', () async {
      await dataSource.upsert(_land(clientUuid: 'cu-1'), pending: false);

      await dataSource.hardDelete('cu-1');

      expect(await dataSource.getByClientUuid('cu-1'), isNull);
    });
  });

  group('setServerId', () {
    test('populates serverId + updatedAt and clears pending', () async {
      await dataSource.upsert(_land(clientUuid: 'cu-1'), pending: true);
      final newUpdatedAt = DateTime.utc(2026, 5);

      await dataSource.setServerId('cu-1', 'server-1', newUpdatedAt);

      final land = await dataSource.getByClientUuid('cu-1');
      expect(land, isNotNull);
      expect(land!.id, 'server-1');
      // Drift round-trips DateTime through storage as a local-zone instant
      // (isUtc becomes false even though we wrote a UTC DateTime), so
      // compare the moment, not object equality (`==` on DateTime also
      // requires a matching `isUtc` flag).
      expect(land.updatedAt.isAtSameMomentAs(newUpdatedAt), isTrue);

      final row = await (db.select(
        db.lands,
      )..where((r) => r.clientUuid.equals('cu-1'))).getSingle();
      expect(row.pending, isFalse);
    });
  });

  group('getByServerId', () {
    test('finds a reconciled row by its server id', () async {
      await dataSource.upsert(_land(clientUuid: 'cu-1'), pending: true);
      await dataSource.setServerId(
        'cu-1',
        'server-1',
        DateTime.utc(2026, 5),
      );

      final land = await dataSource.getByServerId('server-1');

      expect(land, isNotNull);
      expect(land!.clientUuid, 'cu-1');
    });

    test('returns null when no row matches', () async {
      expect(await dataSource.getByServerId('missing'), isNull);
    });
  });

  group('getByClientUuid', () {
    test('returns null when no row matches', () async {
      expect(await dataSource.getByClientUuid('missing'), isNull);
    });
  });

  group('clear', () {
    test('deletes all rows', () async {
      await dataSource.upsert(_land(clientUuid: 'cu-1'), pending: true);
      await dataSource.upsert(_land(clientUuid: 'cu-2'), pending: true);

      await dataSource.clear();

      expect(await dataSource.watchLands().first, isEmpty);
      expect(await dataSource.getByClientUuid('cu-1'), isNull);
      expect(await dataSource.getByClientUuid('cu-2'), isNull);
    });
  });
}
