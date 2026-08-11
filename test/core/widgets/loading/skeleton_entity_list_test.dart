import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  testWidgets(
    'renders itemCount placeholder cards wrapped in an enabled Skeletonizer',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonEntityList(itemCount: 3, icon: Icons.eco),
          ),
        ),
      );

      // Skeletonizer is an abstract class instantiated via a const factory
      // that returns a private subtype, so find.byType (exact runtimeType
      // match) won't find it - a widget predicate using `is` does.
      final skeletonizerFinder = find.byWidgetPredicate(
        (widget) => widget is Skeletonizer,
      );
      expect(skeletonizerFinder, findsOneWidget);
      expect(find.byType(EntityCard), findsNWidgets(3));

      final skeletonizer = tester.widget<Skeletonizer>(skeletonizerFinder);
      expect(skeletonizer.enabled, isTrue);
    },
  );

  testWidgets('defaults to 6 placeholder cards', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SkeletonEntityList()),
      ),
    );

    expect(find.byType(EntityCard), findsNWidgets(6));
  });
}
