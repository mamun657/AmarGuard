import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amarguard/core/theme/app_theme.dart';

void main() {
  testWidgets('AppTheme builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: Text('AmarGuard'))),
      ),
    );
    expect(find.text('AmarGuard'), findsOneWidget);
  });
}
