import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:simple_todo/main.dart' as app;
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-end add custom ToDo item test', (
    WidgetTester tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();

    // Verify initial load by looking for the FAB
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Tap the FAB to add a new task
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Verify we are on the Editor page
    expect(find.text('Edit Item'), findsOneWidget);

    // Enter a title
    await tester.enterText(find.byType(TextField).first, 'Test JSON Saving');
    await tester.pumpAndSettle();

    // Tap the save checkmark
    await tester.tap(find.byIcon(Icons.check).last);
    await tester.pumpAndSettle();

    // Verify we are back on the List page (FAB is back)
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Give the file storage a moment to save and reload
    await Future.delayed(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Tap 'All' to ensure filter is refreshed
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // Verify the new item is listed
    expect(find.text('Test JSON Saving'), findsWidgets);

    // CLEANUP: Delete the item using the context menu
    await tester.longPress(find.text('Test JSON Saving').first);
    await tester.pumpAndSettle();

    // Tap the 'Delete' option in the popup menu
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify the item is gone
    expect(find.text('Test JSON Saving'), findsNothing);
  });
}
