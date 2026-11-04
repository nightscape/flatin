import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scenario phrase -> translation key. A scenario keeps its readable German
/// phrase; the step reads the text of the locale the app loaded.
const glossary = <String, String>{'Unregelmäßige Verben': 'focus.irregular'};

String glossaryKey(String phrase) {
  final key = glossary[phrase];
  if (key == null) throw StateError('phrase not in glossary: $phrase');
  return key;
}

Finder findPhrase(WidgetTester tester, String phrase) => find.text(
  FlutterI18n.translate(
    tester.element(find.byType(Scaffold).first),
    glossaryKey(phrase),
  ),
);
