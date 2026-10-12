import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:farm_tracker/features/billing/data/models/entitlement_model.dart';
import 'package:farm_tracker/features/billing/domain/entities/entitlement.dart';
import 'package:farm_tracker/features/billing/presentation/cubit/entitlement_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements BillingRemoteDataSource {}

EntitlementModel _lapsed() => EntitlementModel.fromJson(const {
  'state': 'lapsed',
  'can_write': false,
  'is_owner': false,
  'collaborators': 2,
  'seats_paid': 2,
  'seat_cap': 20,
  'price_kes': 900,
  'base_kes': 500,
  'per_collaborator_kes': 200,
  'ai_questions_per_day': 3,
});

void main() {
  late _MockRemote remote;

  setUp(() => remote = _MockRemote());

  test('starts permissive, so nothing is gated before the first load', () {
    final cubit = EntitlementCubit(remote: remote);

    expect(cubit.state.entitlement.canWrite, isTrue);
    expect(cubit.state.loading, isFalse);
  });

  test('load() publishes what the server said', () async {
    when(() => remote.getEntitlement()).thenAnswer((_) async => _lapsed());
    final cubit = EntitlementCubit(remote: remote);

    await cubit.load();

    expect(cubit.state.entitlement.state, BillingState.lapsed);
    expect(cubit.state.entitlement.canWrite, isFalse);
    expect(cubit.state.loading, isFalse);
  });

  test('a failed load FALLS OPEN — a dropped request must never put a paying '
      'farm into read-only', () async {
    when(() => remote.getEntitlement()).thenThrow(NetworkException());
    final cubit = EntitlementCubit(remote: remote);

    await cubit.load();

    expect(
      cubit.state.entitlement.canWrite,
      isTrue,
      reason: 'falling closed on a network error is worse than no gate',
    );
    expect(cubit.state.loading, isFalse);
  });

  test('a server error also falls open', () async {
    when(
      () => remote.getEntitlement(),
    ).thenThrow(const ServerException('boom'));
    final cubit = EntitlementCubit(remote: remote);

    await cubit.load();

    expect(cubit.state.entitlement.canWrite, isTrue);
  });

  test('a failed refresh keeps the entitlement already known rather than '
      'discarding it', () async {
    when(() => remote.getEntitlement()).thenAnswer((_) async => _lapsed());
    final cubit = EntitlementCubit(remote: remote);
    await cubit.load();

    when(() => remote.getEntitlement()).thenThrow(NetworkException());
    await cubit.refresh();

    expect(
      cubit.state.entitlement.state,
      BillingState.lapsed,
      reason: 'a blip must not silently re-enable writes on a lapsed farm',
    );
  });

  test(
    'load() is not re-entrant — two simultaneous calls make one request',
    () async {
      var calls = 0;
      when(() => remote.getEntitlement()).thenAnswer((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _lapsed();
      });
      final cubit = EntitlementCubit(remote: remote);

      await Future.wait([cubit.load(), cubit.load()]);

      expect(calls, 1);
    },
  );
}
