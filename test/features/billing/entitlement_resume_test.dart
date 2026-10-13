import 'package:farm_tracker/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:farm_tracker/features/billing/data/models/entitlement_model.dart';
import 'package:farm_tracker/features/billing/domain/entities/entitlement.dart';
import 'package:farm_tracker/features/billing/presentation/cubit/entitlement_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements BillingRemoteDataSource {}

EntitlementModel _of(Map<String, dynamic> json) =>
    EntitlementModel.fromJson(json);

void main() {
  test('a resume picks up a payment made elsewhere', () async {
    // The console unlocked the plan while the phone was in a pocket. The
    // handset must reflect that on resume, without a restart.
    final remote = _MockRemote();
    var call = 0;
    when(remote.getEntitlement).thenAnswer((_) async {
      call++;
      return _of(
        call == 1
            ? const {'state': 'lapsed', 'can_write': false, 'is_owner': false}
            : const {'state': 'active', 'can_write': true, 'is_owner': false},
      );
    });

    final cubit = EntitlementCubit(remote: remote);
    await cubit.load();
    expect(cubit.state.entitlement.state, BillingState.lapsed);

    // What the resume handler does.
    await cubit.refresh();

    expect(
      cubit.state.entitlement.state,
      BillingState.active,
      reason: 'a resume must pick up a payment made on the console',
    );
    expect(cubit.state.entitlement.canWrite, isTrue);
  });

  test('resuming repeatedly is safe', () async {
    // Backgrounding and foregrounding an app happens constantly. Refresh must
    // tolerate being called far more often than anything changes.
    final remote = _MockRemote();
    when(remote.getEntitlement).thenAnswer(
      (_) async => _of(const {'state': 'active', 'can_write': true}),
    );
    final cubit = EntitlementCubit(remote: remote);
    for (var i = 0; i < 5; i++) {
      await cubit.refresh();
    }
    expect(cubit.state.entitlement.state, BillingState.active);
  });

  test('a resume whose request fails keeps what was already known', () async {
    // refresh(), not load(): a dropped request on resume must not fall open on
    // a farm we already know is lapsed.
    final remote = _MockRemote();
    when(remote.getEntitlement).thenAnswer(
      (_) async => _of(const {'state': 'lapsed', 'can_write': false}),
    );
    final cubit = EntitlementCubit(remote: remote);
    await cubit.load();

    when(remote.getEntitlement).thenThrow(Exception('offline'));
    await cubit.refresh();

    expect(
      cubit.state.entitlement.state,
      BillingState.lapsed,
      reason: 'a failed resume refresh must not re-enable writing',
    );
  });
}
