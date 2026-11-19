import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/languages/language.dart';
import 'package:latin_practice/models/course.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:latin_practice/screens/exam_list_screen.dart';
import 'package:latin_practice/screens/exam_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/gen_exam.dart';
import 'support/key_echo_app.dart';
import 'support/key_echo_i18n.dart';
import 'support/word_classification_harness.dart' show letItLoad;

final _en = Language.parse(
  File('lib/data/languages/en.yaml').readAsStringSync(),
);

const _seeds = 8;

String _source(int seed) => jsonEncode(
  EnglishExamGen(
    Random(seed),
  ).exam(include: {...EnglishExamGen.kinds, 'gap_markers', 'writing'}),
);

Exam _pack(int seed) => parseExam(_source(seed), _en);

Future<Map<String, Object>> _stored() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (final k in prefs.getKeys()) k: prefs.get(k)!};
}

Future<void> _openFromList(WidgetTester tester, int seed) async {
  SharedPreferences.setMockInitialValues({
    activeCourseKey: 'englisch',
    'practice_settings.englisch': jsonEncode(
      Settings(lastLesson: noBooksLastLesson).toJson(),
    ),
  });
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final pack = _pack(seed);
  final drawn = jsonDecode(_source(seed)) as Map<String, dynamic>;
  drawn['course'] = 'englisch';
  final bytes = utf8.encode(jsonEncode(drawn));
  await tester.pumpWidget(
    wrapInKeyEchoAppWith(
      ExamListScreen(pickBytes: () async => Uint8List.fromList(bytes)),
      dataLanguage: 'en',
    ),
  );
  await letItLoad(tester);
  await tester.tap(find.byKey(const Key('exam.import')));
  await letItLoad(tester);
  expect(find.byKey(const Key('exam.import.refused')), findsNothing);
  await tester.tap(find.byKey(Key('exam.list.${pack.id}')));
  await letItLoad(tester);
  expect(
    find.byKey(Key('exam.task.${pack.aufgaben.first.id}')),
    findsOneWidget,
  );
  expect(tester.takeException(), isNull);
}

void main() {
  for (var seed = 0; seed < 3; seed++) {
    testWidgets('an English pack imported on the English course opens from the '
        'exam list (seed $seed)', (tester) async {
      // Generators: EnglishExamGen with every kind of task, seeds 0..2.
      await _openFromList(tester, seed);
    });
  }

  for (var seed = 0; seed < _seeds; seed++) {
    testWidgets('the English exam screen takes input in every task, counts the '
        'words of a text, checks the gaps and finishes without changing the '
        'stored Latin data (seed $seed)', (tester) async {
      // Generators: EnglishExamGen with every kind of task in each pack, seeds
      // 0..${_seeds - 1}; the Latin data are three fixed stored values.
      SharedPreferences.setMockInitialValues({
        activeCourseKey: 'englisch',
        'practice_settings': jsonEncode(Settings(lastLesson: 3).toJson()),
        'practice_settings.englisch': jsonEncode(
          Settings(lastLesson: noBooksLastLesson, punkteAnzeige: true).toJson(),
        ),
        'fsrs_cards': '{"x":1}',
      });
      tester.view.physicalSize = const Size(1200, 80000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final before = await _stored();
      final r = Random(seed);
      final pack = _pack(seed);
      var earned = 0;
      await tester.pumpWidget(
        wrapInKeyEchoAppWith(ExamScreen(exam: pack), dataLanguage: 'en'),
      );
      await letItLoad(tester);
      for (final t in pack.aufgaben) {
        final prefix = 'exam.task.${t.id}';
        expect(find.byKey(Key(prefix)), findsOneWidget);
        switch (t) {
          case SchreibenTask():
            final words = [for (var i = 0; i < r.nextInt(12); i++) 'w$i'];
            await tester.enterText(
              find.byKey(Key('$prefix.input')),
              words.join(r.nextBool() ? ' ' : '  \n '),
            );
            await tester.pump();
            expect(
              find.text(
                keyEcho('exam.screen.wordCount', {
                  'n': '${words.length}',
                  'min': '${t.minWoerter}',
                  'max': '${t.maxWoerter}',
                }),
              ),
              findsOneWidget,
              reason: 'writing ${t.id}',
            );
            await tester.tap(find.byKey(Key('$prefix.show')));
            await tester.pump();
            for (final (k, line) in t.rubrik.indexed) {
              final marked = r.nextBool();
              if (marked) earned += line.punkte;
              await tester.tap(
                find.byKey(
                  Key('$prefix.rubric.$k.${marked ? 'habIch' : 'anders'}'),
                ),
              );
              await tester.pump();
            }
          case ItemTask(art: ItemArt.luecke, :final items):
            final right = <int>{};
            for (final (j, i) in items.cast<LueckeItem>().indexed) {
              final good = r.nextBool();
              if (good) {
                right.add(j);
                earned += i.punkte;
              }
              await tester.enterText(
                find.byKey(Key('$prefix.gap.$j')),
                good ? expand(i.antworten.first).first : 'zzz',
              );
            }
            await tester.tap(find.byKey(Key('$prefix.check')));
            await tester.pump();
            for (var j = 0; j < items.length; j++) {
              expect(
                tester
                    .widget<Text>(find.byKey(Key('$prefix.gap.$j.feedback')))
                    .data,
                right.contains(j)
                    ? 'exam.screen.gapCorrect'
                    : 'exam.screen.gapWrong',
                reason: 'gap ${t.id}.$j',
              );
            }
          default:
            await tester.tap(find.byKey(Key('$prefix.show')));
            await tester.pump();
        }
      }
      expect(
        tester.widget<Text>(find.byKey(const Key('exam.points'))).data,
        keyEcho('exam.screen.points', {
          'n': '$earned',
          'total': '${pack.punkteGesamt}',
        }),
      );
      await tester.tap(find.byKey(const Key('exam.finish')));
      await letItLoad(tester);
      expect(find.byKey(const Key('exam.finished')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final after = await _stored();
      expect({for (final k in before.keys) k: after[k]}, before);
    });
  }
}
