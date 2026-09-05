import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedUuidGen extends UuidGen {
  const _FixedUuidGen(this.value);
  final String value;

  @override
  String v4() => value;
}

void main() {
  group('LandModel.create', () {
    test('carries an optional tenureType through', () {
      final land = LandModel.create(
        userId: 'user-1',
        name: 'North Field',
        tenureType: 'owned',
      );

      expect(land.tenureType, 'owned');
    });

    test('defaults tenureType to null when omitted', () {
      final land = LandModel.create(userId: 'user-1', name: 'North Field');

      expect(land.tenureType, isNull);
    });

    test('mints a non-empty clientUuid when none supplied', () {
      final land = LandModel.create(userId: 'user-1', name: 'North Field');

      expect(land.clientUuid, isNotEmpty);
    });

    test('uses the injected UuidGen to mint clientUuid', () {
      final land = LandModel.create(
        userId: 'user-1',
        name: 'North Field',
        uuid: const _FixedUuidGen('fixed-uuid-1'),
      );

      expect(land.clientUuid, 'fixed-uuid-1');
    });

    test('honours an explicitly supplied clientUuid over the generator', () {
      final land = LandModel.create(
        userId: 'user-1',
        name: 'North Field',
        clientUuid: 'explicit-uuid',
        uuid: const _FixedUuidGen('fixed-uuid-1'),
      );

      expect(land.clientUuid, 'explicit-uuid');
    });
  });

  group('LandModel.fromJson', () {
    test('parses snake_case tenure_type', () {
      final land = LandModel.fromJson(const {
        'id': '1',
        'user_id': 'user-1',
        'name': 'North Field',
        'tenure_type': 'rented',
      });

      expect(land.tenureType, 'rented');
    });

    test('parses missing tenure_type as null', () {
      final land = LandModel.fromJson(const {
        'id': '1',
        'user_id': 'user-1',
        'name': 'North Field',
      });

      expect(land.tenureType, isNull);
    });

    test('parses snake_case client_uuid', () {
      final land = LandModel.fromJson(const {
        'id': '1',
        'user_id': 'user-1',
        'name': 'North Field',
        'client_uuid': 'client-uuid-1',
      });

      expect(land.clientUuid, 'client-uuid-1');
    });

    test('parses PascalCase ClientUUID', () {
      final land = LandModel.fromJson(const {
        'id': '1',
        'user_id': 'user-1',
        'name': 'North Field',
        'ClientUUID': 'client-uuid-2',
      });

      expect(land.clientUuid, 'client-uuid-2');
    });

    test('defaults client_uuid to empty string when absent', () {
      final land = LandModel.fromJson(const {
        'id': '1',
        'user_id': 'user-1',
        'name': 'North Field',
      });

      expect(land.clientUuid, '');
    });
  });

  group('LandModel.toJson', () {
    test('includes tenure_type', () {
      final land = LandModel.create(
        userId: 'user-1',
        name: 'North Field',
        tenureType: 'owned',
      );

      expect(land.toJson()['tenure_type'], 'owned');
    });

    test('includes client_uuid', () {
      final land = LandModel.create(
        userId: 'user-1',
        name: 'North Field',
        clientUuid: 'client-uuid-1',
      );

      expect(land.toJson()['client_uuid'], 'client-uuid-1');
    });
  });

  group('LandModel.fromDrift', () {
    test('round-trips all fields, mapping serverId to id', () {
      final now = DateTime.utc(2026, 3, 15);
      final row = LandRow(
        clientUuid: 'client-uuid-1',
        serverId: 'server-1',
        userId: 'user-1',
        name: 'North Field',
        size: 4.5,
        location: 'Nyeri',
        soilType: 'loam',
        tenureType: 'owned',
        createdAt: now,
        updatedAt: now,
        pending: false,
        deletedLocally: false,
      );

      final land = LandModel.fromDrift(row);

      expect(land.id, 'server-1');
      expect(land.clientUuid, 'client-uuid-1');
      expect(land.userId, 'user-1');
      expect(land.name, 'North Field');
      expect(land.size, 4.5);
      expect(land.location, 'Nyeri');
      expect(land.soilType, 'loam');
      expect(land.tenureType, 'owned');
      expect(land.createdAt, now);
      expect(land.updatedAt, now);
    });

    test('defaults id to empty string when serverId is null', () {
      final now = DateTime.utc(2026, 3, 15);
      final row = LandRow(
        clientUuid: 'client-uuid-1',
        userId: 'user-1',
        name: 'North Field',
        createdAt: now,
        updatedAt: now,
        pending: true,
        deletedLocally: false,
      );

      final land = LandModel.fromDrift(row);

      expect(land.id, '');
      expect(land.clientUuid, 'client-uuid-1');
    });
  });

  group('LandModel.toCompanion', () {
    test('maps all fields, including serverId from a non-empty id', () {
      final now = DateTime.utc(2026, 3, 15);
      final land = LandModel(
        id: 'server-1',
        clientUuid: 'client-uuid-1',
        userId: 'user-1',
        name: 'North Field',
        size: 4.5,
        location: 'Nyeri',
        soilType: 'loam',
        tenureType: 'owned',
        createdAt: now,
        updatedAt: now,
      );

      final companion = land.toCompanion(pending: true);

      expect(companion.clientUuid, const Value('client-uuid-1'));
      expect(companion.serverId, const Value('server-1'));
      expect(companion.userId, const Value('user-1'));
      expect(companion.name, const Value('North Field'));
      expect(companion.size, const Value(4.5));
      expect(companion.location, const Value('Nyeri'));
      expect(companion.soilType, const Value('loam'));
      expect(companion.tenureType, const Value('owned'));
      expect(companion.createdAt, Value(now));
      expect(companion.updatedAt, Value(now));
      expect(companion.pending, const Value(true));
      expect(companion.deletedLocally, const Value(false));
    });

    test('maps an empty id to a null serverId', () {
      final land = LandModel.create(
        userId: 'user-1',
        name: 'North Field',
        clientUuid: 'client-uuid-1',
      );

      final companion = land.toCompanion(pending: true);

      expect(companion.serverId, const Value(null));
    });
  });
}
