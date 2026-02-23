import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_todo/main.dart';
import 'package:simple_todo/services/service_locator.dart';
import 'package:simple_todo/data/data_manager.dart';

void main() {
  testWidgets('App compiles and runs smoke test', (WidgetTester tester) async {
    // Mock shared preferences for the test environment
    SharedPreferences.setMockInitialValues({});

    // Initialize our service locator
    if (!getIt.isRegistered<DataManager>()) {
      await setupServiceLocator();
    }

    // Build our app and trigger a frame.
    await tester.pumpWidget(const SimpleTodoApp());

    // Verify that the app renders the main widget tree
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
