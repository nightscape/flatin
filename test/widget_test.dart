// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/flutter_i18n_delegate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:latin_practice/main.dart';

void main() {
  testWidgets('Latin declension screen displays correctly', (WidgetTester tester) async {
    // Build our app with i18n support and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            FlutterI18nDelegate(
              translationLoader: FileTranslationLoader(
                basePath: 'assets/flutter_i18n',
                fallbackFile: 'en',
                useCountryCode: false,
              ),
            ),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: FlutterI18n.rootAppBuilder(),
          home: const LatinPracticeApp(),
        ),
      ),
    );

    // Wait for i18n to load
    await tester.pumpAndSettle();

    // Verify that the declension type is displayed.
    expect(find.text('O-Deklination'), findsOneWidget);

    // Verify that the translation is displayed.
    expect(find.text('Der Hausherr/Herr'), findsOneWidget);

    // Verify that Latin forms are displayed.
    expect(find.text('dominus'), findsOneWidget);
  });
}
