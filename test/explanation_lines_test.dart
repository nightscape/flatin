import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/widgets/explanation_lines.dart';

import 'support/explanation_harness.dart';
import 'support/word_classification_harness.dart';

void main() {
  testWidgets('every explain key renders German text with its params',
      (tester) async {
    await tester.pumpWidget(wrapInApp(
      const Scaffold(body: ExplanationLines(sampleLines)),
      forcedLocale: const Locale('de'),
    ));
    await tester.pumpAndSettle();

    final rendered = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(ExplanationLines),
          matching: find.byType(Text),
        ))
        .map((t) => t.data!)
        .toList();

    expect(rendered, hasLength(sampleLines.length));
    for (var i = 0; i < sampleLines.length; i++) {
      final line = sampleLines[i];
      final text = rendered[i];
      expect(text, isNot(line.key), reason: '${line.key} is missing in de.json');
      expect(text, isNot(contains('{')),
          reason: '${line.key} left a parameter unsubstituted');
      for (final value in line.params.values) {
        expect(text, contains(value), reason: '${line.key} dropped $value');
      }
    }

    expect(rendered[2], 'manus: U-Deklination');
    expect(rendered.last, endsWith('das passt zu keiner bekannten Form'));
  });
}
