import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_cube.dart';
import 'package:latin_practice/data/exercise_interpreter.dart';
import 'package:latin_practice/data/exercise_spec.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'package:latin_practice/data/languages/language.dart';

import 'support/exercise_fakes.dart';
import 'support/gen_language.dart';
import 'support/gen_sentence_learner.dart';
import 'support/latin_course.dart';

/// The codes the sentence corpus used before they moved into the language
/// file.
const _constructions = [
  'frageNe',
  'frageNonne',
  'frageNum',
  'aciPassiv',
  'pcPpa',
  'pcPpp',
  'doppelterAkkusativ',
];
const _meanings = ['temporal', 'kausal', 'konzessiv', 'modal'];
const _mistakes = [
  'tempus',
  'genusVerbi',
  'bezugswort',
  'sinnrichtung',
  'frageart',
  'aussage',
  'rollen',
  'praedikativum',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<PracticeItem> items;
  late ExerciseContext Function(SentenceCorpus) context;

  setUpAll(() async {
    items = await loadAllPracticeItems();
    final bundles = {
      for (final w in items)
        for (final k in w.formOrder) bundleOf(w, k),
    };
    context = (corpus) => ExerciseContext(
      unlocked: bundles,
      pool: items,
      german: fakeExerciseContext().german,
      sentences: corpus,
      reachedLesson: laterLesson,
    );
  });

  test('the language file holds the codes the corpus uses and the corpus '
      'parses with them', () async {
    expect(latinLang.constructions.keys, _constructions);
    expect(latinLang.meanings, _meanings);
    expect(latinLang.mistakes, _mistakes);
    final corpus = await loadSentenceCorpus();
    expect(
      {for (final s in corpus.sentences) s.construction.kind},
      {..._constructions},
    );
  });

  test('a drawn language with drawn codes selects and builds sentence '
      'exercises with none of the Latin codes', () {
    for (var seed = 0; seed < 25; seed++) {
      final r = Random(seed);
      final drawn = drawnSentenceLanguage(r);
      final corpus = parseSentenceCorpus(
        jsonEncode(drawn.corpus),
        drawn.language,
      );
      final latinCodes = {..._constructions, ..._meanings, ..._mistakes};
      expect(
        drawn.language.constructions.keys.toSet().intersection(latinCodes),
        isEmpty,
      );

      final kinds = drawn.language.constructions.keys.toList();
      final listed = {
        for (final k in kinds)
          if (r.nextBool()) k,
      };
      final expected = [
        for (final s in drawn.corpus['sentences'] as List)
          if (listed.isEmpty ||
              listed.contains((s['construction'] as Map)['kind']))
            s['id'],
      ];
      final ctx = context(corpus);
      expect(
        [
          for (final s in sentenceSlices(
            OneSentence(constructions: listed.isEmpty ? null : listed),
            Cube(ctx),
          ))
            s.sentence!.id,
        ],
        expected,
        reason: 'seed $seed, listed $listed',
      );

      final withRoles = {
        for (final MapEntry(:key, :value)
            in (drawn.languageData['constructions'] as Map).entries)
          if ((value as Map)['roles'] != null) key,
      };
      expect(
        [
          for (final s in sentenceSlices(
            const OneSentence(withRoles: true),
            Cube(ctx),
          ))
            s.sentence!.id,
        ],
        [
          for (final s in drawn.corpus['sentences'] as List)
            if (withRoles.contains((s['construction'] as Map)['kind'])) s['id'],
        ],
        reason: 'seed $seed',
      );
      final marks = SpecGenerator(
        KindSpec(
          kind: ExerciseKind.markieren,
          questionKey: 'exercise.tap.question',
          select: const OneSentence(withRoles: true),
          params: const {},
          answer: const Marks(),
        ),
      );
      final ticks = SpecGenerator(
        KindSpec(
          kind: ExerciseKind.satzAnkreuzen,
          questionKey: 'exercise.ticks.question',
          select: const OneSentence(),
          params: const {'sentence': SentenceText()},
          answer: TickMany(count: 4),
        ),
      );
      var built = 0;
      for (final s in corpus.sentences.take(12)) {
        final token = s.tokens.whereType<FormToken>().first;
        final word = itemOfToken(items, token);
        final bundle = bundleOf(word, token.key);
        for (final g in [marks, ticks]) {
          final Exercise e;
          try {
            e = g.build(word, bundle, ctx, Random(seed));
          } on CannotBuild {
            continue;
          }
          built++;
          switch (e.answer) {
            case final MarksAnswer a:
              final c = corpus.sentences
                  .singleWhere((s) => s.id == a.sentenceId)
                  .construction;
              final roles =
                  ((drawn.languageData['constructions'] as Map)[c.kind]
                          as Map)['roles']
                      as Map;
              expect(a.pills.map((p) => p.role), [
                roles['head'],
                roles['reference'],
              ]);
            case final TickAnswer a:
              for (final o in a.options) {
                expect(
                  o.mistake == null ||
                      drawn.language.mistakes.contains(o.mistake),
                  isTrue,
                  reason: '${o.mistake}',
                );
              }
            default:
              fail('${e.answer.runtimeType}');
          }
        }
      }
      expect(built, greaterThan(0), reason: 'seed $seed');
    }
  });

  test('a code the language lacks is refused with the sentence id', () {
    final drawn = drawnSentenceLanguage(Random(1));
    final sentences = drawn.corpus['sentences'] as List;
    for (var i = 0; i < sentences.length; i++) {
      for (final spot in ['kind', 'meaning', 'mistake']) {
        final data =
            jsonDecode(jsonEncode(drawn.corpus)) as Map<String, dynamic>;
        final s = (data['sentences'] as List)[i] as Map<String, dynamic>;
        final c = s['construction'] as Map<String, dynamic>;
        switch (spot) {
          case 'kind':
            c['kind'] = _constructions[i % _constructions.length];
          case 'meaning':
            if (c['meaning'] == null) continue;
            c['meaning'] = [_meanings.first];
          default:
            ((s['wrong'] as List).first as Map)['mistake'] =
                _mistakes[i % _mistakes.length];
        }
        expect(
          () => parseSentenceCorpus(jsonEncode(data), drawn.language),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(contains(s['id'] as String), contains('no ')),
            ),
          ),
          reason: '${s['id']} $spot',
        );
      }
    }
  });

  test('a reference word on a construction without one is refused with '
      'the sentence id', () {
    final drawn = drawnSentenceLanguage(Random(2));
    final data = jsonDecode(jsonEncode(drawn.corpus)) as Map<String, dynamic>;
    final s = (data['sentences'] as List).first as Map<String, dynamic>;
    final c = s['construction'] as Map<String, dynamic>;
    c['reference'] = 0;
    expect(
      () => parseSentenceCorpus(jsonEncode(data), drawn.language),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains(s['id'] as String),
        ),
      ),
    );
  });

  test('a construction whose roles do not fit its reference, or that names '
      'an unknown pill role, is refused with its path', () {
    const roleKeys = ['head', 'reference'];
    final latin = latinLanguageData();
    final withRoles = [
      for (final e in (latin['constructions'] as Map).entries)
        if ((e.value as Map)['roles'] != null) e.key as String,
    ];
    final without = [
      for (final e in (latin['constructions'] as Map).entries)
        if ((e.value as Map)['roles'] == null) e.key as String,
    ];
    void refused(
      void Function(Map<String, dynamic> constructions) break_,
      String path,
    ) {
      final data = latinLanguageData();
      break_(data['constructions'] as Map<String, dynamic>);
      expect(
        () => Language.parse(jsonEncode(data)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(path),
          ),
        ),
      );
    }

    for (final code in withRoles) {
      refused((c) => (c[code] as Map).remove('roles'), 'constructions.$code');
      for (final key in roleKeys) {
        refused(
          (c) => ((c[code] as Map)['roles'] as Map)[key] = 'nonsense',
          'constructions.$code.roles.$key',
        );
      }
    }
    for (final code in without) {
      refused(
        (c) => (c[code] as Map)['roles'] = {
          'head': 'participle',
          'reference': 'reference',
        },
        'constructions.$code',
      );
    }
  });

  test('a sentence whose reference or meaning does not fit its '
      'construction is refused with the sentence id', () {
    Map<String, dynamic> flippedShape(
      Map<String, dynamic> corpus,
      int i,
      String key,
      String meaning,
    ) {
      final data = jsonDecode(jsonEncode(corpus)) as Map<String, dynamic>;
      final c =
          ((data['sentences'] as List)[i]
                  as Map<String, dynamic>)['construction']
              as Map<String, dynamic>;
      if (c[key] != null) {
        c.remove(key);
      } else {
        c[key] = key == 'reference' ? 0 : [meaning];
      }
      return data;
    }

    for (var seed = 0; seed < 5; seed++) {
      final drawn = drawnSentenceLanguage(Random(seed));
      final sentences = drawn.corpus['sentences'] as List;
      for (var i = 0; i < sentences.length; i++) {
        final id = (sentences[i] as Map)['id'] as String;
        for (final key in ['reference', 'meaning']) {
          final data = flippedShape(
            drawn.corpus,
            i,
            key,
            drawn.language.meanings.first,
          );
          expect(
            () => parseSentenceCorpus(jsonEncode(data), drawn.language),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains(id),
              ),
            ),
            reason: 'seed $seed, $id, $key',
          );
        }
      }
    }
  });
}
