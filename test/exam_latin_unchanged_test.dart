import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/languages/language.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/screens/exam_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/gen_exam.dart';
import 'support/latin_course.dart' show latinLastLesson;
import 'support/word_classification_harness.dart';

// Generators: none. The inputs are the packs and the screen dump that the
// code before the English schema produced, stored as explicit data in
// test/fixtures/exam/latin_*.golden.json; a generator would redraw them
// whenever it changes. Each test runs one property over every stored input.
final _toy = Language.parse(
  File('test/fixtures/toy_course/toy_language.yaml').readAsStringSync(),
);

Map<String, dynamic> _golden(String name) =>
    jsonDecode(File('test/fixtures/exam/$name.golden.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('a Latin pack reads and writes the bytes it did before the English '
      'schema: the fixtures and the stored drawn packs', () {
    final golden = _golden('latin_base');
    final fixtures = golden['fixtures'] as Map<String, dynamic>;
    for (final (name, path, language) in [
      ('synthetic', 'test/fixtures/exam/synthetic.exam', latinLang),
      ('toy', 'test/fixtures/toy_course/toy.exam', _toy),
    ]) {
      final exam = parseExam(File(path).readAsStringSync(), language);
      expect(
        jsonEncode(examToYaml(exam)),
        jsonEncode(fixtures[name]),
        reason: name,
      );
      expect(
        jsonEncode(examToYaml(parseExam(serializeExam(exam), language))),
        jsonEncode(fixtures[name]),
        reason: '$name written and read again',
      );
    }
    for (final (i, entry) in (golden['drawn'] as List).indexed) {
      final exam = parseExam(jsonEncode(entry['pack']), latinLang);
      expect(
        jsonEncode(examToYaml(exam)),
        jsonEncode(entry['written']),
        reason: 'drawn pack $i',
      );
    }
  });

  testWidgets('the Latin exam screen shows the keys and texts it showed before '
      'the English schema, before and after every solution is shown', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'practice_settings': jsonEncode(
        Settings(lastLesson: latinLastLesson).toJson(),
      ),
    });
    tester.view.physicalSize = const Size(1200, 60000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final pack = parseExam(
      File('test/fixtures/exam/synthetic.exam').readAsStringSync(),
      latinLang,
    );
    await tester.pumpWidget(
      wrapInApp(ExamScreen(exam: pack), forcedLocale: const Locale('de')),
    );
    await letItLoad(tester);
    List<String> keys() => [
      for (final e
          in find
              .byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith('exam.task.'),
              )
              .evaluate())
        (e.widget.key! as ValueKey<String>).value,
    ];
    Map<String, List<String>> texts() => {
      for (final t in pack.aufgaben)
        t.id: [
          for (final w
              in find
                  .descendant(
                    of: find.byKey(Key('exam.task.${t.id}')),
                    matching: find.byType(Text),
                  )
                  .evaluate()
                  .map((e) => e.widget as Text))
            w.data ?? w.textSpan!.toPlainText(),
        ],
    };
    final golden = _golden('latin_screen_base');
    expect(keys(), golden['keysBefore']);
    expect(texts(), golden['textsBefore']);
    for (final t in pack.aufgaben) {
      await tester.tap(find.byKey(Key('exam.task.${t.id}.show')));
      await tester.pump();
    }
    expect(keys(), golden['keysAfter']);
    expect(texts(), golden['textsAfter']);
  });
}
