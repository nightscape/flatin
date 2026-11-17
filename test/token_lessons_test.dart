import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latin_practice/data/analyse_form.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/token_lessons.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/exam_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

import 'support/latin_course.dart';

WordToken _token(String lemma, Map<String, Object> codes) =>
    WordToken('t', lemma, lemma, Analyse(codes));

const _clause = Clause(
  id: 'c',
  art: 'haupt',
  tokens: [],
  de: [],
  ausrichtung: [],
);

/// The analysis codes that state exactly the features of [label], or null
/// when the language file has no analysis code for one of them.
Map<String, Object>? _codesOf(FormLabel label) {
  final codes = <String, Object>{};
  for (final MapEntry(:key, :value) in label.features.entries) {
    final known = latinLang.analyse[key]?.where((c) => '$c' == value);
    if (known == null || known.isEmpty) return null;
    codes[key] = known.single;
  }
  return codes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late Curriculum curriculum;
  late LessonData lessons;
  late List<PracticeItem> items;
  late Map<String, List<FormLabel>> labels;

  setUpAll(() async {
    curriculum = await loadCurriculum(latinCourse.books);
    lessons = await loadLessonData(latinCourse.books);
    items = await loadAllPracticeItems();
    labels = {
      for (final file in latinCourse.grammarFiles)
        file.path: curriculum.labelsOf(
          (await getFormMetadata(file.path)).dataFileId,
        ),
    };
  });

  test('every token whose lemma the lesson lists contain shows its word '
      'lesson, with or without an app item', () async {
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    addTearDown(container.dispose);
    final resolved = await container.read(examWordsProvider.future);
    final lookup = await container.read(lessonLookupProvider.future);
    final lemmas = {...lessons.wordToLesson.keys, ...resolved.keys};
    var withoutItem = 0;
    for (final lemma in lemmas) {
      final listed = lessons.wordToLesson.keys.any(
        (w) => latinLang.fold(w) == latinLang.fold(lemma),
      );
      if (!listed) continue;
      if (!resolved.containsKey(lemma)) withoutItem++;
      expect(
        lookup.of(_token(lemma, {}), _clause).word,
        isNotEmpty,
        reason: lemma,
      );
    }
    expect(withoutItem, greaterThan(0));
  });

  test('every form key of the real files that the language can state '
      'maps back to itself, and every other key has a feature it cannot', () {
    var reachable = 0, unreachable = 0;
    for (final fileLabels in labels.values) {
      for (final label in fileLabels) {
        final codes = _codesOf(label);
        if (codes == null) {
          unreachable++;
          continue;
        }
        reachable++;
        expect(
          formKeyOfAnalyse(fileLabels, codes),
          label.key,
          reason: '${label.key} from $codes',
        );
      }
    }
    expect(reachable, greaterThan(100));
    expect(unreachable, greaterThan(0));
  });

  test('a lookup without a topic is null where the throwing lookup gives the '
      'lesson, and equal otherwise', () {
    for (final id in {
      for (final i in items)
        if (curriculum.hasGrammar(i.dataFileId)) i.dataFileId,
    }) {
      for (final label in curriculum.labelsOf(id)) {
        final lesson = curriculum.formLesson(id, label.key);
        expect(
          curriculum.formLessonOrNull(id, label.key),
          lesson == latinLaterLesson ? isNull : lesson,
          reason: label.key,
        );
      }
    }
    for (final item in items.where(
      (i) => curriculum.hasGrammar(i.dataFileId),
    )) {
      final lesson = curriculum.typeLesson(item.dataFileId, item.type);
      expect(
        curriculum.typeLessonOrNull(item.dataFileId, item.type),
        lesson == latinLaterLesson ? isNull : lesson,
        reason: item.type,
      );
    }
    expect(curriculum.typeLessonOrNull('nouns', 'no such type'), isNull);
    expect(curriculum.syntaxLessonOrNull('no.such.topic'), isNull);
  });

  test('the syntax topics are the funktion codes and the clause arts but '
      'the main clause', () {
    final ids = syntaxTopicIds(latinLang);
    expect(ids, isNot(contains('clause.art.${latinLang.rules.mainClause}')));
    expect(ids, containsAll(['analyse.funktion.gen_subj', 'clause.art.aci']));
    for (final id in ids) {
      expect(
        id.startsWith('analyse.funktion.') || id.startsWith('clause.art.'),
        isTrue,
        reason: id,
      );
    }
    for (final art in latinLang.clauseArt) {
      expect(
        ids.contains('clause.art.$art'),
        art != latinLang.rules.mainClause,
      );
    }
  });

  test(
    'a book that lists an unknown, a main-clause or a repeated syntax '
    'topic is refused with the entry path; known topics get their lesson',
    () {
      final ids = syntaxTopicIds(latinLang).toList()..sort();
      for (var seed = 0; seed < 40; seed++) {
        final r = Random(seed);
        final lesson = 1 + r.nextInt(latinLastLesson);
        final good = ids[r.nextInt(ids.length)];
        final bad = [
          'clause.art.${latinLang.rules.mainClause}',
          'analyse.funktion.zzz',
          'nouns',
          'clause.art',
          '${ids[r.nextInt(ids.length)]}x',
        ][r.nextInt(5)];
        String book(List<String> topics, [int at = 0]) =>
            'lessons:\n  - lesson: ${lesson + at}\n    grammar:\n'
            '      syntax: [${topics.join(', ')}]\n';
        Curriculum parse(List<String> sources) => Curriculum.parse(
          sources,
          {},
          syntaxTopics: ids.toSet(),
          lastLesson: latinLastLesson,
        );

        expect(
          parse([
            book([good]),
          ]).syntaxLessonOrNull(good),
          lesson,
          reason: 'seed $seed',
        );
        expect(
          () => parse([
            book([good, bad]),
          ]),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(contains('book file 1, lesson $lesson'), contains(bad)),
            ),
          ),
          reason: 'seed $seed: $bad',
        );
        expect(
          () => parse([
            book([good]),
            book([good]),
          ]),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(contains('book file 2, lesson $lesson'), contains(good)),
            ),
          ),
          reason: 'seed $seed: repeated $good',
        );
      }
    },
  );

  test('a lemma in several data files shows one value per distinct '
      'lesson, ascending, and a lesson of type and form once', () {
    final grammar = [
      for (final i in items)
        if (curriculum.hasGrammar(i.dataFileId)) i,
    ];
    final reachable = [
      for (final l in labels.values.expand((l) => l))
        if (_codesOf(l) != null) l,
    ];
    for (var seed = 0; seed < 60; seed++) {
      final r = Random(seed);
      final own = [
        for (var n = 1 + r.nextInt(3); n > 0; n--)
          grammar[r.nextInt(grammar.length)],
      ];
      final files = [
        for (final i in own) (dataFileId: i.dataFileId, type: i.type),
      ];
      final from = own[r.nextInt(own.length)];
      final label = reachable[r.nextInt(reachable.length)];
      final codes = _codesOf(label)!;
      final got = LessonLookup(latinLang, lessons, curriculum, {
        'x': files,
      }).of(_token('x', codes), _clause);
      final types = {
        for (final f in files)
          curriculum.typeLessonOrNull(f.dataFileId, f.type),
      }..remove(null);
      final forms = {
        for (final f in files)
          if (formKeyOfAnalyse(curriculum.labelsOf(f.dataFileId), codes)
              case final key?)
            curriculum.formLessonOrNull(f.dataFileId, key),
      }..remove(null);
      final why = 'seed $seed: ${from.dataFileId} $codes $files';
      expect(
        got.typeAndForm,
        types.intersection(forms).toList()..sort(),
        reason: why,
      );
      expect(got.type, types.difference(forms).toList()..sort(), reason: why);
      expect(got.form, forms.difference(types).toList()..sort(), reason: why);
    }
  });
}
