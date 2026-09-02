import 'package:farm_tracker/core/widgets/crud/entity_picker_with_add.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestItem {
  const _TestItem(this.id, this.label);
  final String id;
  final String label;
}

void main() {
  final items = const [
    _TestItem('1', 'Maize'),
    _TestItem('2', 'Beans'),
  ];

  Widget buildSubject({
    String? selectedId,
    ValueChanged<String?>? onChanged,
    Future<String?> Function(BuildContext)? onAddNew,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: EntityPickerWithAdd<_TestItem>(
          items: items,
          selectedId: selectedId,
          idOf: (item) => item.id,
          labelOf: (item) => item.label,
          labelText: 'Select Plant',
          onChanged: onChanged ?? (_) {},
          onAddNew: onAddNew ?? (_) async => null,
        ),
      ),
    );
  }

  testWidgets('renders a dropdown item for every entry in items', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('Maize').hitTestable(), findsOneWidget);
    expect(find.text('Beans').hitTestable(), findsOneWidget);
  });

  testWidgets('selecting a dropdown item calls onChanged with its id', (
    tester,
  ) async {
    String? changedId;
    await tester.pumpWidget(
      buildSubject(onChanged: (id) => changedId = id),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beans').hitTestable());
    await tester.pumpAndSettle();

    expect(changedId, '2');
  });

  testWidgets(
    'tapping the add button calls onAddNew and selects the returned id',
    (tester) async {
      String? changedId;
      var addNewCalled = false;
      await tester.pumpWidget(
        buildSubject(
          onChanged: (id) => changedId = id,
          onAddNew: (_) async {
            addNewCalled = true;
            return '3';
          },
        ),
      );

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      expect(addNewCalled, isTrue);
      expect(changedId, '3');
    },
  );

  testWidgets(
    'tapping the add button does not call onChanged when onAddNew returns null',
    (tester) async {
      var changedCalled = false;
      await tester.pumpWidget(
        buildSubject(
          onChanged: (_) => changedCalled = true,
          onAddNew: (_) async => null,
        ),
      );

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      expect(changedCalled, isFalse);
    },
  );

  testWidgets('passes prefixIcon through to the dropdown decoration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntityPickerWithAdd<_TestItem>(
            items: items,
            selectedId: null,
            idOf: (item) => item.id,
            labelOf: (item) => item.label,
            labelText: 'Select Herd',
            prefixIcon: const Icon(Icons.pets),
            onChanged: (_) {},
            onAddNew: (_) async => null,
          ),
        ),
      ),
    );

    final field = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    final decoration = field.decoration;
    expect(decoration.prefixIcon, isA<Icon>());
    expect((decoration.prefixIcon! as Icon).icon, Icons.pets);
  });
}
