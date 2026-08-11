import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';

void main() {
  group('AppRouter.sharedAxisTransition', () {
    testWidgets('wraps child in a horizontal SharedAxisTransition by default',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => AppRouter.sharedAxisTransition(
              context: context,
              animation: kAlwaysCompleteAnimation,
              secondaryAnimation: kAlwaysDismissedAnimation,
              child: const Text('page content'),
            ),
          ),
        ),
      );

      expect(find.byType(SharedAxisTransition), findsOneWidget);
      final transition =
          tester.widget<SharedAxisTransition>(find.byType(SharedAxisTransition));
      expect(transition.transitionType, SharedAxisTransitionType.horizontal);
      expect(find.text('page content'), findsOneWidget);
    });

    testWidgets('skips the transition entirely when reduced motion is on',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) => AppRouter.sharedAxisTransition(
                context: context,
                animation: kAlwaysCompleteAnimation,
                secondaryAnimation: kAlwaysDismissedAnimation,
                child: const Text('page content'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SharedAxisTransition), findsNothing);
      expect(find.text('page content'), findsOneWidget);
    });
  });

  group('AppRouter.fadeThroughTransitionBuilder', () {
    testWidgets('wraps child in a FadeThroughTransition by default',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => AppRouter.fadeThroughTransitionBuilder(
              context: context,
              animation: kAlwaysCompleteAnimation,
              secondaryAnimation: kAlwaysDismissedAnimation,
              child: const Text('tab content'),
            ),
          ),
        ),
      );

      expect(find.byType(FadeThroughTransition), findsOneWidget);
      expect(find.text('tab content'), findsOneWidget);
    });

    testWidgets('skips the transition entirely when reduced motion is on',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) => AppRouter.fadeThroughTransitionBuilder(
                context: context,
                animation: kAlwaysCompleteAnimation,
                secondaryAnimation: kAlwaysDismissedAnimation,
                child: const Text('tab content'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FadeThroughTransition), findsNothing);
      expect(find.text('tab content'), findsOneWidget);
    });
  });
}
