// A LogWriter with no server behind it, for previews and widget tests.
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_category.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/web_console/data/console_log_service.dart';

/// Records what a form submitted instead of sending it, so a test can
/// assert on the values the dialog actually built.
class FakeLogWriter implements LogWriter {
  FakeLogWriter({LogReference? data, this.failReference = false, this.failWrite = false})
    : data = data ?? sampleLogReference;

  final LogReference data;
  final bool failReference;
  final bool failWrite;

  final List<Map<String, Object?>> calls = [];
  int referenceLoads = 0;

  @override
  Future<LogReference> reference() async {
    referenceLoads++;
    if (failReference) throw Exception('no network');
    return data;
  }

  @override
  void invalidateReference() {}

  Future<void> _record(String kind, Map<String, Object?> values) async {
    if (failWrite) throw Exception('no network');
    calls.add({'kind': kind, ...values});
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
  }) => _record('activity', {
    'sourceType': sourceType,
    'sourceId': sourceId,
    'type': type,
    'cost': cost,
    'date': date,
    'details': details,
    'notes': notes,
  });

  @override
  Future<void> addInput({
    required String sourceType,
    required String sourceId,
    required String type,
    required double cost,
    required DateTime date,
    double? quantity,
    String? notes,
  }) => _record('input', {
    'sourceType': sourceType,
    'sourceId': sourceId,
    'type': type,
    'cost': cost,
    'date': date,
    'quantity': quantity,
    'notes': notes,
  });

  @override
  Future<void> addRevenue({
    required String source,
    required String sourceId,
    required String type,
    required double quantity,
    required double unitPrice,
    required DateTime date,
    String? notes,
  }) => _record('revenue', {
    'source': source,
    'sourceId': sourceId,
    'type': type,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'date': date,
    'notes': notes,
  });

  @override
  Future<void> addHarvest({
    required String seasonId,
    required double quantity,
    required String unit,
    required DateTime date,
    String? notes,
  }) => _record('harvest', {
    'seasonId': seasonId,
    'quantity': quantity,
    'unit': unit,
    'date': date,
    'notes': notes,
  });

  @override
  Future<void> addHerdActivity({
    required String herdId,
    required String activityType,
    required int count,
    required DateTime date,
    String? notes,
  }) => _record('herdActivity', {
    'herdId': herdId,
    'activityType': activityType,
    'count': count,
    'date': date,
    'notes': notes,
  });

  @override
  Future<void> addLand({
    required String name,
    double? size,
    String? location,
    String? soilType,
    String? tenureType,
  }) => _record('land', {
    'name': name,
    'size': size,
    'location': location,
    'soilType': soilType,
    'tenureType': tenureType,
  });

  @override
  Future<void> addPlant({required String name, String? variety}) =>
      _record('plant', {'name': name, 'variety': variety});

  @override
  Future<void> addAnimalType({required String name, String? notes}) =>
      _record('animalType', {'name': name, 'notes': notes});

  @override
  Future<void> addSeason({
    required String name,
    required String plantId,
    required String landId,
    required DateTime startDate,
    DateTime? endDate,
  }) => _record('season', {
    'name': name,
    'plantId': plantId,
    'landId': landId,
    'startDate': startDate,
    'endDate': endDate,
  });

  @override
  Future<void> addHerd({
    required String name,
    required String animalTypeId,
    required String location,
    required int initialHeadCount,
    required DateTime startDate,
  }) => _record('herd', {
    'name': name,
    'animalTypeId': animalTypeId,
    'location': location,
    'initialHeadCount': initialHeadCount,
    'startDate': startDate,
  });


}

/// The mockups' sample farm (DESIGN_SPEC §8) as a reference set.
final sampleLogReference = LogReference(
  seasons: [
    Season(
      id: 's1',
      userId: 'u1',
      name: 'Long rains 2026',
      plantId: 'p1',
      landId: 'l1',
      startDate: DateTime(2026, 3, 14),
      endDate: DateTime(2026, 9, 30),
      createdAt: DateTime(2026, 3, 14),
      updatedAt: DateTime(2026, 3, 14),
    ),
  ],
  lands: [
    Land(
      id: 'l1',
      userId: 'u1',
      name: 'West Plot',
      size: 1.2,
      location: 'Nakuru',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ],
  herds: [
    Herd(
      id: 'h1',
      userId: 'u1',
      name: 'Dairy cows',
      animalTypeId: 'a1',
      location: 'Home paddock',
      initialHeadCount: 6,
      currentHeadCount: 6,
      startDate: DateTime(2026),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ],
  plants: [
    Plant(
      id: 'pl1',
      userId: 'u1',
      name: 'Maize',
      variety: 'H614',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ],
  animalTypes: [
    AnimalType(
      id: 'at1',
      userId: 'u1',
      name: 'Dairy cow',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ],
  categories: const [
    CostCategory(id: 'c1', name: 'Weeding', type: 'plant', category: 'activity', isDefault: true),
    CostCategory(id: 'c2', name: 'Spraying', type: 'plant', category: 'activity', isDefault: true),
    CostCategory(id: 'c3', name: 'Fertilizer', type: 'plant', category: 'input', isDefault: true),
    CostCategory(id: 'c4', name: 'Feed', type: 'animal', category: 'input', isDefault: true),
    CostCategory(id: 'c5', name: 'Veterinary', type: 'animal', category: 'activity', isDefault: true),
  ],
);
