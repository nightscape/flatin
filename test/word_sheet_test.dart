import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/screens/word_sheet.dart';

import 'support/key_echo_app.dart';
import 'support/key_echo_i18n.dart';

void main() {
  testWidgets('the sheet shows the meaning, entry and analysis lines that '
      'have text, and no line for a part that is null or empty', (
    tester,
  ) async {
    const parts = <String?>[null, '', 'x'];
    for (final meaning in parts) {
      for (final entry in parts) {
        for (final analysis in parts) {
          await tester.pumpWidget(
            wrapInKeyEchoAppWith(
              Scaffold(
                body: WordSheet(
                  spelling: 'amō',
                  lemma: 'amare',
                  meaning: meaning,
                  entry: entry,
                  analysis: analysis,
                ),
              ),
            ),
          );
          await tester.pump();
          expect(
            [
              for (final t in tester.widgetList<Text>(find.byType(Text)))
                t.data!,
            ],
            [
              'amō',
              keyEcho('exam.sheet.lemma', {'lemma': 'amare'}),
              if (meaning == 'x')
                keyEcho('exam.sheet.meaning', {'meaning': 'x'}),
              if (entry == 'x') keyEcho('exam.sheet.entry', {'angabe': 'x'}),
              if (analysis == 'x')
                keyEcho('exam.sheet.analysis', {'analysis': 'x'}),
            ],
            reason: 'meaning $meaning, entry $entry, analysis $analysis',
          );
        }
      }
    }
  });
}
