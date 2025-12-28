import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nertz_royale/main.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: NertzRoyaleApp(),
      ),
    );

    // Verify the lobby screen loads
    expect(find.text('NERTZ ROYALE'), findsOneWidget);
    expect(find.text('PLAY NOW'), findsOneWidget);
  });
}
