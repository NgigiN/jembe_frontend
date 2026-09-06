import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:farm_tracker/core/network/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  late MockConnectivity connectivity;

  setUp(() {
    connectivity = MockConnectivity();
  });

  group('ConnectivityService()', () {
    test('defaults to a real Connectivity() when none is injected', () {
      expect(ConnectivityService.new, returnsNormally);
    });
  });

  group('onlineChanges', () {
    test('emits true then false for wifi then none', () async {
      final controller = StreamController<List<ConnectivityResult>>();
      when(
        () => connectivity.onConnectivityChanged,
      ).thenAnswer((_) => controller.stream);

      final service = ConnectivityService(connectivity: connectivity);
      final emitted = <bool>[];
      final sub = service.onlineChanges.listen(emitted.add);

      controller
        ..add([ConnectivityResult.wifi])
        ..add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      await controller.close();

      expect(emitted, [true, false]);
    });

    test('treats any non-none result in the list as online', () async {
      final controller = StreamController<List<ConnectivityResult>>();
      when(
        () => connectivity.onConnectivityChanged,
      ).thenAnswer((_) => controller.stream);

      final service = ConnectivityService(connectivity: connectivity);
      final emitted = <bool>[];
      final sub = service.onlineChanges.listen(emitted.add);

      controller.add([ConnectivityResult.none, ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      await controller.close();

      expect(emitted, [true]);
    });
  });

  group('isOnline', () {
    test('is false when checkConnectivity reports only none', () async {
      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.none]);

      final service = ConnectivityService(connectivity: connectivity);

      expect(await service.isOnline(), isFalse);
    });

    test('is true when checkConnectivity reports mobile', () async {
      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.mobile]);

      final service = ConnectivityService(connectivity: connectivity);

      expect(await service.isOnline(), isTrue);
    });

    test('is true when the result list mixes wifi and none', () async {
      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.wifi, ConnectivityResult.none]);

      final service = ConnectivityService(connectivity: connectivity);

      expect(await service.isOnline(), isTrue);
    });
  });
}
