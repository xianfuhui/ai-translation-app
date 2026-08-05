import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_app/main.dart';

void main() {
  testWidgets('Lingua app boots with the branded splash screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LanguageApp());
    await tester.pump();

    expect(find.text('lingua'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
