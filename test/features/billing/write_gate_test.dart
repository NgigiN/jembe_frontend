import 'package:farm_tracker/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:farm_tracker/features/billing/data/models/entitlement_model.dart';
import 'package:farm_tracker/features/billing/domain/entities/entitlement.dart';
import 'package:farm_tracker/features/billing/presentation/cubit/entitlement_cubit.dart';
import 'package:farm_tracker/features/billing/presentation/widgets/write_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements BillingRemoteDataSource {}

Entitlement _of(Map<String, dynamic> json) => EntitlementModel.fromJson(json);

void main() {
  group('WriteGate.allows', () {
    test('a lapsed collaborator may not write', () {
      expect(
        WriteGate.allows(
          _of(const {'state': 'lapsed', 'can_write': false, 'is_owner': false}),
        ),
        isFalse,
      );
    });

    test('the owner of a lapsed farm may always write', () {
      expect(
        WriteGate.allows(
          _of(const {'state': 'lapsed', 'can_write': true, 'is_owner': true}),
        ),
        isTrue,
      );
    });

    test('an unknown entitlement allows writing — falling closed would cost '
        'a paying farmer their records over a dropped request', () {
      expect(WriteGate.allows(const Entitlement.permissive()), isTrue);
    });

    test('active, trialing, free and grandfathered all allow writing', () {
      for (final state in ['active', 'trialing', 'free', 'grandfathered']) {
        expect(
          WriteGate.allows(_of({'state': state, 'can_write': true})),
          isTrue,
          reason: '$state must be writable',
        );
      }
    });
  });

  testWidgets('builds with allowed=false for a lapsed collaborator', (
    tester,
  ) async {
    final remote = _MockRemote();
    final lapsed = EntitlementModel.fromJson(const {
      'state': 'lapsed',
      'can_write': false,
      'is_owner': false,
    });
    when(remote.getEntitlement).thenAnswer((_) async => lapsed);
    final cubit = EntitlementCubit(remote: remote);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: WriteGate(
            builder: (context, allowed) =>
                Text(allowed ? 'writable' : 'read-only'),
          ),
        ),
      ),
    );

    expect(find.text('read-only'), findsOneWidget);
  });

  testWidgets('a disabled button cannot be tapped, so no write is ever '
      'queued', (tester) async {
    final remote = _MockRemote();
    final lapsed = EntitlementModel.fromJson(const {
      'state': 'lapsed',
      'can_write': false,
      'is_owner': false,
    });
    when(remote.getEntitlement).thenAnswer((_) async => lapsed);
    final cubit = EntitlementCubit(remote: remote);
    await cubit.load();

    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: WriteGate(
              builder: (context, allowed) => FilledButton(
                onPressed: allowed ? () => taps++ : null,
                child: const Text('Save'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(
      taps,
      0,
      reason: 'the write must never start — a 402 would kill the outbox row',
    );
  });

  testWidgets('without an EntitlementCubit above it, allows writing '
      '(unknown falls open)', (tester) async {
    bool? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: WriteGate(
          builder: (context, allowed) {
            seen = allowed;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(seen, isTrue);
  });
}
