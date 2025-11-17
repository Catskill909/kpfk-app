import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:wpfw_radio/main.dart';
import 'package:wpfw_radio/core/di/service_locator.dart';

void main() {
  setUpAll(() async {
    // Initialize ServiceRegistry (new pattern)
    await setupServiceLocator();
  });

  tearDownAll(() {
    // Clean up is handled automatically by ServiceRegistry
  });

  testWidgets('WPFW Radio App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WPFWRadioApp());

    // Verify that the app title is displayed
    expect(find.text('WPFW'), findsOneWidget);

    // Verify that the play button is displayed
    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);

    // Verify that the stop button is displayed
    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
  });
}
