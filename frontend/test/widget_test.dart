// Basic widget smoke test for ICMS app.
//
// Verifies the app can be instantiated without errors.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:icms/app.dart';

void main() {
  testWidgets('ICMSApp renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ICMSApp()),
    );

    // App should render — at minimum we see a MaterialApp.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
