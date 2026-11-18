import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/providers/lesson_provider.dart';
import 'package:latin_practice/screens/lookup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/course_providers.dart';
import 'support/gen_exam.dart';
import 'support/key_echo_app.dart';
import 'support/key_echo_i18n.dart';
import 'support/latin_course.dart';
import 'support/word_classification_harness.dart';

typedef _Reading = (PracticeItem, int, String);

const _marks = {'ā': 'a', 'ē': 'e', 'ī': 'i', 'ō': 'o', 'ū': 'u', 'ȳ': 'y'};

/// Lower case without quantity marks, spelled out here and not taken from
/// the language file the lookup uses.
String _plain(String w) =>
    w.toLowerCase().split('').map((c) => _marks[c] ?? c).join();

/// Every accepted spelling of every form of every item that spells [query]
/// up to case and quantity marks, found by a scan, in course order.
List<_Reading> _scan(List<PracticeItem> items, String query) => [
  for (final item in items)
    for (final (j, spellings) in item.acceptedForms.indexed)
      for (final spelling in spellings)
        if (_plain(spelling) == _plain(query.trim())) (item, j, spelling),
];

/// The lesson lines of [reading] as (key, text) in the order of the sheet,
/// from the lookups of the data alone.
List<(String, String)> _lessonLines(
  _Reading reading,
  LessonData lessons,
  Curriculum curriculum,
) {
  final (item, j, _) = reading;
  final exact = lessons.wordToLesson[item.wordKey];
  final word = exact != null
      ? {exact}
      : {
          for (final MapEntry(:key, :value) in lessons.wordToLesson.entries)
            if (_plain(key) == _plain(item.wordKey)) value,
        };
  final grammar = curriculum.hasGrammar(item.dataFileId);
  final type = grammar
      ? curriculum.typeLessonOrNull(item.dataFileId, item.type)
      : null;
  final form = grammar && !item.isVocab
      ? curriculum.formLessonOrNull(item.dataFileId, item.formOrder[j])
      : null;
  (String, String) line(String kind, int n) => (
    'exam.sheet.lesson.$kind.$n',
    keyEcho('exam.sheet.lesson.$kind', {'lesson': '$n'}),
  );
  return [
    for (final n in word.toList()..sort()) line('word', n),
    if (type != null && type == form) line('typeAndForm', type),
    if (type != null && type != form) line('type', type),
    if (form != null && type != form) line('form', form),
  ];
}

List<(String?, String)> _expectedSheet(
  _Reading reading,
  LessonData lessons,
  Curriculum curriculum,
) {
  final (item, j, spelling) = reading;
  return [
    (null, spelling),
    (null, keyEcho('exam.sheet.lemma', {'lemma': item.lemma})),
    if (item.note case final note?) ('exam.sheet.note', note),
    (null, keyEcho('exam.sheet.meaning', {'meaning': item.translation})),
    if (!item.isVocab)
      (
        null,
        keyEcho('exam.sheet.analysis', {
          'analysis': item.formLabels[j].displayName,
        }),
      ),
    ..._lessonLines(reading, lessons, curriculum),
  ];
}

void main() {
  testWidgets('the lookup shows exactly the readings of the typed spelling, '
      'each with the lessons of its word, type and form, and "not found" '
      'for a spelling that no form has', (tester) async {
    final items = (await tester.runAsync(
      () => loadAllPracticeItems(language: 'de'),
    ))!;
    final realLessons = (await tester.runAsync(
      () => loadLessonData(latinCourse.books),
    ))!;
    final curriculum = (await tester.runAsync(
      () => curriculumOf([
        for (final b in latinCourse.books) File(b).readAsStringSync(),
      ]),
    ))!;
    final seen = <String, int>{};
    void hit(String what) => seen[what] = (seen[what] ?? 0) + 1;

    for (var seed = 0; seed < 8; seed++) {
      final r = Random(seed);
      final lessons = withoutWords(realLessons, {
        for (final w in realLessons.wordToLesson.keys)
          if (r.nextDouble() >= [1.0, 0.5, 0.0][seed % 3]) w,
      });
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const SizedBox());
      tester.view.physicalSize = const Size(1200, 60000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapInKeyEchoAppWith(
          const LookupScreen(),
          overrides: [
            lessonDataProvider.overrideWith((ref) => lessons),
            curriculumProvider.overrideWith((ref) => curriculum),
          ],
        ),
      );
      await letItLoad(tester);

      PracticeItem pick() => items[r.nextInt(items.length)];
      final queries = [
        'dominī',
        'domini',
        'NŌNNE',
        '  amō ',
        'xqzunlisted',
        '   ',
        for (final item in items)
          if (item.isVocab &&
              (item.note != null || item.acceptedForms.single.length > 1))
            ...item.acceptedForms.single,
        for (var n = 0; n < 6; n++)
          ...() {
            final item = pick();
            final spellings = item.acceptedForms[r.nextInt(item.forms.length)];
            final f = spellings[r.nextInt(spellings.length)];
            return [
              f,
              _plain(f),
              f.toUpperCase(),
              '$f${'qxz'[r.nextInt(3)]}',
              f.substring(1),
              item.lemma,
            ];
          }(),
      ];
      for (final q in queries) {
        await tester.enterText(find.byKey(const Key('lookup.field')), q);
        await tester.pump();
        final readings = _scan(items, q);
        final why = 'seed $seed, query "$q"';
        for (var i = 0; i < readings.length; i++) {
          final sheet = find.byKey(Key('lookup.result.$i'));
          expect(sheet, findsOneWidget, reason: '$why reading $i');
          expect(
            [
              for (final t in tester.widgetList<Text>(
                find.descendant(of: sheet, matching: find.byType(Text)),
              ))
                ((t.key as ValueKey<String>?)?.value, t.data!),
            ],
            _expectedSheet(readings[i], lessons, curriculum),
            reason: '$why reading $i',
          );
        }
        expect(
          find.byKey(Key('lookup.result.${readings.length}')),
          findsNothing,
          reason: '$why shows no reading beyond the ${readings.length}',
        );
        expect(
          find.byKey(const Key('lookup.notFound')),
          q.trim().isNotEmpty && readings.isEmpty
              ? findsOneWidget
              : findsNothing,
          reason: why,
        );
        if (readings.isEmpty) hit('no reading');
        if (readings.length > 1) hit('several readings');
        if (readings.any((x) => x.$1.isVocab)) hit('vocab reading');
        if (readings.any((x) => x.$3 != x.$1.forms[x.$2])) {
          hit('variant reading');
        }
        if (readings.any((x) => x.$1.note != null)) hit('noted reading');
        if (readings.isNotEmpty &&
            !readings.any(
              (x) => x.$3.toLowerCase() == q.trim().toLowerCase(),
            )) {
          hit('found only by the fold');
        }
        for (final x in readings) {
          final lines = _lessonLines(x, lessons, curriculum);
          if (lines.any((l) => l.$1.contains('.word.'))) hit('word line');
          if (!lines.any((l) => l.$1.contains('.word.'))) hit('no word line');
          if (lines.any((l) => l.$1.contains('.type.'))) hit('type line');
          if (lines.any((l) => l.$1.contains('.form.'))) hit('form line');
          if (lines.any((l) => l.$1.contains('.typeAndForm.'))) {
            hit('typeAndForm line');
          }
        }
      }
    }
    for (final what in [
      'no reading',
      'several readings',
      'vocab reading',
      'variant reading',
      'noted reading',
      'found only by the fold',
      'word line',
      'no word line',
      'type line',
      'form line',
      'typeAndForm line',
    ]) {
      expect(seen[what], greaterThan(0), reason: 'drawn cases reach "$what"');
    }
  });
}
