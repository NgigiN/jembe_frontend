import 'dart:convert';

import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:farm_tracker/features/farm/data/sync/land_syncer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captured verbatim from production on 2026-10-05, after the client_uuid
/// backfill — this is byte-for-byte what the device received.
const String kRealLandsPayload = '''
[
  {
    "id": 23,
    "created_at": "2026-09-08T07:51:52.607077Z",
    "updated_at": "2026-09-08T07:51:52.607077Z",
    "client_uuid": "109b2153-06ce-4cb7-a753-80556553e8dd",
    "user_id": 7,
    "name": "Cute",
    "size": 50,
    "location": "Embu",
    "soil_type": "loam",
    "tenure_type": "",
    "farm_id": 7,
    "logged_by": {"user_id": 7, "first_name": "Ngigi", "last_name": "Nyongo"}
  },
  {
    "id": 6,
    "created_at": "2026-05-09T18:30:19.472701Z",
    "updated_at": "2026-10-05T11:27:45.693527Z",
    "client_uuid": "bf7ebb01-f89f-4cb9-8714-4357dad626f3",
    "user_id": 7,
    "name": "Kambaa Tea Farm",
    "size": 1,
    "location": "Kiambu",
    "soil_type": "loam",
    "tenure_type": "",
    "farm_id": 7,
    "logged_by": {"user_id": 7, "first_name": "Ngigi", "last_name": "Nyongo"}
  }
]
''';

class _PayloadRemote implements LandRemoteDataSource {
  _PayloadRemote(this.rows);
  final List<LandModel> rows;
  @override
  Future<List<LandModel>> getLands({
    DateTime? updatedSince,
    int? limit,
    int? cursor,
  }) async => rows;
  @override
  Future<LandModel> addLand(LandModel l) async => l;
  @override
  Future<LandModel> updateLand(LandModel l) async => l;
  @override
  Future<void> deleteLand(String id) async {}
}

void main() {
  test('the real production payload parses with a client_uuid intact', () {
    final decoded = jsonDecode(kRealLandsPayload) as List<dynamic>;
    final models = decoded
        .map((j) => LandModel.fromJson(j as Map<String, dynamic>))
        .toList();

    expect(models.length, 2);
    for (final m in models) {
      expect(
        m.clientUuid,
        isNotEmpty,
        reason:
            'an empty clientUuid is silently skipped by the syncer — '
            'that is the whole incident',
      );
    }
    expect(models.map((m) => m.name), ['Cute', 'Kambaa Tea Farm']);
  });

  test('that same payload reaches the local mirror for farm 7', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final decoded = jsonDecode(kRealLandsPayload) as List<dynamic>;
    final models = decoded
        .map((j) => LandModel.fromJson(j as Map<String, dynamic>))
        .toList();

    final local = LandLocalDataSource(db);
    final syncer = LandSyncer(remote: _PayloadRemote(models), local: local);

    await syncer.pull(null, farmId: 7);

    final mirrored = await local.watchLands(farmId: 7).first;
    expect(
      mirrored.map((l) => l.name).toSet(),
      {'Cute', 'Kambaa Tea Farm'},
      reason: 'the device showed "No lands registered yet" for this payload',
    );
  });
}
