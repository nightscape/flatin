@Tags(['tracer'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/main.dart';
import 'package:latin_practice/screens/exam_list_screen.dart';
import 'package:latin_practice/screens/exam_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/word_classification_harness.dart' show letItLoad;
import 'toy_assets.dart';

const _language = '$toyDir/toy_language.yaml';
const _words = '$toyDir/toy_words.yaml';

List<List<String>> _subsets(List<String> items, {required bool empty}) => [
  for (var mask = empty ? 0 : 1; mask < 1 << items.length; mask++)
    [
      for (var b = 0; b < items.length; b++)
        if (mask & (1 << b) != 0) items[b],
    ],
];

typedef _Course = ({
  List<String> form,
  List<String> axisValues,
  List<String> analyse,
});

/// Every course made of a `form` line over the toy keys and `kraft`, the
/// values of the grammar axis `kraft` and the `analyse` codes of that key:
/// each side empty, overlapping or disjoint with the others.
Iterable<_Course> _courses() sync* {
  const codes = ['stark', 'schwach'];
  for (final form in _subsets([
    'wortart',
    'ruf',
    'zal',
    'kraft',
  ], empty: true)) {
    for (final axisValues in _subsets(codes, empty: false)) {
      for (final analyse in _subsets(codes, empty: false)) {
        yield (form: form, axisValues: axisValues, analyse: analyse);
      }
    }
  }
}

String _languageOf(String source, _Course c) => source
    .replaceFirst('form: [ruf, zal]', 'form: [${c.form.join(', ')}]')
    .replaceFirst(
      '  zal: [ein]\n',
      '  zal: [ein]\n  kraft: [${c.analyse.join(', ')}]\n',
    );

String _wordsOf(String source, _Course c) => source
    .replaceFirst('tail: [ruf, zal]', 'tail: [ruf, zal, kraft]')
    .replaceFirst(
      '\nlabel:',
      [
        '  kraft:',
        '    name: {de: Kraft, en: Strength}',
        '    values:',
        for (final v in c.axisValues) '      $v: {de: $v, en: $v}',
        '',
        'label:',
      ].join('\n'),
    );

/// The toy pack with one `bestimmen` task that asks `kraft`, as well as every
/// toy axis.
String _packOf(_Course c) => File('$toyDir/toy.exam')
    .readAsStringSync()
    .replaceFirst('punkte_gesamt: 4', 'punkte_gesamt: 5')
    .replaceFirst(
      'zal: ein}, rolle: tu',
      'zal: ein, kraft: ${c.analyse.first}}, rolle: tu',
    )
    .replaceFirst('aufgaben: []', '''aufgaben:
- id: a1
  titel: Bestimmen
  punkte: 1
  art: bestimmen
  frage: Bestimme trovka.
  items:
  - token: s1_1
    merkmale: [lemma, ruf, zal, kraft]
    punkte: 1
  loesung:
  - trovka
''');

void main() {
  final language = File(_language).readAsStringSync();
  final words = File(_words).readAsStringSync();
  assert(language.contains('form: [ruf, zal]'));
  assert(language.contains('  zal: [ein]\n'));
  assert(words.contains('\nlabel:'));
  assert(words.contains('tail: [ruf, zal]'));
  for (final c in _courses()) {
    testWidgets(
      'the exam screen opens the toy pack, with a task asking every axis, when '
      'the language forms words with ${c.form}, the kraft axis has '
      '${c.axisValues} and the language analyse has ${c.analyse}',
      (tester) async {
        resetPracticeData();
        SharedPreferences.setMockInitialValues({});
        injectToyCourse(
          served: {
            _language: _languageOf(language, c),
            _words: _wordsOf(words, c),
          },
        );
        tester.view.physicalSize = const Size(1200, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          const ProviderScope(retry: noRetry, child: LatinPracticeApp()),
        );
        await letItLoad(tester);
        final pack = utf8.encode(_packOf(c));
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .push(
              MaterialPageRoute<void>(
                builder: (_) => ExamListScreen(pickBytes: () async => pack),
              ),
            );
        await letItLoad(tester);
        await tester.tap(find.byKey(const Key('exam.import')));
        await letItLoad(tester);
        await tester.tap(find.byKey(const Key('exam.list.toy-pack')));
        await letItLoad(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(ExamScreen), findsOneWidget);
        expect(find.byKey(const Key('exam.finish')), findsOneWidget);
      },
    );
  }
}
