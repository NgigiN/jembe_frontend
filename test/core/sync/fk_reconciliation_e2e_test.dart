// Golden end-to-end tests for P4's cross-entity FK reconciliation (Task 6 —
// see
// `.superpowers/sdd/2026-09-06-offline-first-p4-fk-reconciliation/task-6-brief.md`).
//
// Proves the WHOLE loop through the REAL `SyncEngine` + real `EntitySyncer`s
// + real drift-backed local mirrors against a fake in-memory "server": an
// offline-created parent and child sync, the parent lands first (FIFO), and
// the child's create body carries the parent's SERVER id — not its
// client_uuid. Mirrors the existing single-entity goldens
// (`season_offline_e2e_test.dart`, `harvest_offline_e2e_test.dart`, etc.): a
// real `AppDatabase.forTesting` (in-memory sqlite via drift), real
// `OutboxDao`/`SyncCursorDao`/`*LocalDataSource`s, real `*Syncer`s and a real
// `SyncEngine` (with `fkStores` wired exactly like
// `injection_container.dart`), driven against fakes at the network boundary
// only (`*RemoteDataSource`) plus a fake `ConnectivityService`.
//
// ## One deliberate divergence from the single-entity goldens
// Those tests drive creates through a `*RepositoryImpl` (`repo.addSeason`,
// `repo.addHarvest`, ...). This file instead calls each entity's
// `*Model.create(clientUuid: ...)` factory directly, followed by the exact
// same `local.upsert(pending:true)` + `outbox.enqueue(...)` pair
// `OfflineRepositoryMixin.stageWrite` performs (see
// `lib/core/offline/offline_repository.dart`) — i.e. the SAME real
// plumbing, just invoked directly instead of through a repository facade.
// This is necessary here (and not in the single-entity goldens) because a
// cross-entity FK chain needs an explicit, known `client_uuid` for the
// PARENT before the CHILD model is even constructed (so the child's FK
// field can reference it) — repositories mint a fresh random uuid per call
// and only hand it back via the returned domain entity's `id`, which is
// fine for a single entity but awkward to thread through a 3-level chain
// across 7 different entity types. No sync-engine behavior under test is
// affected: `SyncEngine.syncNow()`, the real `*Syncer`s, and the FK
// translators (`fk_translators.dart`) never go through the repository layer
// either.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/network/connectivity_service.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/outbox_coalescing.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/core/sync/sync_cursor_dao.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/sync/sync_status.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';
import 'package:farm_tracker/features/farm/data/models/animal_type_model.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';
import 'package:farm_tracker/features/farm/data/models/herd_activity_model.dart';
import 'package:farm_tracker/features/farm/data/models/herd_model.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';
import 'package:farm_tracker/features/farm/data/models/plant_model.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';
import 'package:farm_tracker/features/farm/data/sync/animal_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/animal_type_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/harvest_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/herd_activity_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/herd_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/input_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/plant_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/season_syncer.dart';
import 'package:flutter_test/flutter_test.dart';

// --- Fakes: one per entity's RemoteDataSource, each idempotent on
// `client_uuid` (mints a server id once, replays the same row on a retried
// create) and each appending `'<entity>:<client_uuid>'` to a SHARED log —
// the only way this harness can prove CROSS-entity FIFO ordering (a
// per-entity fake's own call list only proves ordering within that entity).

class _FakePlantRemoteDataSource implements PlantRemoteDataSource {
  _FakePlantRemoteDataSource(this._log);
  final List<String> _log;
  final Map<String, PlantModel> _byServerId = {};
  final Map<String, String> _serverIdByClientUuid = {};
  int _nextId = 100;

  List<PlantModel> get allRows => List.unmodifiable(_byServerId.values);
  String? serverIdFor(String clientUuid) => _serverIdByClientUuid[clientUuid];

  @override
  Future<PlantModel> addPlant(PlantModel plant) async {
    _log.add('plant:${plant.clientUuid}');
    final existing = _serverIdByClientUuid[plant.clientUuid];
    if (existing != null) return _byServerId[existing]!;
    final serverId = '${_nextId++}';
    final stored = PlantModel(
      id: serverId,
      clientUuid: plant.clientUuid,
      userId: plant.userId,
      name: plant.name,
      variety: plant.variety,
      createdAt: plant.createdAt,
      updatedAt: plant.updatedAt,
    );
    _byServerId[serverId] = stored;
    _serverIdByClientUuid[plant.clientUuid] = serverId;
    return stored;
  }

  @override
  Future<PlantModel> updatePlant(PlantModel plant) async => plant;

  @override
  Future<void> deletePlant(String id) async {}

  @override
  Future<List<PlantModel>> getPlants({DateTime? updatedSince}) async =>
      allRows;
}

class _FakeSeasonRemoteDataSource implements SeasonRemoteDataSource {
  _FakeSeasonRemoteDataSource(this._log);
  final List<String> _log;
  final Map<String, SeasonModel> _byServerId = {};
  final Map<String, String> _serverIdByClientUuid = {};
  int _nextId = 600;

  List<SeasonModel> get allRows => List.unmodifiable(_byServerId.values);
  String? serverIdFor(String clientUuid) => _serverIdByClientUuid[clientUuid];

  @override
  Future<SeasonModel> addSeason(SeasonModel season) async {
    _log.add('season:${season.clientUuid}');
    final existing = _serverIdByClientUuid[season.clientUuid];
    if (existing != null) return _byServerId[existing]!;
    final serverId = '${_nextId++}';
    final stored = SeasonModel(
      id: serverId,
      clientUuid: season.clientUuid,
      userId: season.userId,
      name: season.name,
      plantId: season.plantId,
      landId: season.landId,
      startDate: season.startDate,
      endDate: season.endDate,
      createdAt: season.createdAt,
      updatedAt: season.updatedAt,
    );
    _byServerId[serverId] = stored;
    _serverIdByClientUuid[season.clientUuid] = serverId;
    return stored;
  }

  @override
  Future<SeasonModel> updateSeason(SeasonModel season) async => season;

  @override
  Future<void> deleteSeason(String id) async {}

  @override
  Future<List<SeasonModel>> getSeasons({DateTime? updatedSince}) async =>
      allRows;
}

class _FakeHarvestRemoteDataSource implements HarvestRemoteDataSource {
  _FakeHarvestRemoteDataSource(this._log);
  final List<String> _log;
  final Map<String, HarvestModel> _byServerId = {};
  final Map<String, String> _serverIdByClientUuid = {};
  int _nextId = 800;

  List<HarvestModel> get allRows => List.unmodifiable(_byServerId.values);
  String? serverIdFor(String clientUuid) => _serverIdByClientUuid[clientUuid];

  @override
  Future<HarvestModel> addHarvest(HarvestModel harvest) async {
    _log.add('harvest:${harvest.clientUuid}');
    final existing = _serverIdByClientUuid[harvest.clientUuid];
    if (existing != null) return _byServerId[existing]!;
    final serverId = '${_nextId++}';
    final stored = HarvestModel(
      id: serverId,
      clientUuid: harvest.clientUuid,
      seasonId: harvest.seasonId,
      quantity: harvest.quantity,
      unit: harvest.unit,
      date: harvest.date,
      notes: harvest.notes,
      revenueId: harvest.revenueId,
      createdAt: harvest.createdAt,
      updatedAt: harvest.updatedAt,
    );
    _byServerId[serverId] = stored;
    _serverIdByClientUuid[harvest.clientUuid] = serverId;
    return stored;
  }

  @override
  Future<HarvestModel> updateHarvest(HarvestModel harvest) async => harvest;

  @override
  Future<void> deleteHarvest(String id) async {}

  @override
  Future<List<HarvestModel>> getHarvests({
    String? seasonId,
    DateTime? updatedSince,
    int? limit,
    int? cursor,
  }) async => allRows;
}

class _FakeAnimalTypeRemoteDataSource implements AnimalTypeRemoteDataSource {
  _FakeAnimalTypeRemoteDataSource(this._log);
  final List<String> _log;
  final Map<String, AnimalTypeModel> _byServerId = {};
  final Map<String, String> _serverIdByClientUuid = {};
  int _nextId = 200;

  List<AnimalTypeModel> get allRows => List.unmodifiable(_byServerId.values);
  String? serverIdFor(String clientUuid) => _serverIdByClientUuid[clientUuid];

  @override
  Future<AnimalTypeModel> addAnimalType(AnimalTypeModel animalType) async {
    _log.add('animal_type:${animalType.clientUuid}');
    final existing = _serverIdByClientUuid[animalType.clientUuid];
    if (existing != null) return _byServerId[existing]!;
    final serverId = '${_nextId++}';
    final stored = AnimalTypeModel(
      id: serverId,
      clientUuid: animalType.clientUuid,
      userId: animalType.userId,
      name: animalType.name,
      notes: animalType.notes,
      createdAt: animalType.createdAt,
      updatedAt: animalType.updatedAt,
    );
    _byServerId[serverId] = stored;
    _serverIdByClientUuid[animalType.clientUuid] = serverId;
    return stored;
  }

  @override
  Future<AnimalTypeModel> updateAnimalType(AnimalTypeModel animalType) async =>
      animalType;

  @override
  Future<void> deleteAnimalType(String id) async {}

  @override
  Future<AnimalTypeModel> getAnimalType(String id) async => _byServerId[id]!;

  @override
  Future<List<AnimalTypeModel>> getAnimalTypes({
    DateTime? updatedSince,
  }) async => allRows;
}

class _FakeHerdRemoteDataSource implements HerdRemoteDataSource {
  _FakeHerdRemoteDataSource(this._log);
  final List<String> _log;
  final Map<String, HerdModel> _byServerId = {};
  final Map<String, String> _serverIdByClientUuid = {};
  int _nextId = 300;

  List<HerdModel> get allRows => List.unmodifiable(_byServerId.values);
  String? serverIdFor(String clientUuid) => _serverIdByClientUuid[clientUuid];

  @override
  Future<HerdModel> addHerd(HerdModel herd) async {
    _log.add('herd:${herd.clientUuid}');
    final existing = _serverIdByClientUuid[herd.clientUuid];
    if (existing != null) return _byServerId[existing]!;
    final serverId = '${_nextId++}';
    final stored = HerdModel(
      id: serverId,
      clientUuid: herd.clientUuid,
      userId: herd.userId,
      name: herd.name,
      animalTypeId: herd.animalTypeId,
      location: herd.location,
      initialHeadCount: herd.initialHeadCount,
      currentHeadCount: herd.currentHeadCount,
      startDate: herd.startDate,
      endDate: herd.endDate,
      createdAt: herd.createdAt,
      updatedAt: herd.updatedAt,
    );
    _byServerId[serverId] = stored;
    _serverIdByClientUuid[herd.clientUuid] = serverId;
    return stored;
  }

  @override
  Future<HerdModel> updateHerd(HerdModel herd) async => herd;

  @override
  Future<void> deleteHerd(String id) async {}

  @override
  Future<List<HerdModel>> getHerds({DateTime? updatedSince}) async =>
      allRows;
}

class _FakeAnimalRemoteDataSource implements AnimalRemoteDataSource {
  _FakeAnimalRemoteDataSource(this._log);
  final List<String> _log;
  final Map<String, AnimalModel> _byServerId = {};
  final Map<String, String> _serverIdByClientUuid = {};
  int _nextId = 400;

  List<AnimalModel> get allRows => List.unmodifiable(_byServerId.values);
  String? serverIdFor(String clientUuid) => _serverIdByClientUuid[clientUuid];

  @override
  Future<AnimalModel> addAnimal(AnimalModel animal) async {
    _log.add('animal:${animal.clientUuid}');
    final existing = _serverIdByClientUuid[animal.clientUuid];
    if (existing != null) return _byServerId[existing]!;
    final serverId = '${_nextId++}';
    final stored = AnimalModel(
      id: serverId,
      clientUuid: animal.clientUuid,
      userId: animal.userId,
      name: animal.name,
      animalTypeId: animal.animalTypeId,
      herdId: animal.herdId,
      birthDate: animal.birthDate,
      sex: animal.sex,
      acquisitionSource: animal.acquisitionSource,
      createdAt: animal.createdAt,
      updatedAt: animal.updatedAt,
    );
    _byServerId[serverId] = stored;
    _serverIdByClientUuid[animal.clientUuid] = serverId;
    return stored;
  }

  @override
  Future<AnimalModel> updateAnimal(AnimalModel animal) async => animal;

  @override
  Future<void> deleteAnimal(String id) async {}

  @override
  Future<List<AnimalModel>> getAnimals({DateTime? updatedSince}) async =>
      allRows;
}

class _FakeHerdActivityRemoteDataSource
    implements HerdActivityRemoteDataSource {
  _FakeHerdActivityRemoteDataSource(this._log);
  final List<String> _log;

  /// The `herdId` URL param every [addHerdActivity] call received, in order
  /// — proves whether the syncer translated it to the herd's SERVER id.
  final List<String> receivedHerdIds = <String>[];

  /// The raw model body every [addHerdActivity] call received, in order —
  /// proves it still carries `client_uuid` (this fake bypasses the real
  /// Dio-based wire/JSON layer, so the closest equivalent to "the wire body
  /// includes client_uuid" at this boundary is "the model handed to the
  /// remote adapter carries its client_uuid").
  final List<HerdActivityModel> receivedBodies = <HerdActivityModel>[];
  int _nextId = 500;

  @override
  Future<HerdActivityModel> addHerdActivity(
    String herdId,
    HerdActivityModel activity,
  ) async {
    _log.add('herd_activity:${activity.clientUuid}');
    receivedHerdIds.add(herdId);
    receivedBodies.add(activity);
    final serverId = '${_nextId++}';
    return HerdActivityModel(
      id: serverId,
      clientUuid: activity.clientUuid,
      herdId: herdId,
      activityType: activity.activityType,
      count: activity.count,
      date: activity.date,
      notes: activity.notes,
      createdAt: activity.createdAt,
    );
  }
}

class _FakeInputRemoteDataSource implements InputRemoteDataSource {
  _FakeInputRemoteDataSource(this._log);
  final List<String> _log;
  final Map<String, InputModel> _byServerId = {};
  final Map<String, String> _serverIdByClientUuid = {};
  int _nextId = 700;

  List<InputModel> get allRows => List.unmodifiable(_byServerId.values);

  @override
  Future<InputModel> addInput(InputModel input) async {
    _log.add('input:${input.clientUuid}');
    final existing = _serverIdByClientUuid[input.clientUuid];
    if (existing != null) return _byServerId[existing]!;
    final serverId = '${_nextId++}';
    final stored = InputModel(
      id: serverId,
      clientUuid: input.clientUuid,
      sourceType: input.sourceType,
      sourceId: input.sourceId,
      animalId: input.animalId,
      type: input.type,
      quantity: input.quantity,
      cost: input.cost,
      date: input.date,
      notes: input.notes,
      createdAt: input.createdAt,
      updatedAt: input.updatedAt,
    );
    _byServerId[serverId] = stored;
    _serverIdByClientUuid[input.clientUuid] = serverId;
    return stored;
  }

  @override
  Future<InputModel> updateInput(InputModel input) async => input;

  @override
  Future<void> deleteInput(String id) async {}

  @override
  Future<List<InputModel>> getInputs({
    String? sourceType,
    DateTime? updatedSince,
    int? limit,
    int? cursor,
  }) async => allRows;
}

/// Controllable fake of [ConnectivityService] — always online here (this
/// file drives every write directly through `local.upsert`+`outbox.enqueue`,
/// never through a repository's fire-and-forget `syncNow()`, so there is no
/// premature-sync race to guard against by flipping it offline first).
class _FakeConnectivityService implements ConnectivityService {
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => const Stream<bool>.empty();
}

/// Wires every REAL offline-first collaborator for all 7 entities this file
/// touches around one in-memory [AppDatabase] — the same shape as
/// `injection_container.dart`'s real wiring (one `SyncEngine`, `fkStores`
/// shared with the resolver's prior-pass fallback) — plus the fakes at the
/// network boundary.
class _Harness {
  _Harness() : db = AppDatabase.forTesting(NativeDatabase.memory()) {
    plantLocal = PlantLocalDataSource(db);
    seasonLocal = SeasonLocalDataSource(db);
    harvestLocal = HarvestLocalDataSource(db);
    animalTypeLocal = AnimalTypeLocalDataSource(db);
    herdLocal = HerdLocalDataSource(db);
    animalLocal = AnimalLocalDataSource(db);
    herdActivityLocal = HerdActivityLocalDataSource(db);
    inputLocal = InputLocalDataSource(db);

    outbox = OutboxDao(db);
    cursors = SyncCursorDao(db);
    connectivity = _FakeConnectivityService();

    plantRemote = _FakePlantRemoteDataSource(serverCalls);
    seasonRemote = _FakeSeasonRemoteDataSource(serverCalls);
    harvestRemote = _FakeHarvestRemoteDataSource(serverCalls);
    animalTypeRemote = _FakeAnimalTypeRemoteDataSource(serverCalls);
    herdRemote = _FakeHerdRemoteDataSource(serverCalls);
    animalRemote = _FakeAnimalRemoteDataSource(serverCalls);
    herdActivityRemote = _FakeHerdActivityRemoteDataSource(serverCalls);
    inputRemote = _FakeInputRemoteDataSource(serverCalls);

    final fkStores = <String, LocalSyncStore<SyncableModel>>{
      'plant': plantLocal,
      'season': seasonLocal,
      'harvest': harvestLocal,
      'animal_type': animalTypeLocal,
      'herd': herdLocal,
      'animal': animalLocal,
      'herd_activity': herdActivityLocal,
      'input': inputLocal,
    };

    engine = SyncEngine(
      outbox: outbox,
      syncers: [
        PlantSyncer(remote: plantRemote, local: plantLocal),
        SeasonSyncer(remote: seasonRemote, local: seasonLocal),
        HarvestSyncer(remote: harvestRemote, local: harvestLocal),
        AnimalTypeSyncer(remote: animalTypeRemote, local: animalTypeLocal),
        HerdSyncer(remote: herdRemote, local: herdLocal),
        AnimalSyncer(remote: animalRemote, local: animalLocal),
        HerdActivitySyncer(
          remote: herdActivityRemote,
          local: herdActivityLocal,
        ),
        InputSyncer(remote: inputRemote, local: inputLocal),
      ],
      cursors: cursors,
      connectivity: connectivity,
      fkStores: fkStores,
    );
  }

  final AppDatabase db;

  /// Every `'<entity>:<client_uuid>'` create call, across every fake, in the
  /// order the engine actually issued them — proves cross-entity FIFO.
  final List<String> serverCalls = <String>[];

  late final PlantLocalDataSource plantLocal;
  late final SeasonLocalDataSource seasonLocal;
  late final HarvestLocalDataSource harvestLocal;
  late final AnimalTypeLocalDataSource animalTypeLocal;
  late final HerdLocalDataSource herdLocal;
  late final AnimalLocalDataSource animalLocal;
  late final HerdActivityLocalDataSource herdActivityLocal;
  late final InputLocalDataSource inputLocal;

  late final OutboxDao outbox;
  late final SyncCursorDao cursors;
  late final _FakeConnectivityService connectivity;

  late final _FakePlantRemoteDataSource plantRemote;
  late final _FakeSeasonRemoteDataSource seasonRemote;
  late final _FakeHarvestRemoteDataSource harvestRemote;
  late final _FakeAnimalTypeRemoteDataSource animalTypeRemote;
  late final _FakeHerdRemoteDataSource herdRemote;
  late final _FakeAnimalRemoteDataSource animalRemote;
  late final _FakeHerdActivityRemoteDataSource herdActivityRemote;
  late final _FakeInputRemoteDataSource inputRemote;

  late final SyncEngine engine;

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}

// --- Model builders: thin wrappers over each entity's `.create()` factory
// with a caller-supplied `clientUuid` (so a child's FK field can reference a
// parent's uuid before the parent even syncs) and sensible fixed defaults
// for everything this file doesn't care about.

PlantModel _plant(String clientUuid, {String name = 'Maize'}) =>
    PlantModel.create(userId: 'user-1', name: name, clientUuid: clientUuid);

SeasonModel _season(
  String clientUuid, {
  required String plantId,
  String landId = '601',
  String name = 'Long Rains',
}) => SeasonModel.create(
  userId: 'user-1',
  name: name,
  plantId: plantId,
  landId: landId,
  startDate: DateTime.utc(2026),
  clientUuid: clientUuid,
);

HarvestModel _harvest(
  String clientUuid, {
  required String seasonId,
  double quantity = 12,
}) => HarvestModel.create(
  seasonId: seasonId,
  quantity: quantity,
  unit: 'kg',
  date: DateTime.utc(2026),
  clientUuid: clientUuid,
);

AnimalTypeModel _animalType(String clientUuid, {String name = 'Dairy Cow'}) =>
    AnimalTypeModel.create(
      userId: 'user-1',
      name: name,
      clientUuid: clientUuid,
    );

HerdModel _herd(
  String clientUuid, {
  required String animalTypeId,
  String name = 'North Herd',
}) => HerdModel.create(
  userId: 'user-1',
  name: name,
  animalTypeId: animalTypeId,
  location: 'North field',
  initialHeadCount: 10,
  startDate: DateTime.utc(2026),
  clientUuid: clientUuid,
);

AnimalModel _animal(
  String clientUuid, {
  required String animalTypeId,
  required String herdId,
  String name = 'Bessie',
}) => AnimalModel.create(
  userId: 'user-1',
  name: name,
  animalTypeId: animalTypeId,
  herdId: herdId,
  birthDate: DateTime.utc(2025),
  clientUuid: clientUuid,
);

HerdActivityModel _herdActivity(String clientUuid, {required String herdId}) =>
    HerdActivityModel.create(
      herdId: herdId,
      activityType: 'birth',
      count: 2,
      date: DateTime.utc(2026),
      clientUuid: clientUuid,
    );

InputModel _input(
  String clientUuid, {
  required String sourceId,
  String sourceType = 'plant',
}) => InputModel.create(
  sourceType: sourceType,
  sourceId: sourceId,
  type: 'fertilizer',
  cost: 25.5,
  date: DateTime.utc(2026),
  clientUuid: clientUuid,
);

/// Stages exactly what `OfflineRepositoryMixin.stageWrite` does (see the
/// file doc comment for why this file calls it directly instead of going
/// through a repository): upsert [model] into [local] as a pending row,
/// then enqueue a `create` intent on the outbox — WITHOUT the fire-and-forget
/// `syncNow()` kick, since every test here drives `syncNow()` explicitly to
/// control exactly how many passes run.
Future<void> _stage<M extends SyncableModel>(
  _Harness h,
  LocalSyncStore<M> local,
  String entity,
  M model,
  Map<String, dynamic> json,
) async {
  await local.upsert(model, pending: true);
  await h.outbox.enqueue(
    OutboxIntent(
      op: OutboxOp.create,
      entity: entity,
      clientUuid: model.syncClientUuid,
      payload: jsonEncode(json),
    ),
  );
}

void main() {
  late _Harness h;

  setUp(() {
    h = _Harness();
    OfflineConfig.enabled = true;
  });

  tearDown(() async {
    OfflineConfig.enabled = false;
    await h.dispose();
  });

  test(
    'Step 1: plant -> season chain — the plant is posted first and returns '
    'a server id; the season create carries that server id as plant_id '
    '(not the client uuid); both rows reconcile in one pass',
    () async {
      final plant = _plant('plant-P');
      await _stage(h, h.plantLocal, 'plant', plant, plant.toJson());

      final season = _season('season-S', plantId: plant.clientUuid);
      await _stage(h, h.seasonLocal, 'season', season, season.toJson());

      await h.engine.syncNow();

      // FIFO: plant posted before season.
      expect(h.serverCalls, ['plant:plant-P', 'season:season-S']);

      final plantServerId = h.plantRemote.serverIdFor('plant-P');
      expect(plantServerId, '100');

      expect(h.seasonRemote.allRows, hasLength(1));
      final pushedSeason = h.seasonRemote.allRows.single;
      expect(pushedSeason.plantId, plantServerId);
      expect(
        int.tryParse(pushedSeason.plantId),
        isNotNull,
        reason: 'the wire carries the resolved server id, not the uuid',
      );

      final localPlant = await h.plantLocal.getByClientUuid('plant-P');
      final localSeason = await h.seasonLocal.getByClientUuid('season-S');
      expect(localPlant, isNotNull);
      expect(localPlant!.id, plantServerId);
      expect(localPlant.pending, isFalse);
      expect(localSeason, isNotNull);
      expect(localSeason!.id, isNotEmpty);
      expect(localSeason.pending, isFalse);

      expect(await h.outbox.peekAll(), isEmpty);
    },
  );

  test(
    "Step 2: animal_type -> herd -> animal two-level chain — every child's "
    "FK resolves to its parent's server id in the received bodies; all "
    'three reconcile in one pass',
    () async {
      final animalType = _animalType('at-AT');
      await _stage(
        h,
        h.animalTypeLocal,
        'animal_type',
        animalType,
        animalType.toJson(),
      );

      final herd = _herd('herd-H', animalTypeId: animalType.clientUuid);
      await _stage(h, h.herdLocal, 'herd', herd, herd.toJson());

      final animal = _animal(
        'animal-AN',
        animalTypeId: animalType.clientUuid,
        herdId: herd.clientUuid,
      );
      await _stage(h, h.animalLocal, 'animal', animal, animal.toJson());

      await h.engine.syncNow();

      // FIFO: animal_type, then herd, then animal.
      expect(h.serverCalls, [
        'animal_type:at-AT',
        'herd:herd-H',
        'animal:animal-AN',
      ]);

      final atServerId = h.animalTypeRemote.serverIdFor('at-AT');
      final herdServerId = h.herdRemote.serverIdFor('herd-H');
      expect(atServerId, '200');
      expect(herdServerId, '300');

      final pushedHerd = h.herdRemote.allRows.single;
      expect(pushedHerd.animalTypeId, atServerId);

      final pushedAnimal = h.animalRemote.allRows.single;
      expect(pushedAnimal.animalTypeId, atServerId);
      expect(pushedAnimal.herdId, herdServerId);

      final localAt = await h.animalTypeLocal.getByClientUuid('at-AT');
      final localHerd = await h.herdLocal.getByClientUuid('herd-H');
      final localAnimal = await h.animalLocal.getByClientUuid('animal-AN');
      expect(localAt!.id, atServerId);
      expect(localAt.pending, isFalse);
      expect(localHerd!.id, herdServerId);
      expect(localHerd.pending, isFalse);
      expect(localAnimal!.id, isNotEmpty);
      expect(localAnimal.pending, isFalse);

      expect(await h.outbox.peekAll(), isEmpty);
    },
  );

  test(
    'Step 3: herd -> herd_activity — the nested create URL carries the '
    "herd's translated SERVER id and the body still carries client_uuid",
    () async {
      // animalTypeId '900' is an already-synced numeric parent, out of
      // scope here — herd's OWN FK chain is Step 2's concern.
      final herd = _herd('herd-H3', animalTypeId: '900');
      await _stage(h, h.herdLocal, 'herd', herd, herd.toJson());

      final activity = _herdActivity('ha-1', herdId: herd.clientUuid);
      await _stage(
        h,
        h.herdActivityLocal,
        'herd_activity',
        activity,
        activity.toJson(),
      );

      await h.engine.syncNow();

      expect(h.serverCalls, ['herd:herd-H3', 'herd_activity:ha-1']);

      final herdServerId = h.herdRemote.serverIdFor('herd-H3');
      expect(herdServerId, '300');

      // The nested URL's herdId param is the translated SERVER id.
      expect(h.herdActivityRemote.receivedHerdIds, [herdServerId]);
      // The body handed to the remote adapter still carries client_uuid.
      expect(h.herdActivityRemote.receivedBodies.single.clientUuid, 'ha-1');

      final localHerd = await h.herdLocal.getByClientUuid('herd-H3');
      final localActivity = await h.herdActivityLocal.getByClientUuid('ha-1');
      expect(localHerd!.id, herdServerId);
      expect(localActivity, isNotNull);
      expect(localActivity!.id, isNotEmpty);
      expect(localActivity.pending, isFalse);

      expect(await h.outbox.peekAll(), isEmpty);
    },
  );

  test(
    "Step 4: season -> input polymorphic 'plant' source — the input "
    "create's source_id resolves to the season's server id (an int, not "
    'the uuid)',
    () async {
      final season = _season('season-S4', plantId: '501');
      await _stage(h, h.seasonLocal, 'season', season, season.toJson());

      final input = _input('input-I4', sourceId: season.clientUuid);
      await _stage(h, h.inputLocal, 'input', input, input.toJson());

      await h.engine.syncNow();

      expect(h.serverCalls, ['season:season-S4', 'input:input-I4']);

      final seasonServerId = h.seasonRemote.serverIdFor('season-S4');
      expect(seasonServerId, '600');

      final pushedInput = h.inputRemote.allRows.single;
      expect(pushedInput.sourceId, seasonServerId);
      expect(
        int.tryParse(pushedInput.sourceId),
        isNotNull,
        reason: 'the wire carries the resolved server id, not the uuid',
      );

      final localInput = await h.inputLocal.getByClientUuid('input-I4');
      expect(localInput, isNotNull);
      expect(localInput!.id, isNotEmpty);
      expect(localInput.pending, isFalse);

      expect(await h.outbox.peekAll(), isEmpty);
    },
  );

  test(
    'Step 5: parking across passes — a child whose parent is missing from '
    'both the outbox and the local mirror parks (stays pending, attempts '
    'bumped, NO backoff scheduled); once the parent is added it eventually '
    'syncs and the child resolves against it',
    () async {
      // Seed ONLY the child: `season.plantId` references a plant client_uuid
      // that is NEITHER in the outbox NOR in the local mirror.
      const missingPlantUuid = 'plant-P5-not-yet-created';
      final season = _season('season-S5', plantId: missingPlantUuid);
      await _stage(h, h.seasonLocal, 'season', season, season.toJson());

      // --- Pass 1: parked. ---
      await h.engine.syncNow();

      expect(
        h.seasonRemote.allRows,
        isEmpty,
        reason: 'never sent — the parent has no server id to resolve to',
      );
      expect(h.serverCalls, isEmpty);

      var rows = await h.outbox.peekAll();
      expect(rows, hasLength(1));
      expect(rows.single.entity, 'season');
      expect(rows.single.state, 'pending', reason: 'parked, not failed');
      expect(rows.single.attempts, 1);
      expect(
        h.engine.status.phase,
        SyncPhase.idle,
        reason: 'parking is not a failure — no backoff retry is scheduled',
      );

      final seasonAfterPass1 = await h.seasonLocal.getByClientUuid(
        'season-S5',
      );
      expect(seasonAfterPass1!.pending, isTrue);
      expect(seasonAfterPass1.id, isEmpty);

      // --- The parent's create finally arrives. It's enqueued AFTER the
      // child, so it lands at a LATER outbox seq than the child's
      // already-pending row: this next pass still processes the child
      // FIRST (it parks yet again — the parent hasn't pushed yet at that
      // point in the SAME pass), then pushes the parent, which succeeds. ---
      final plant = _plant(missingPlantUuid);
      await _stage(h, h.plantLocal, 'plant', plant, plant.toJson());

      await h.engine.syncNow(); // pass 2

      final plantServerId = h.plantRemote.serverIdFor(missingPlantUuid);
      expect(
        plantServerId,
        isNotNull,
        reason: 'the parent itself synced this pass',
      );
      expect(
        h.seasonRemote.allRows,
        isEmpty,
        reason:
            'still not sent — FIFO means the child (older seq) was '
            'retried BEFORE the just-added parent within this same pass',
      );

      rows = await h.outbox.peekAll();
      expect(rows, hasLength(1));
      expect(rows.single.entity, 'season');
      expect(rows.single.state, 'pending');
      expect(rows.single.attempts, 2);

      // --- Pass 3: the parent's server id is now in the local mirror (set
      // during pass 2), so the resolver's prior-pass fallback finds it and
      // the child finally syncs. ---
      await h.engine.syncNow();

      expect(h.seasonRemote.allRows, hasLength(1));
      final pushedSeason = h.seasonRemote.allRows.single;
      expect(pushedSeason.plantId, plantServerId);

      final seasonFinal = await h.seasonLocal.getByClientUuid('season-S5');
      expect(seasonFinal!.id, isNotEmpty);
      expect(seasonFinal.pending, isFalse);
      expect(await h.outbox.peekAll(), isEmpty);
    },
  );

  test(
    'Step 6: season -> harvest LOCAL FK reconcile (P5) — after the season '
    "syncs, the local harvest row carries the season's SERVER id (not its "
    'client uuid), so watchHarvests(seasonId: <server-id>) matches; the wire '
    'also carries the resolved server id',
    () async {
      // plantId '501' is an already-synced numeric parent, out of scope
      // here — the season's OWN FK chain is Step 1's concern.
      final season = _season('season-S6', plantId: '501');
      await _stage(h, h.seasonLocal, 'season', season, season.toJson());

      final harvest = _harvest('harvest-H6', seasonId: season.clientUuid);
      await _stage(h, h.harvestLocal, 'harvest', harvest, harvest.toJson());

      await h.engine.syncNow();

      // FIFO: season posted before harvest.
      expect(h.serverCalls, ['season:season-S6', 'harvest:harvest-H6']);

      final seasonServerId = h.seasonRemote.serverIdFor('season-S6');
      expect(seasonServerId, '600');

      // The wire body carries the RESOLVED numeric season id, not the uuid.
      final pushedHarvest = h.harvestRemote.allRows.single;
      expect(pushedHarvest.seasonId, seasonServerId);
      expect(
        int.tryParse(pushedHarvest.seasonId),
        isNotNull,
        reason: 'the wire carries the resolved server id, not the uuid',
      );

      // The crux (P5): the LOCAL harvest row now carries the season's SERVER
      // id in its `seasonId` FK — no longer the season's client_uuid.
      final localHarvest = await h.harvestLocal.getByClientUuid('harvest-H6');
      expect(localHarvest, isNotNull);
      expect(localHarvest!.seasonId, seasonServerId);
      expect(localHarvest.id, isNotEmpty, reason: 'own serverId reconciled');
      expect(localHarvest.pending, isFalse);

      // A filter by the season's SERVER id includes the harvest...
      final byServerId = await h.harvestLocal
          .watchHarvests(seasonId: seasonServerId)
          .first;
      expect(byServerId.map((m) => m.clientUuid), ['harvest-H6']);

      // ...and the stale client_uuid no longer matches anything.
      final byClientUuid = await h.harvestLocal
          .watchHarvests(seasonId: season.clientUuid)
          .first;
      expect(byClientUuid, isEmpty);

      expect(await h.outbox.peekAll(), isEmpty);
    },
  );

  test(
    'Step 6b: the local harvest FK is reconciled the instant the SEASON '
    'syncs — even when the harvest itself never pushed (not enqueued) and no '
    'pull ran to bring it back; this is the window (A) at harvest-push time '
    'cannot close',
    () async {
      // A harvest staged into the local mirror ONLY (pending), referencing
      // the season's client_uuid — deliberately NOT enqueued on the outbox,
      // so it never pushes and is never pulled back. The ONLY thing that can
      // reconcile its FK is the season's push-ack cascade.
      final season = _season('season-S6b', plantId: '501');
      final harvest = _harvest('harvest-H6b', seasonId: season.clientUuid);
      await h.harvestLocal.upsert(harvest, pending: true);

      // Only the season is staged + synced.
      await _stage(h, h.seasonLocal, 'season', season, season.toJson());
      await h.engine.syncNow();

      final seasonServerId = h.seasonRemote.serverIdFor('season-S6b');
      expect(seasonServerId, isNotNull);

      // The harvest never reached the server this pass.
      expect(h.harvestRemote.allRows, isEmpty);
      expect(h.serverCalls, ['season:season-S6b']);

      // Yet its local FK was rewritten to the season's server id the instant
      // the season's setServerId ran (the cascade) — so the filter matches
      // without waiting on the harvest's own push or a pull-back.
      final localHarvest = await h.harvestLocal.getByClientUuid('harvest-H6b');
      expect(localHarvest, isNotNull);
      expect(localHarvest!.seasonId, seasonServerId);
      // Pure FK reconcile: the harvest's own sync state is left untouched.
      expect(localHarvest.pending, isTrue);
      expect(localHarvest.id, isEmpty, reason: 'harvest itself still unsynced');

      final byServerId = await h.harvestLocal
          .watchHarvests(seasonId: seasonServerId)
          .first;
      expect(byServerId.map((m) => m.clientUuid), ['harvest-H6b']);
    },
  );
}
