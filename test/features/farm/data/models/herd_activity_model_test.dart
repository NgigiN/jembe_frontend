import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/features/farm/data/models/herd_activity_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HerdActivityModel', () {
    test(
      'toJson OMITS herdId (it travels in the nested URL) and sends reason '
      'under the backend field name',
      () {
        final model = HerdActivityModel.create(
          herdId: '1',
          activityType: 'fatality',
          count: 2,
          date: DateTime.utc(2026, 9),
          notes: 'lion attack',
        );
        final json = model.toJson();
        expect(json['reason'], 'lion attack');
        expect(json.containsKey('notes'), isFalse);
        expect(json.containsKey('herd_id'), isFalse);
        expect(json.containsKey('herdId'), isFalse);
        expect(json, {
          'activity_type': 'fatality',
          'count': 2,
          'date': DateTime.utc(2026, 9).toIso8601String(),
          'reason': 'lion attack',
        });
      },
    );

    test('fromJson reads the backend reason field', () {
      final model = HerdActivityModel.fromJson(const {
        'ID': 7,
        'herd_id': 1,
        'activity_type': 'fatality',
        'count': 2,
        'date': '2026-09-01T00:00:00Z',
        'reason': 'lion attack',
        'CreatedAt': '2026-09-01T10:00:00Z',
      });
      expect(model.notes, 'lion attack');
    });

    test(
      'create mints a clientUuid and a server-unknown id placeholder',
      () {
        final model = HerdActivityModel.create(
          herdId: 'herd-1',
          activityType: 'birth',
          count: 1,
          date: DateTime.utc(2026, 9),
        );
        expect(model.id, '');
        expect(model.clientUuid, isNotEmpty);
        expect(model.pending, isFalse);
        expect(model.deletedLocally, isFalse);
      },
    );

    test('syncUpdatedAt mirrors createdAt (no real updatedAt exists)', () {
      final model = HerdActivityModel.create(
        herdId: 'herd-1',
        activityType: 'birth',
        count: 1,
        date: DateTime.utc(2026, 9),
      );
      expect(model.syncUpdatedAt, model.createdAt);
    });

    test('fromDrift carries herdId and local sync-state flags', () {
      final row = HerdActivityRow(
        clientUuid: 'cu-1',
        serverId: 'server-1',
        herdId: 'herd-7',
        activityType: 'fatality',
        count: 3,
        date: DateTime.utc(2026, 9, 2),
        notes: 'drought',
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
        pending: true,
        deletedLocally: false,
      );

      final model = HerdActivityModel.fromDrift(row);

      expect(model.id, 'server-1');
      expect(model.herdId, 'herd-7');
      expect(model.notes, 'drought');
      expect(model.pending, isTrue);
      expect(model.deletedLocally, isFalse);
    });

    test(
      'toCompanion synthesizes updatedAt from createdAt (no real updatedAt)',
      () {
        final model = HerdActivityModel.create(
          herdId: 'herd-1',
          activityType: 'birth',
          count: 1,
          date: DateTime.utc(2026, 9),
          clientUuid: 'cu-1',
        );

        final companion = model.toCompanion(pending: true);

        expect(companion.updatedAt.value, model.createdAt);
        expect(companion.herdId.value, 'herd-1');
      },
    );
  });
}
