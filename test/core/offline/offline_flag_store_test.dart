import 'package:farm_tracker/core/offline/offline_flag_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OfflineFlagStore', () {
    test('read defaults to false when nothing was ever persisted', () async {
      SharedPreferences.setMockInitialValues({});
      const store = OfflineFlagStore();

      expect(await store.read(), isFalse);
    });

    test('write then read round-trips true', () async {
      SharedPreferences.setMockInitialValues({});
      const store = OfflineFlagStore();

      await store.write(value: true);

      expect(await store.read(), isTrue);
    });

    test('write then read round-trips false (explicit rollback)', () async {
      SharedPreferences.setMockInitialValues({'offline_enabled': true});
      const store = OfflineFlagStore();

      await store.write(value: false);

      expect(await store.read(), isFalse);
    });

    test('read reflects whatever was already persisted under the key', () async {
      SharedPreferences.setMockInitialValues({'offline_enabled': true});
      const store = OfflineFlagStore();

      expect(await store.read(), isTrue);
    });
  });
}
