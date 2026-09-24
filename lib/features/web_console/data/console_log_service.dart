import 'package:farm_tracker/features/farm/data/datasources/activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/revenue_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/activity_model.dart';
import 'package:farm_tracker/features/farm/data/models/animal_type_model.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';
import 'package:farm_tracker/features/farm/data/models/herd_activity_model.dart';
import 'package:farm_tracker/features/farm/data/models/herd_model.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:farm_tracker/features/farm/data/models/plant_model.dart';
import 'package:farm_tracker/features/farm/data/models/revenue_model.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_category.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';

/// The lists a log form needs to fill its pickers, fetched together.
class LogReference {
  const LogReference({
    required this.seasons,
    required this.lands,
    required this.herds,
    required this.categories,
    this.plants = const [],
    this.animalTypes = const [],
  });

  const LogReference.empty()
    : seasons = const [],
      lands = const [],
      herds = const [],
      categories = const [],
      plants = const [],
      animalTypes = const [];

  final List<Season> seasons;

  /// Only so a season can be named by its plot — a season on its own reads
  /// as "Long rains 2026", which is ambiguous across two fields.
  final List<Land> lands;

  final List<Herd> herds;

  /// The farm's activity and input types, which the type field suggests
  /// from rather than making people retype "Fertilizer" every time.
  final List<CostCategory> categories;

  /// What a season can be planted with, and what a herd can be made of.
  /// Only the setup forms read these.
  final List<Plant> plants;
  final List<AnimalType> animalTypes;

  bool get hasPlantSource => seasons.isNotEmpty;
  bool get hasAnimalSource => herds.isNotEmpty;
  bool get isEmpty => seasons.isEmpty && herds.isEmpty;

  /// The category names for one kind of entry against one kind of source,
  /// e.g. the input types you can log against a herd.
  List<String> typesFor({required String category, required String source}) {
    final names = <String>{
      for (final row in categories)
        if (row.category == category && row.type == source) row.name,
    }.toList()..sort();
    return names;
  }
}

/// What a log form needs from the write path.
///
/// The dialog depends on this rather than on [ConsoleLogService] so it can
/// be rendered and driven without nine HTTP data sources behind it — the
/// preview harness and the widget tests each supply their own.
abstract interface class LogWriter {
  Future<LogReference> reference();
  void invalidateReference();

  Future<void> addActivity({
    required String sourceType,
    required String sourceId,
    required String type,
    required double cost,
    required DateTime date,
    String? details,
    String? notes,
  });

  Future<void> addInput({
    required String sourceType,
    required String sourceId,
    required String type,
    required double cost,
    required DateTime date,
    double? quantity,
    String? notes,
  });

  Future<void> addRevenue({
    required String source,
    required String sourceId,
    required String type,
    required double quantity,
    required double unitPrice,
    required DateTime date,
    String? notes,
  });

  Future<void> addHarvest({
    required String seasonId,
    required double quantity,
    required String unit,
    required DateTime date,
    String? notes,
  });

  Future<void> addHerdActivity({
    required String herdId,
    required String activityType,
    required int count,
    required DateTime date,
    String? notes,
  });

  Future<void> addLand({
    required String name,
    double? size,
    String? location,
    String? soilType,
    String? tenureType,
  });

  Future<void> addPlant({required String name, String? variety});

  Future<void> addAnimalType({required String name, String? notes});

  Future<void> addSeason({
    required String name,
    required String plantId,
    required String landId,
    required DateTime startDate,
    DateTime? endDate,
  });

  Future<void> addHerd({
    required String name,
    required String animalTypeId,
    required String location,
    required int initialHeadCount,
    required DateTime startDate,
  });
}

/// The console's write path for the things an office logs: a purchase, a
/// sale, an activity someone phoned in.
///
/// Remote-only by design. The Android app writes through the offline queue
/// so work can be logged in a field with no signal; the console is always
/// online, and a second queue here would mean two sources of truth for the
/// same row. Every call is a plain HTTP write that either lands or fails
/// in front of you.
class ConsoleLogService implements LogWriter {
  ConsoleLogService({
    required this.activities,
    required this.inputs,
    required this.revenues,
    required this.harvests,
    required this.herdActivities,
    required this.seasons,
    required this.lands,
    required this.herds,
    required this.categories,
    required this.plants,
    required this.animalTypes,
    required this.currentUserId,
  });

  final ActivityRemoteDataSource activities;
  final InputRemoteDataSource inputs;
  final RevenueRemoteDataSource revenues;
  final HarvestRemoteDataSource harvests;
  final HerdActivityRemoteDataSource herdActivities;
  final SeasonRemoteDataSource seasons;
  final LandRemoteDataSource lands;
  final HerdRemoteDataSource herds;
  final CostCategoryRemoteDataSource categories;
  final PlantRemoteDataSource plants;
  final AnimalTypeRemoteDataSource animalTypes;

  /// A plot is owned by a user, and the server expects that id on the way
  /// in. Injected rather than read from storage here so the service stays
  /// testable without a storage plugin behind it.
  final Future<String?> Function() currentUserId;

  Future<LogReference>? _pending;

  /// The pickers' contents, fetched once per session and shared by every
  /// form. Held as the in-flight future rather than the result, so opening
  /// two forms quickly issues one round of requests, not two.
  @override
  Future<LogReference> reference() => _pending ??= _loadReference();

  /// Drops the cache after something is created, so a season added on the
  /// phone shows up in the next form without a page reload.
  @override
  void invalidateReference() => _pending = null;

  Future<LogReference> _loadReference() async {
    try {
      final results = await Future.wait([
        seasons.getSeasons(),
        lands.getLands(),
        herds.getHerds(),
        categories.getCostCategories(),
        plants.getPlants(),
        animalTypes.getAnimalTypes(),
      ]);
      return LogReference(
        seasons: results[0].cast<Season>(),
        lands: results[1].cast<Land>(),
        herds: results[2].cast<Herd>(),
        categories: results[3].cast<CostCategory>(),
        plants: results[4].cast<Plant>(),
        animalTypes: results[5].cast<AnimalType>(),
      );
    } catch (_) {
      // A failed fetch must not be cached as the answer — the next form
      // should try again rather than show empty pickers forever.
      _pending = null;
      rethrow;
    }
  }

  @override
  Future<void> addActivity({
    required String sourceType,
    required String sourceId,
    required String type,
    required double cost,
    required DateTime date,
    String? details,
    String? notes,
  }) async {
    await activities.addActivity(
      ActivityModel.create(
        sourceType: sourceType,
        sourceId: sourceId,
        type: type,
        cost: cost,
        date: date,
        details: details,
        notes: notes,
      ),
    );
  }

  @override
  Future<void> addInput({
    required String sourceType,
    required String sourceId,
    required String type,
    required double cost,
    required DateTime date,
    double? quantity,
    String? notes,
  }) async {
    await inputs.addInput(
      InputModel.create(
        sourceType: sourceType,
        sourceId: sourceId,
        type: type,
        cost: cost,
        date: date,
        quantity: quantity,
        notes: notes,
      ),
    );
  }

  @override
  Future<void> addRevenue({
    required String source,
    required String sourceId,
    required String type,
    required double quantity,
    required double unitPrice,
    required DateTime date,
    String? notes,
  }) async {
    await revenues.addRevenue(
      RevenueModel.create(
        source: source,
        sourceId: sourceId,
        type: type,
        quantity: quantity,
        unitPrice: unitPrice,
        date: date,
        notes: notes,
      ),
    );
  }

  @override
  Future<void> addHarvest({
    required String seasonId,
    required double quantity,
    required String unit,
    required DateTime date,
    String? notes,
  }) async {
    await harvests.addHarvest(
      HarvestModel.create(
        seasonId: seasonId,
        quantity: quantity,
        unit: unit,
        date: date,
        notes: notes,
      ),
    );
  }

  @override
  Future<void> addHerdActivity({
    required String herdId,
    required String activityType,
    required int count,
    required DateTime date,
    String? notes,
  }) async {
    await herdActivities.addHerdActivity(
      herdId,
      HerdActivityModel.create(
        herdId: herdId,
        activityType: activityType,
        count: count,
        date: date,
        notes: notes,
      ),
    );
  }

  @override
  Future<void> addLand({
    required String name,
    double? size,
    String? location,
    String? soilType,
    String? tenureType,
  }) async {
    await lands.addLand(
      LandModel.create(
        userId: await _requireUserId(),
        name: name,
        size: size,
        location: location,
        soilType: soilType,
        tenureType: tenureType,
      ),
    );
    // The new plot belongs in the next form's season labels.
    invalidateReference();
  }

  @override
  Future<void> addPlant({required String name, String? variety}) async {
    await plants.addPlant(
      PlantModel.create(
        userId: await _requireUserId(),
        name: name,
        variety: variety,
      ),
    );
    invalidateReference();
  }

  @override
  Future<void> addAnimalType({required String name, String? notes}) async {
    await animalTypes.addAnimalType(
      AnimalTypeModel.create(
        userId: await _requireUserId(),
        name: name,
        notes: notes,
      ),
    );
    invalidateReference();
  }

  @override
  Future<void> addSeason({
    required String name,
    required String plantId,
    required String landId,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    await seasons.addSeason(
      SeasonModel.create(
        userId: await _requireUserId(),
        name: name,
        plantId: plantId,
        landId: landId,
        startDate: startDate,
        endDate: endDate,
      ),
    );
    invalidateReference();
  }

  @override
  Future<void> addHerd({
    required String name,
    required String animalTypeId,
    required String location,
    required int initialHeadCount,
    required DateTime startDate,
  }) async {
    await herds.addHerd(
      HerdModel.create(
        userId: await _requireUserId(),
        name: name,
        animalTypeId: animalTypeId,
        location: location,
        initialHeadCount: initialHeadCount,
        startDate: startDate,
      ),
    );
    invalidateReference();
  }

  /// Every setup record is owned by a user and the server expects that id.
  Future<String> _requireUserId() async {
    final userId = await currentUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('No signed-in user to own this record');
    }
    return userId;
  }
}
