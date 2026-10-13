import 'package:farm_tracker/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:farm_tracker/features/billing/data/models/entitlement_model.dart';
import 'package:farm_tracker/features/billing/presentation/cubit/entitlement_cubit.dart';
import 'package:farm_tracker/features/billing/presentation/pages/paywall_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// The page makes no requests, so every call here is a test bug.
class _NullRemote implements BillingRemoteDataSource {
  @override
  Future<EntitlementModel> getEntitlement() => throw UnimplementedError();

  @override
  Future<CheckoutResult> checkout({
    required int seats,
    required int months,
    required String phone,
  }) => throw UnimplementedError();
}

class _StaticCubit extends EntitlementCubit {
  _StaticCubit(EntitlementStatus initial) : super(remote: _NullRemote()) {
    emit(initial);
  }
}

Future<void> _pump(WidgetTester tester, Map<String, dynamic> json) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final cubit = _StaticCubit(
    EntitlementStatus(
      entitlement: EntitlementModel.fromJson(json),
      loading: false,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<EntitlementCubit>.value(
        value: cubit,
        child: const PaywallPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers NO way to pay from inside the app', (tester) async {
    await _pump(tester, const {
      'state': 'lapsed',
      'can_write': false,
      'is_owner': true,
      'collaborators': 3,
      'seats_paid': 0,
      'seat_cap': 20,
      'price_kes': 1100,
      'base_kes': 500,
      'per_collaborator_kes': 200,
    });

    // Not a disabled button, not a hidden form: nothing a policy reviewer
    // could read as an in-app purchase flow.
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.textContaining('M-Pesa'), findsNothing);
    expect(find.textContaining('Pay'), findsNothing);
  });

  testWidgets('says what it costs and where to renew', (tester) async {
    await _pump(tester, const {
      'state': 'lapsed',
      'can_write': false,
      'is_owner': true,
      'collaborators': 3,
      'price_kes': 1100,
      'base_kes': 500,
      'per_collaborator_kes': 200,
    });

    expect(find.textContaining('1,100'), findsWidgets);
    expect(find.textContaining('farmtracker.samtama.lol'), findsOneWidget);
  });

  testWidgets('still leads with what stays free', (tester) async {
    await _pump(tester, const {
      'state': 'free',
      'can_write': true,
      'is_owner': true,
      'collaborators': 0,
      'price_kes': 0,
      'base_kes': 500,
      'per_collaborator_kes': 200,
    });

    expect(find.textContaining('free for your own farms'), findsOneWidget);
  });

  testWidgets('a COLLABORATOR sees the trimmed shape without crashing', (
    tester,
  ) async {
    // The server now withholds price_kes, collaborators and the dates from
    // non-owners, and the parser fills them with zeros. The page must never
    // turn those fallbacks into a price a worker could read.
    await _pump(tester, const {
      'state': 'lapsed',
      'can_write': false,
      'is_owner': false,
      'seat_cap': 20,
      'ai_questions_per_day': 3,
    });

    expect(tester.takeException(), isNull);
    expect(find.textContaining('KES'), findsNothing);
    expect(find.textContaining('farmtracker.samtama.lol'), findsNothing);
    expect(find.textContaining('ask the farm owner'), findsOneWidget);
  });
}
