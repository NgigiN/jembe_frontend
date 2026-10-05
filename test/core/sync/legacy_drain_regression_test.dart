import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:farm_tracker/features/farm/data/models/plant_model.dart';
import 'package:farm_tracker/features/farm/data/sync/land_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/plant_syncer.dart';
import 'package:flutter_test/flutter_test.dart';

/// The farm a real signed-in user resolves to — deliberately NOT the `1`
/// that every farmId parameter defaults to, so a default leaking through
/// instead of the caller's value is caught rather than hidden.
const int kFarmId = 7;

class _FakeLandRemote implements LandRemoteDataSource {
  _FakeLandRemote(this.rows);
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

class _FakePlantRemote implements PlantRemoteDataSource {
  _FakePlantRemote(this.rows);
  final List<PlantModel> rows;
  @override
  Future<List<PlantModel>> getPlants({
    DateTime? updatedSince,
    int? limit,
    int? cursor,
  }) async => rows;
  @override
  Future<PlantModel> addPlant(PlantModel p) async => p;
  @override
  Future<PlantModel> updatePlant(PlantModel p) async => p;
  @override
  Future<void> deletePlant(String id) async {}
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// A server row as it looks AFTER the client_uuid backfill: a real
  /// identifier and an updated_at at the backfill instant.
  LandModel land(String uuid, String name, int serverId) => LandModel(
    id: '$serverId',
    clientUuid: uuid,
    userId: '7',
    name: name,
    createdAt: DateTime.utc(2026, 5, 9),
    updatedAt: DateTime.utc(2026, 10, 5, 11, 27, 45),
  );

  test(
    'a first-ever pull mirrors every backfilled land into the local store',
    () async {
      final local = LandLocalDataSource(db);
      final syncer = LandSyncer(
        remote: _FakeLandRemote([
          land('bf7ebb01-f89f-4cb9-8714-4357dad626f3', 'Kambaa Tea Farm', 6),
          land('109b2153-06ce-4cb7-a753-80556553e8dd', 'Cute', 23),
          land('aa11bb22-cc33-dd44-ee55-ff6677889900', 'Mau Summit', 12),
        ]),
        local: local,
      );

      // Exactly what SyncEngine does for a device that has never synced.
      await syncer.pull(null, farmId: kFarmId);

      final mirrored = await local.watchLands(farmId: kFarmId).first;
      expect(
        mirrored.map((l) => l.name).toSet(),
        {'Kambaa Tea Farm', 'Cute', 'Mau Summit'},
        reason:
            'every land the server returned must reach the local mirror — '
            'this is the drain that decides whether a user sees a blank app',
      );
    },
  );

  test('the same drain works for plants (control, known good)', () async {
    final local = PlantLocalDataSource(db);
    final syncer = PlantSyncer(
      remote: _FakePlantRemote([
        PlantModel(
          id: '6',
          clientUuid: 'cc11dd22-ee33-ff44-0011-223344556677',
          userId: '7',
          name: 'Tea',
          createdAt: DateTime.utc(2026, 5, 9),
          updatedAt: DateTime.utc(2026, 10, 5, 11, 27, 45),
        ),
      ]),
      local: local,
    );

    await syncer.pull(null, farmId: kFarmId);

    final mirrored = await local.watchPlants(farmId: kFarmId).first;
    expect(mirrored.length, 1);
  });
}
