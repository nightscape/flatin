import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:latin_practice/data/analyse_form.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/course.dart';
import 'package:latin_practice/data/token_lessons.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/exam_provider.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/providers/lesson_provider.dart';
import 'package:latin_practice/screens/exam_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/course_providers.dart';
import 'support/gen_exam.dart';
import 'support/latin_course.dart';
import 'support/key_echo_app.dart';
import 'support/key_echo_i18n.dart';
import 'support/word_classification_harness.dart';

const _prefix = 'exam.sheet.lesson.';
const _unlisted = 'xqzunlisted';

List<String> _bookTexts() => [
  for (final b in latinCourse.books) File(b).readAsStringSync(),
];

/// The books with every id of each `syntax:` entry kept with probability
/// [keep].
String _thinSyntax(String book, Random r, double keep) => book.replaceAllMapped(
  RegExp(r'syntax: \[(.*)\]'),
  (m) =>
      'syntax: [${m[1]!.split(', ').where((_) => r.nextDouble() < keep).join(', ')}]',
);

/// The form a token names in a data file: written independently of
/// [formKeyOfAnalyse], by filtering and then taking the most specific label.
FormKey? _formKey(List<FormLabel> labels, Map<String, Object> codes) {
  final fitting = [
    for (final l in labels)
      if (l.features.entries.every((e) => '${codes[e.key]}' == e.value)) l,
  ]..sort((a, b) => b.features.length.compareTo(a.features.length));
  return fitting.isEmpty ? null : fitting.first.key;
}

/// The lines the sheet of [token] must show, as key -> lesson, computed from
/// the lookups alone; the words a respelled lemma folds to come from the
/// lists of the case, which the property thins per seed.
Map<String, int> _expected(
  WordToken token,
  Clause clause,
  Map<String, List<WordFile>> files,
  LessonData lessons,
  Curriculum curriculum,
) {
  final lines = <String, int>{};
  void add(String id, int lesson) => lines['$_prefix$id.$lesson'] = lesson;
  final exact = lessons.wordToLesson[token.lemma];
  final word = exact != null
      ? {exact}
      : {
          for (final MapEntry(:key, :value) in lessons.wordToLesson.entries)
            if (_withoutMarks(key) == _withoutMarks(token.lemma)) value,
        };
  for (final n in word.toList()..sort()) {
    add('word', n);
  }
  final types = <int>{}, forms = <int>{};
  for (final i in (files[token.lemma] ?? const <WordFile>[]).where(
    (i) => curriculum.hasGrammar(i.dataFileId),
  )) {
    final t = curriculum.typeLessonOrNull(i.dataFileId, i.type);
    if (t != null) types.add(t);
    final key = _formKey(
      curriculum.labelsOf(i.dataFileId),
      token.analyse.codes,
    );
    final f = key == null
        ? null
        : curriculum.formLessonOrNull(i.dataFileId, key);
    if (f != null) forms.add(f);
  }
  types.intersection(forms).forEach((n) => add('typeAndForm', n));
  types.difference(forms).forEach((n) => add('type', n));
  forms.difference(types).forEach((n) => add('form', n));
  for (final topic in [
    for (final e in token.analyse.codes.entries) 'analyse.${e.key}.${e.value}',
    'clause.art.${clause.art}',
  ]) {
    final n = curriculum.syntaxLessonOrNull(topic);
    if (n != null) add(topic, n);
  }
  return lines;
}

const _marks = {'ā': 'a', 'ē': 'e', 'ī': 'i', 'ō': 'o', 'ū': 'u', 'ȳ': 'y'};

String _withoutMarks(String w) => w.split('').map((c) => _marks[c] ?? c).join();

/// One drawn spelling of each group of list words that differ only in
/// quantity marks: a token of that spelling then finds its sibling only by
/// the fold.
Set<String> _oneSpellingPerGroup(
  Random r,
  Map<String, List<String>> byLetters,
) => {
  for (final group in byLetters.values)
    if (group.length > 1 && r.nextBool()) group[r.nextInt(group.length)],
};

/// Whether [lines] hold two or more type, form or typeAndForm lines of one
/// kind, which only a lemma in several data files gives.
bool _severalOfOneKind(Map<String, int> lines) =>
    ['type', 'form', 'typeAndForm'].any(
      (kind) =>
          lines.keys.where((k) => k.startsWith('$_prefix$kind.')).length > 1,
    );

/// The app's own lookup provider, unless the case gives lemmas data files
/// that only a lookup built by the test can hold.
List<Override> _lookupOverride(
  bool testFiles,
  LessonLookup Function() lookup,
) => [
  if (testFiles) lessonLookupProvider.overrideWith((ref) async => lookup()),
];

/// The lessons of [token] by an independent copy of the sheet's lesson rule.
TokenLessons _ruleLessons(LessonLookup l, WordToken token, Clause clause) {
  final types = <int>{}, forms = <int>{};
  for (final file in l.files[token.lemma] ?? const <WordFile>[]) {
    if (!l.curriculum.hasGrammar(file.dataFileId)) continue;
    final type = l.curriculum.typeLessonOrNull(file.dataFileId, file.type);
    if (type != null) types.add(type);
    final key = formKeyOfAnalyse(
      l.curriculum.labelsOf(file.dataFileId),
      token.analyse.codes,
    );
    final form = key == null
        ? null
        : l.curriculum.formLessonOrNull(file.dataFileId, key);
    if (form != null) forms.add(form);
  }
  List<int> sorted(Iterable<int> xs) => xs.toList()..sort();
  final exactWord = l.lessons.wordToLesson[token.lemma];
  final both = types.intersection(forms);
  final syntax = <String, int>{};
  for (final id in [
    for (final MapEntry(:key, :value) in token.analyse.codes.entries)
      'analyse.$key.$value',
    'clause.art.${clause.art}',
  ]) {
    final lesson = l.curriculum.syntaxLessonOrNull(id);
    if (lesson != null) syntax[id] = lesson;
  }
  final folded = <String, Set<int>>{};
  for (final MapEntry(:key, :value) in l.lessons.wordToLesson.entries) {
    (folded[l.language.fold(key)] ??= {}).add(value);
  }
  return (
    word: sorted(
      exactWord != null
          ? [exactWord]
          : folded[l.language.fold(token.lemma)] ?? const <int>{},
    ),
    typeAndForm: sorted(both),
    type: sorted(types.difference(both)),
    form: sorted(forms.difference(both)),
    syntax: syntax,
  );
}

/// The (key, text) of every text that the sheet shows for [token] and its
/// [l] lessons, under a key-echo i18n.
List<(String?, String)> _sheetLines(
  WordToken token,
  TokenLessons l,
  String? meaning,
  Hilfe? hilfe,
) {
  (String?, String) line(String kind, int n, {String? topic}) => (
    'exam.sheet.lesson.${topic ?? kind}.$n',
    keyEcho('exam.sheet.lesson.$kind', {
      'lesson': '$n',
      if (topic != null) 'topic': 'exam.$topic',
    }),
  );
  return [
    (null, token.la),
    (null, keyEcho('exam.sheet.lemma', {'lemma': token.lemma})),
    if (meaning != null && meaning.isNotEmpty)
      (null, keyEcho('exam.sheet.meaning', {'meaning': meaning})),
    if (hilfe != null && hilfe.angabe.isNotEmpty)
      (null, keyEcho('exam.sheet.entry', {'angabe': hilfe.angabe})),
    (
      null,
      keyEcho('exam.sheet.analysis', {
        'analysis': [
          for (final e in token.analyse.codes.entries)
            'exam.analyse.${e.key}.${e.value}',
        ].join(', '),
      }),
    ),
    for (final n in l.word) line('word', n),
    for (final n in l.typeAndForm) line('typeAndForm', n),
    for (final n in l.type) line('type', n),
    for (final n in l.form) line('form', n),
    for (final MapEntry(:key, :value) in l.syntax.entries)
      line('syntax', value, topic: key),
  ];
}

void main() {
  testWidgets('the sheet shows the word, type, form and syntax '
      'lessons the lookups give, and nothing for a value that is missing', (
    tester,
  ) async {
    final items = (await tester.runAsync(loadAllPracticeItems))!;
    final realLessons = (await tester.runAsync(
      () => loadLessonData(latinCourse.books),
    ))!;
    List<String> pool(DataFileRole role) => [
      for (final l in {
        for (final i in items)
          if (i.role == role) i.lemma,
      }.toList()..sort())
        l,
    ];
    final nouns = pool(DataFileRole.noun);
    final verbs = pool(DataFileRole.verb);
    final vocab = pool(DataFileRole.vocab);
    final itemLemmas = {for (final i in items) i.lemma};
    final listOnly = [
      for (final w in realLessons.wordToLesson.keys)
        if (!itemLemmas.contains(w)) w,
    ]..sort();
    final grammarItems = [
      for (final i in items)
        if (i.role != DataFileRole.vocab) i,
    ];
    final byLetters = <String, List<String>>{};
    for (final w in realLessons.wordToLesson.keys) {
      (byLetters[_withoutMarks(w)] ??= []).add(w);
    }
    final respelled = {
      for (final MapEntry(:key, :value) in byLetters.entries)
        if (!realLessons.wordToLesson.containsKey(key)) key: value,
    };
    final respelledLemmas = respelled.keys.toList()..sort();
    final homographs = [
      for (final group in byLetters.values)
        if (group.length > 1) ...group,
    ]..sort();
    final seen = <String, int>{};
    void hit(String what) => seen[what] = (seen[what] ?? 0) + 1;

    for (var seed = 1; seed <= 60; seed++) {
      final r = Random(seed);
      List<String> some(List<String> from, int n) => [
        for (var i = 0; i < n; i++) from[r.nextInt(from.length)],
      ];
      final gen = ExamGen(
        r,
        nouns: [
          ...some(nouns, 4),
          ...some(vocab, 1),
          ...some(listOnly, 1),
          ...some(homographs, 2),
          ...some(respelledLemmas, 2),
          _unlisted,
        ],
        verbs: [...some(verbs, 4), ...some(vocab, 1), _unlisted],
        adjectives: [...some(nouns, 2), _unlisted],
        participles: some(verbs, 2),
        funktionChance: 0.4,
        blankHilfeChance: 0.3,
      );
      final exam = parseExam(jsonEncode(gen.exam()), latinLang);
      final keepWords = [1.0, 0.7, 0.0][seed % 3];
      final keepSyntax = [1.0, 0.5, 0.0][(seed ~/ 3) % 3];
      final lessons = withoutWords(realLessons, {
        for (final w in realLessons.wordToLesson.keys)
          if (r.nextDouble() >= keepWords) w,
        ..._oneSpellingPerGroup(r, byLetters),
      });
      final curriculum = (await tester.runAsync(
        () => curriculumOf([
          for (final b in _bookTexts()) _thinSyntax(b, r, keepSyntax),
        ]),
      ))!;

      final files = {
        for (final i in items)
          i.lemma: [
            for (final j in items)
              if (j.lemma == i.lemma) (dataFileId: j.dataFileId, type: j.type),
          ],
      };
      if (seed % 4 == 0) {
        for (final lemma in {
          for (final t in exam.saetze.expand((s) => s.tokens))
            if (t case final WordToken w) w.lemma,
        }) {
          files[lemma] = [
            ...?files[lemma],
            for (var n = 1 + r.nextInt(2); n > 0; n--)
              (() {
                final i = grammarItems[r.nextInt(grammarItems.length)];
                return (dataFileId: i.dataFileId, type: i.type);
              })(),
          ];
        }
      }

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const SizedBox());
      tester.view.physicalSize = const Size(1200, 60000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapInKeyEchoAppWith(
          ExamScreen(exam: exam),
          overrides: [
            lessonDataProvider.overrideWith((ref) => lessons),
            curriculumProvider.overrideWith((ref) => curriculum),
            ..._lookupOverride(
              seed % 4 == 0,
              () => LessonLookup(latinLang, lessons, curriculum, files),
            ),
          ],
        ),
      );
      await letItLoad(tester);

      final words = [
        for (final s in exam.saetze)
          for (final c in s.teilsaetze)
            for (final id in c.tokens)
              if (s.tokens.firstWhere((t) => t.id == id) case final WordToken t)
                (t, c),
      ]..shuffle(r);
      bool teaches((WordToken, Clause) w) =>
          w.$1.analyse.codes.containsKey('funktion') ||
          const {'aci', 'pc'}.contains(w.$2.art);
      bool spelled((WordToken, Clause) w) =>
          respelled.containsKey(w.$1.lemma) || homographs.contains(w.$1.lemma);
      final tapped = [
        ...words.where(teaches),
        ...words.where((w) => !teaches(w) && spelled(w)),
        ...words.where((w) => !teaches(w) && !spelled(w)),
      ];
      for (final (token, clause) in tapped.take(12)) {
        final why = 'seed $seed, ${token.id} ${token.lemma} ${clause.art}';
        await tester.tap(find.byKey(Key('exam.token.${token.id}')));
        await tester.pump();
        await letItLoad(tester);
        final shown = {
          for (final t in tester.widgetList<Text>(
            find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  w.key is ValueKey<String> &&
                  (w.key as ValueKey<String>).value.startsWith(_prefix),
            ),
          ))
            (t.key as ValueKey<String>).value: t.data!,
        };
        final expected = _expected(token, clause, files, lessons, curriculum);
        final ruleLessons = _ruleLessons(
          LessonLookup(latinLang, lessons, curriculum, files),
          token,
          clause,
        );
        final hilfe = exam.hilfen.where((h) => h.lemma == token.lemma);
        if (hilfe.any((h) => h.angabe.isEmpty)) hit('empty hilfe angabe');
        final hilfeDe = hilfe.firstOrNull?.de;
        final courseMeaning = items
            .where((i) => i.lemma == token.lemma)
            .firstOrNull
            ?.translation;
        if (hilfeDe != null && hilfeDe.isEmpty) {
          hit(
            courseMeaning != null && courseMeaning.isNotEmpty
                ? 'empty hilfe de with course meaning'
                : 'empty hilfe de without course meaning',
          );
        }
        final shownSheet = [
          for (final t in tester.widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('exam.sheet')),
              matching: find.byType(Text),
            ),
          ))
            ((t.key as ValueKey<String>?)?.value, t.data!),
        ];
        expect(
          shownSheet,
          _sheetLines(
            token,
            ruleLessons,
            hilfeDe != null && hilfeDe.isNotEmpty ? hilfeDe : courseMeaning,
            hilfe.firstOrNull,
          ),
          reason: '$why: the whole sheet equals the lines of the rule copy',
        );
        expect(shown.keys.toSet(), expected.keys.toSet(), reason: why);
        for (final MapEntry(:key, :value) in shown.entries) {
          final id = key.substring(_prefix.length, key.lastIndexOf('.'));
          final n = '${expected[key]}';
          final isKind = const {
            'word',
            'type',
            'form',
            'typeAndForm',
          }.contains(id);
          expect(
            value,
            isKind
                ? keyEcho('$_prefix$id', {'lesson': n})
                : keyEcho('${_prefix}syntax', {
                    'lesson': n,
                    'topic': 'exam.$id',
                  }),
            reason: why,
          );
          hit(isKind ? id : 'syntax');
          if (id.startsWith('analyse.funktion.')) hit('funktion');
          if (id == 'clause.art.aci') hit('aci');
          if (id == 'clause.art.pc') hit('pc');
        }
        if (keepSyntax == 1.0) {
          final needs = [
            for (final e in token.analyse.codes.entries)
              if (e.key == 'funktion') 'analyse.funktion.${e.value}',
            if (const {'aci', 'pc'}.contains(clause.art))
              'clause.art.${clause.art}',
          ];
          for (final topic in needs) {
            expect(
              shown.keys.where((k) => k.startsWith('$_prefix$topic.')),
              hasLength(1),
              reason: '$why shows the lesson of $topic',
            );
          }
        }
        if (expected.isEmpty) hit('no line');
        if (_severalOfOneKind(expected)) hit('several type or form lines');
        if (respelled.containsKey(token.lemma) &&
            expected.keys.any((k) => k.contains('.word.'))) {
          hit('word line by fold');
        }
        if (homographs.contains(token.lemma) &&
            expected.keys.any((k) => k.contains('.word.'))) {
          hit('word line of a homograph');
        }
        if (!items.any((i) => i.lemma == token.lemma) &&
            shown.keys.any((k) => k.startsWith('${_prefix}word.'))) {
          hit('word line without item');
        }
        if (expected.isNotEmpty &&
            !expected.keys.any((k) => k.contains('.word.'))) {
          hit('lines without word');
        }
        if (!shown.keys.any(
          (k) => k.contains('.form.') || k.contains('.typeAndForm.'),
        )) {
          hit('no form line');
        }
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();
        await letItLoad(tester);
      }
    }
    for (final what in [
      'word',
      'typeAndForm',
      'syntax',
      'funktion',
      'aci',
      'pc',
      'no line',
      'lines without word',
      'word line without item',
      'word line by fold',
      'several type or form lines',
      'word line of a homograph',
      'no form line',
      'empty hilfe angabe',
      'empty hilfe de with course meaning',
      'empty hilfe de without course meaning',
    ]) {
      expect(seen[what], greaterThan(0), reason: 'drawn cases reach "$what"');
    }
  });
}
