import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/word_focus.dart';
import 'package:latin_practice/grammar/schema.dart' show dataLanguages;
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/providers/round_providers.dart';

import 'support/course_providers.dart';
import 'support/grammar_exercise_harness.dart';

const _lesson24 = {
  'nōnne',
  'num',
  'utrum ... an',
  'neque (nec)',
  'quī (fragend)',
  'laudibus afficere',
};

const _lesson26 = {
  'negōtia agere',
  'aliī... aliī',
  'plūs valēre',
  'summum bonum',
  'aliquem aliquid facere',
  'aliquem aliquid putāre',
  'aliquem aliquid dūcere',
  'aliquem aliquid vocāre',
  'aliquem aliquid appellāre',
  'sē aliquem praebēre',
};

/// The pairs whose book meanings are equal or one holds the other; they
/// overlap in every data language.
const _overlappingMeanings = [
  {'aliquem aliquid putāre', 'aliquem aliquid dūcere'},
  {'aliquem aliquid vocāre', 'aliquem aliquid appellāre'},
  {'nōnne', 'num'},
];

const _vocabKinds = {
  ExerciseKind.latDeWahl,
  ExerciseKind.deLatWahl,
  ExerciseKind.deLatTippen,
  ExerciseKind.zuordnen,
};

ProviderContainer _container() => ProviderContainer(
  retry: noRetry,
  overrides: [
    dataLanguageProvider.overrideWith((ref) => 'de'),
    exerciseRandomProvider.overrideWithValue(Random(5)),
  ],
);

/// Plays a round of vocab only with the words of [lesson] to its end, every
/// answer right, and returns the lemmas it asked.
Future<Set<String>> _playVocabRound(int lesson) async {
  seedSettings(Settings(courseWords: LessonRange(lesson, lesson)));
  final c = _container();
  addTearDown(c.dispose);

  final practicable = await c.read(practicableItemsByTypeProvider.future);
  final vocab = {for (final w in practicable['vocab']!) w.lemma};

  final provider = roundProvider(
    const MixedRound(TypeFocus('vocab', 'Vokabel', 'Vokabel')),
  );
  c.listen(provider, (_, _) {});
  var state = await c.read(provider.future);
  final asked = <String>{};
  for (var n = 0; !state.isOver; n++) {
    expect(n, lessThan(20), reason: 'the round does not end');
    final task = state.queue.first;
    expect(task.word.isVocab, isTrue, reason: task.word.id);
    expect(_vocabKinds, contains(task.exercise.kind));
    asked.add(task.word.lemma);
    await c
        .read(provider.notifier)
        .respond(rightAndWrong(task.word, task.exercise).$1);
    await c.pump();
    state = await c.read(provider.future);
  }
  expect(asked, vocab);
  return vocab;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'with words L24–L24 the lesson 24 words and phrases are practised',
    () async {
      expect(await _playVocabRound(24), _lesson24);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'with words L26–L26 the phrases and double-accusative meanings are practised',
    () async {
      expect(await _playVocabRound(26), _lesson26);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('a new meaning keeps the known word in its first lesson', () async {
    final lessons = await loadLessonData(bookAssets);
    final items = await loadAllPracticeItems();
    int lessonOf(String lemma) =>
        lessons.lessonNumberOf(items.singleWhere((i) => i.lemma == lemma));

    expect(lessonOf('putāre'), lessThan(26));
    expect(lessonOf('aliquem aliquid putāre'), 26);
    expect(lessonOf('quī'), lessThan(24));
    expect(lessonOf('quī (fragend)'), 24);
  });

  test('only the translation kinds ask a vocab item', () async {
    final vocab = await loadPracticeItems('lib/data/latin_vocab.yaml');
    final ctx = ExerciseContext(
      unlocked: {'Vokabel'},
      pool: vocab,
      german: const NoForms(),
    );
    for (final word in vocab) {
      for (final generator in exerciseGenerators) {
        if (_vocabKinds.contains(generator.kind)) {
          final exercise = generator.build(word, 'Vokabel', ctx, Random(1));
          expect(
            generator.objections(exercise, word, 'Vokabel', ctx),
            isEmpty,
            reason: '${generator.kind.name} ${word.lemma}',
          );
        } else {
          expect(
            () => generator.build(word, 'Vokabel', ctx, Random(1)),
            throwsA(isA<CannotBuild>()),
          );
        }
      }
    }
  });

  test(
    'a vocab exercise never shows two items of overlapping meaning',
    () async {
      final shown = <String>{};
      for (final language in dataLanguages) {
        final vocab = await loadPracticeItems(
          'lib/data/latin_vocab.yaml',
          language: language,
        );
        final lemmaOf = {for (final w in vocab) w.id: w.lemma};
        final ctx = ExerciseContext(
          unlocked: {'Vokabel'},
          pool: vocab,
          german: const NoForms(),
        );
        for (final word in vocab) {
          for (final generator in exerciseGenerators) {
            if (!_vocabKinds.contains(generator.kind)) continue;
            for (var seed = 0; seed < 20; seed++) {
              final exercise = generator.build(
                word,
                'Vokabel',
                ctx,
                Random(seed),
              );
              final lemmas = switch (exercise.answer) {
                ChoiceAnswer(:final options) => {
                  for (final o in options) lemmaOf[o.lexemeId]!,
                },
                MatchingAnswer(:final pairs) => {
                  for (final (o, _) in pairs) lemmaOf[o.lexemeId]!,
                },
                _ => <String>{},
              };
              for (final pair in _overlappingMeanings) {
                if (lemmas.containsAll(pair)) {
                  shown.add(
                    '$language ${generator.kind.name} ${word.lemma}: $pair',
                  );
                }
              }
            }
          }
        }
      }
      expect(shown, isEmpty, reason: shown.join('\n'));
    },
  );

  test('a vocab item accepts each spelling it gives', () async {
    final neque = (await loadPracticeItems(
      'lib/data/latin_vocab.yaml',
    )).singleWhere((i) => i.lemma == 'neque (nec)');
    expect(neque.acceptedForms.single, ['neque (nec)', 'neque', 'nec']);
  });
}
