import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:farm_tracker/features/billing/data/models/entitlement_model.dart';
import 'package:farm_tracker/features/billing/presentation/cubit/entitlement_cubit.dart';
import 'package:farm_tracker/features/billing/presentation/pages/paywall_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements BillingRemoteDataSource {}

EntitlementModel _free() => EntitlementModel.fromJson(const {
  'state': 'free',
  'can_write': true,
  'is_owner': true,
  'collaborators': 1,
  'seats_paid': 0,
  'seat_cap': 20,
  'price_kes': 700,
  'base_kes': 500,
  'per_collaborator_kes': 200,
  'ai_questions_per_day': 3,
});

Future<void> _pump(WidgetTester tester, _MockRemote remote) async {
  when(() => remote.getEntitlement()).thenAnswer((_) async => _free());
  final cubit = EntitlementCubit(remote: remote);
  await cubit.load();
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: PaywallPage(remote: remote),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _MockRemote remote;

  setUp(() {
    remote = _MockRemote();
    registerFallbackValue(0);
  });

  testWidgets('leads with the free offer, not the price', (tester) async {
    await _pump(tester, remote);

    expect(find.textContaining('free for your own farms'), findsOneWidget);
  });

  testWidgets('shows the computed price for the current team size, not the '
      'formula', (tester) async {
    await _pump(tester, remote);

    // One collaborator: 500 + 200.
    expect(find.textContaining('700'), findsWidgets);
  });

  testWidgets('the price follows the seat picker', (tester) async {
    await _pump(tester, remote);

    await tester.tap(find.byTooltip('Add a person'));
    await tester.pumpAndSettle();

    // Two collaborators: 500 + 400.
    expect(find.textContaining('900'), findsWidgets);
  });

  testWidgets('cannot go below one collaborator', (tester) async {
    await _pump(tester, remote);

    await tester.tap(find.byTooltip('Remove a person'));
    await tester.pumpAndSettle();

    expect(find.textContaining('700'), findsWidgets);
  });

  testWidgets('requires a phone number before paying', (tester) async {
    await _pump(tester, remote);

    await tester.tap(find.text('Pay with M-Pesa'));
    await tester.pumpAndSettle();

    expect(find.textContaining('M-Pesa number'), findsWidgets);
    verifyNever(
      () => remote.checkout(
        seats: any(named: 'seats'),
        months: any(named: 'months'),
        phone: any(named: 'phone'),
      ),
    );
  });

  testWidgets('a second tap while the first is in flight starts no second '
      'charge', (tester) async {
    await _pump(tester, remote);
    when(
      () => remote.checkout(
        seats: any(named: 'seats'),
        months: any(named: 'months'),
        phone: any(named: 'phone'),
      ),
    ).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return const CheckoutResult(reference: 'r1', amountKes: 700);
    });

    await tester.enterText(find.byType(TextField).first, '0722000000');
    await tester.pump();

    await tester.tap(find.text('Pay with M-Pesa'));
    await tester.pump();
    // The label is swapped for a spinner while in flight, so target the button.
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pumpAndSettle();

    verify(
      () => remote.checkout(
        seats: any(named: 'seats'),
        months: any(named: 'months'),
        phone: any(named: 'phone'),
      ),
    ).called(1);
  });

  testWidgets('tells the farmer to check their phone once the push is sent', (
    tester,
  ) async {
    await _pump(tester, remote);
    when(
      () => remote.checkout(
        seats: any(named: 'seats'),
        months: any(named: 'months'),
        phone: any(named: 'phone'),
      ),
    ).thenAnswer(
      (_) async => const CheckoutResult(reference: 'r1', amountKes: 700),
    );

    await tester.enterText(find.byType(TextField).first, '0722000000');
    await tester.pump();
    await tester.tap(find.text('Pay with M-Pesa'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Check your phone'), findsOneWidget);
  });

  testWidgets('a failed checkout says so and re-enables the button', (
    tester,
  ) async {
    await _pump(tester, remote);
    when(
      () => remote.checkout(
        seats: any(named: 'seats'),
        months: any(named: 'months'),
        phone: any(named: 'phone'),
      ),
    ).thenThrow(const ServerException('we could not reach M-Pesa'));

    await tester.enterText(find.byType(TextField).first, '0722000000');
    await tester.pump();
    await tester.tap(find.text('Pay with M-Pesa'));
    await tester.pumpAndSettle();

    expect(find.textContaining('could not'), findsWidgets);
    expect(find.text('Pay with M-Pesa'), findsOneWidget);
  });

  testWidgets('a year costs ten months, not twelve', (tester) async {
    await _pump(tester, remote);

    await tester.tap(find.text('1 year'));
    await tester.pumpAndSettle();

    expect(find.textContaining('KES 7000 for a year'), findsOneWidget);
    expect(find.textContaining('8400'), findsNothing);
  });
}
