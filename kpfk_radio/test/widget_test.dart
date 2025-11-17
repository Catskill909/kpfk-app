import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kpfk_radio/main.dart';
import 'package:kpfk_radio/core/di/service_locator.dart';

void main() {
  setUpAll(() async {
    // Initialize ServiceRegistry (new pattern)
    await setupServiceLocator();
  });

  tearDownAll(() {
    // Clean up is handled automatically by ServiceRegistry
  });

  testWidgets('KPFK Radio App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const KPFKRadioApp());

    // Verify that the app title is displayed
    expect(find.text('KPFK'), findsOneWidget);

    // Verify that the play button is displayed
    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);

    // Verify that the stop button is displayed
    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
  });
}
