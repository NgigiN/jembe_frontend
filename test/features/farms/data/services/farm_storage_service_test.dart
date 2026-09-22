import 'package:farm_tracker/features/farms/data/services/farm_storage_service.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Farm _farm(int id, {bool isDefault = false, FarmRole role = FarmRole.owner}) {
  return Farm(
    id: id,
    name: 'Farm $id',
    location: '',
    fiscalYearStartMonth: 1,
    ownerUserId: 1,
    successorUserId: null,
    maxMembers: 5,
    role: role,
    memberCount: 1,
    isDefault: isDefault,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('FarmStorageService', () {
    test('round-trips farms and default farm id', () async {
      final farms = [_farm(1, isDefault: true), _farm(2)];
      await FarmStorageService.saveFarms(farms, defaultFarmId: 1);

      final stored = await FarmStorageService.getFarms();
      expect(stored.map((f) => f.id), [1, 2]);
      expect(await FarmStorageService.getDefaultFarmId(), 1);
    });

    test('getCurrentFarmId falls back to defaultFarmId when nothing was '
        'explicitly selected', () async {
      await FarmStorageService.saveFarms([_farm(1, isDefault: true)], defaultFarmId: 1);

      expect(await FarmStorageService.getCurrentFarmId(), 1);
    });

    test('getCurrentFarmId returns the explicitly selected farm once set',
        () async {
      await FarmStorageService.saveFarms(
        [_farm(1, isDefault: true), _farm(2)],
        defaultFarmId: 1,
      );
      await FarmStorageService.setCurrentFarmId(2);

      expect(await FarmStorageService.getCurrentFarmId(), 2);
    });

    test('getCurrentFarmId returns null when nothing is cached yet', () async {
      expect(await FarmStorageService.getCurrentFarmId(), isNull);
    });

    test('getCurrentRole looks up the role from the farms list entry '
        'matching the current farm id', () async {
      await FarmStorageService.saveFarms(
        [_farm(1, isDefault: true, role: FarmRole.owner), _farm(2, role: FarmRole.worker)],
        defaultFarmId: 1,
      );
      await FarmStorageService.setCurrentFarmId(2);

      expect(await FarmStorageService.getCurrentRole(), FarmRole.worker);
    });

    test('getCurrentRole returns null when no current farm is known', () async {
      expect(await FarmStorageService.getCurrentRole(), isNull);
    });

    test('clearFarmData wipes farms, default, and current selection',
        () async {
      await FarmStorageService.saveFarms([_farm(1, isDefault: true)], defaultFarmId: 1);
      await FarmStorageService.setCurrentFarmId(1);

      await FarmStorageService.clearFarmData();

      expect(await FarmStorageService.getFarms(), isEmpty);
      expect(await FarmStorageService.getDefaultFarmId(), isNull);
      expect(await FarmStorageService.getCurrentFarmId(), isNull);
    });
  });
}
