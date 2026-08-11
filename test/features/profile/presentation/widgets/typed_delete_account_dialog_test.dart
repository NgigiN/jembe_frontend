import 'package:farm_tracker/features/profile/presentation/widgets/typed_delete_account_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpDialogHost(
    WidgetTester tester, {
    required void Function(Future<bool?> result) onOpened,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                onOpened(
                  TypedDeleteAccountDialog.show(
                    context: context,
                    title: 'Delete Account',
                    message:
                        'This permanently deletes your account and all '
                        'farm data. This cannot be undone.',
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Delete button stays disabled until DELETE is typed exactly', (
    tester,
  ) async {
    Future<bool?>? resultFuture;
    await pumpDialogHost(tester, onOpened: (result) => resultFuture = result);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final deleteButtonFinder = find.widgetWithText(TextButton, 'Delete');
    expect(tester.widget<TextButton>(deleteButtonFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    expect(tester.widget<TextButton>(deleteButtonFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    expect(
      tester.widget<TextButton>(deleteButtonFinder).onPressed,
      isNotNull,
    );

    await tester.tap(deleteButtonFinder);
    await tester.pumpAndSettle();

    expect(await resultFuture, isTrue);
  });

  testWidgets('Cancel pops false without requiring typed confirmation', (
    tester,
  ) async {
    Future<bool?>? resultFuture;
    await pumpDialogHost(tester, onOpened: (result) => resultFuture = result);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(await resultFuture, isFalse);
  });
}
