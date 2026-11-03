import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/widgets/explanation_lines.dart';

import 'support/explanation_harness.dart';
import 'support/key_echo_app.dart';
import 'support/key_echo_i18n.dart';
import 'support/trace_fixtures.dart';

void main() {
  // Subject is de.json itself: its explain keys, each with exactly the
  // placeholders its sample line fills.
  test('sampleLines has an entry for every explain key of de.json', () async {
    final texts = await germanTexts();
    final explainKeys = texts.keys
        .where((key) => key.startsWith('explain.'))
        .toSet();
    expect(sampleLines.map((line) => line.key).toSet(), explainKeys);
    for (final line in sampleLines) {
      final placeholders = {
        for (final m in RegExp(r'\{(\w+)\}').allMatches(texts[line.key]!))
          m[1]!,
      };
      expect(line.params.keys.toSet(), placeholders, reason: line.key);
    }
  });

  testWidgets('every explain line renders its key with its params', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapInKeyEchoAppWith(const Scaffold(body: ExplanationLines(sampleLines))),
    );
    await tester.pumpAndSettle();

    final rendered = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ExplanationLines),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data!)
        .toList();

    expect(rendered, [
      for (final line in sampleLines) keyEcho(line.key, line.params),
    ]);
  });
}
