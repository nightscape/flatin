import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/languages/language.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/screens/exercise_match_widget.dart';
import 'package:latin_practice/widgets/exercise_question.dart';

import 'support/exercise_fakes.dart';
import 'support/gen_language.dart';
import 'support/gen_prompt_exercises.dart';
import 'support/hand_items.dart';
import 'support/i18n_keys.dart';
import 'support/key_echo_app.dart';
import 'support/latin_course.dart';

const _locales = ['de', 'en'];
const _shared = {'feedback', 'screen'};
const _seeds = 12;

// Generators: drawExercises (reused, gen_prompt_exercises.dart) for the
// exercises, drawnLanguageName (gen_language.dart) for the language
// names. The two key checks are example-based: their inputs are the finite
// enum and the translation files, there is nothing to draw.
void main() {
  final kinds = {for (final s in kindSpecs) s.kind};
  final questionSpecs = [
    ...kindSpecs,
    ...vocabSpecs.values,
    ...agreementSpecs.values,
  ];

  group('the keys of each kind', () {
    for (final code in _locales) {
      final keys = translationKeys(
        code,
      ).where((k) => k.startsWith('exercise.')).toList();

      test(
        'every kind with a generator has keys under its own name in $code',
        () {
          for (final kind in kinds) {
            expect(
              keys.where((k) => k.startsWith('exercise.${kind.name}.')),
              isNotEmpty,
              reason: kind.name,
            );
          }
        },
      );

      test('every exercise key of $code belongs to a kind or is shared', () {
        final owners = {
          ..._shared,
          for (final k in ExerciseKind.values) k.name,
        };
        expect([
          for (final k in keys)
            if (!owners.contains(k.split('.')[1])) k,
        ], isEmpty);
      });

      test('the question key of every spec sits under its kind in $code', () {
        final texts = translationTexts(code);
        for (final spec in questionSpecs) {
          expect(spec.questionKey, startsWith('exercise.${spec.kind.name}.'));
          expect(texts, contains(spec.questionKey));
        }
      });
    }
  });

  group('the language name in texts', () {
    test('no exercise text spells the course language', () {
      for (final code in _locales) {
        final name = latinLang.name[code]!.toLowerCase();
        for (final MapEntry(:key, :value) in translationTexts(code).entries) {
          if (!key.startsWith('exercise.')) continue;
          expect(value.toLowerCase(), isNot(contains(name)), reason: key);
        }
      }
    });

    late List<(PracticeItem, Exercise)> drawn;
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final items = await loadAllPracticeItems();
      final container = ProviderContainer(
        overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
      );
      final glosses = await container.read(germanFormsProvider.future);
      container.dispose();
      drawn = drawExercises(
        items,
        glosses,
        await loadSentenceCorpus(),
        stride: 7,
      );
      final vocab = [
        for (final w in items)
          if (w.isVocab) w,
      ];
      final word = vocab.first;
      final bundle = bundleOf(word, word.formOrder.first);
      drawn.add((
        word,
        generatorFor(ExerciseKind.formWahl, exerciseGenerators).build(
          word,
          bundle,
          fakeExerciseContext(unlocked: {bundle}, pool: vocab),
          Random(1),
        ),
      ));
    });

    test('every built exercise carries the name of its word\'s language', () {
      for (final (word, e) in drawn) {
        expect(e.languageName, word.lang.name, reason: e.questionKey);
      }
    });

    test('a built exercise carries the name its word\'s language file '
        'gives, for drawn names', () {
      const bundle = 'ind.fut.pass';
      for (var seed = 1; seed <= _seeds; seed++) {
        final names = drawnLanguageName(Random(seed));
        final lang = Language.parse(
          jsonEncode(latinLanguageData()..['name'] = names),
        );
        final word = handItem(
          dataFileId: 'verbs',
          lemma: 'synthetica',
          axes: changeableVerbAxes,
          forms: {
            'ind.fut.pass.sg': ['amātus est', 'amātī est'],
            'ind.fut.pass.pl': ['amātī sunt'],
          },
          grammar: Grammar({}, {}, {}, 'de', lang, fileRoles: shippedRoles),
        );
        final e = generatorFor(ExerciseKind.fehlerFinden, exerciseGenerators)
            .build(
              word,
              bundle,
              fakeExerciseContext(unlocked: {bundle}, pool: [word]),
              Random(seed),
            );
        expect(e.languageName, names, reason: 'seed $seed');
      }
    });

    testWidgets('every text with a language placeholder shows the name the '
        'course language has', (tester) async {
      for (final code in _locales) {
        final texts = translationTexts(code);
        final named = {
          for (final MapEntry(:key, :value) in texts.entries)
            if (key.startsWith('exercise.') && value.contains('{language}'))
              key,
        };
        final byKey = <String, (PracticeItem, Exercise)>{};
        for (final d in drawn) {
          byKey.putIfAbsent(d.$2.questionKey, () => d);
        }
        final reached = <String>{};
        for (var seed = 1; seed <= _seeds; seed++) {
          final names = drawnLanguageName(Random(seed));
          for (final MapEntry(:key, :value) in byKey.entries) {
            final (word, drawnExercise) = value;
            final e = withLanguageName(drawnExercise, names);
            final shown = texts[key]!.contains('{language}');
            await tester.pumpWidget(
              wrapInKeyEchoAppWith(
                Scaffold(body: ExerciseQuestion(e)),
                code: code,
              ),
            );
            expect(
              find.textContaining('language=${names[code]}'),
              shown ? findsOneWidget : findsNothing,
              reason: '$code $key',
            );
            if (shown) reached.add(key);
            if (e.answer is MatchingAnswer &&
                (e.answer as MatchingAnswer).agreements == null) {
              await tester.pumpWidget(
                wrapInKeyEchoAppWith(
                  ExerciseMatchWidget(
                    word: word,
                    exercise: e,
                    onResponse: (_) {},
                  ),
                  code: code,
                ),
              );
              await tester.pumpAndSettle();
              expect(
                find.text('exercise.zuordnen.hint{language=${names[code]}}'),
                findsOneWidget,
                reason: '$code zuordnen.hint',
              );
              reached.add('exercise.zuordnen.hint');
            }
          }
        }
        expect(reached, named, reason: code);
      }
    });
  });
}
