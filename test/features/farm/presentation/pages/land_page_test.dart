import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/land_page.dart';

class MockLandBloc extends MockBloc<LandEvent, LandState>
    implements LandBloc {}

void main() {
  testWidgets(
    'shows a skeleton (not a spinner) while lands are loading',
    (tester) async {
      final landBloc = MockLandBloc();
      whenListen(
        landBloc,
        Stream<LandState>.value(const LandLoading()),
        initialState: const LandLoading(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<LandBloc>.value(
            value: landBloc,
            child: const LandPage(),
          ),
        ),
      );

      final skeletonizerFinder = find.byWidgetPredicate(
        (widget) => widget is Skeletonizer,
      );
      expect(skeletonizerFinder, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
