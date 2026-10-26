import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/providers/round_providers.dart';
import 'package:latin_practice/providers/settings_provider.dart';

import 'support/course_providers.dart';

/// Records the macron switch of every context a round builds with.
class _Recording implements ExerciseGenerator {
  _Recording(this.inner, this.seen);

  final ExerciseGenerator inner;
  final List<bool> seen;

  @override
  ExerciseKind get kind => inner.kind;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    seen.add(ctx.avoidMacronTwins);
    return inner.build(word, bundle, ctx, rng);
  }
}

/// Builds [word] in [bundle] with a fixed draw, whatever the round asks, so
/// that only the context decides whether the exercise is a macron twin.
class _Pinned implements ExerciseGenerator {
  const _Pinned(this.inner, this.word, this.bundle, this.seed);

  final ExerciseGenerator inner;
  final PracticeItem word;
  final GrammarBundle bundle;
  final int seed;

  @override
  ExerciseKind get kind => inner.kind;

  @override
  Exercise build(
    PracticeItem _,
    GrammarBundle _,
    ExerciseContext ctx,
    Random _,
  ) => inner.build(word, bundle, ctx, Random(seed));
}

bool _isTwinPairing(Exercise e) =>
    (e.answer as MatchingAnswer).pairs
        .map((p) => norm(p.$1.text))
        .toSet()
        .length <
    4;

bool _isTwinChain(Exercise e) => (e.answer as TypedAnswer).accepted
    .map(norm)
    .contains(norm(e.questionParams['start']!));

ProviderContainer _container(List<ExerciseGenerator> registry) {
  seedSettings(
    Settings(
      courseWords: LessonRange(5, 5),
      courseGrammar: LessonRange.full,
      grammarToLinked: false,
    ),
  );
  final container = ProviderContainer(
    retry: noRetry,
    overrides: [
      dataLanguageProvider.overrideWith((ref) => 'de'),
      exerciseRandomProvider.overrideWithValue(Random(17)),
      exerciseRegistryProvider.overrideWithValue(registry),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<List<Exercise>> _round(ProviderContainer c, String dataFileId) async {
  final topic = (await c.read(
    topicsProvider.future,
  )).firstWhere((t) => t.dataFileId == dataFileId);
  final provider = roundProvider(BlockedRound(topic.id));
  c.listen(provider, (_, _) {});
  final exercises = [
    for (final task in (await c.read(provider.future)).queue) task.exercise,
  ];
  c.invalidate(provider);
  return exercises;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a round passes the stored macron switch into every exercise '
      'context', () async {
    final seen = <bool>[];
    final c = _container([
      for (final g in exerciseGenerators) _Recording(g, seen),
    ]);
    await c.read(settingsProvider.future);
    for (final avoid in [true, false]) {
      await c.read(settingsProvider.notifier).setAvoidMacronTwins(avoid);
      seen.clear();
      await _round(c, 'nouns');
      expect(seen, isNotEmpty);
      expect(seen.toSet(), {avoid});
    }
  });

  test('flipping the macron switch changes zuordnen and formenKette', () async {
    final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final puella = nouns.singleWhere((i) => i.lemma.startsWith('puella'));
    final legere = verbs.singleWhere((i) => i.id == 'verbs:legere');
    final german = await (() async {
      final c = ProviderContainer(
        overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
      );
      addTearDown(c.dispose);
      return c.read(germanFormsProvider.future);
    })();

    // The draw that yields a twin when twins are allowed is found with the
    // generator alone, so that the round has only to pass the switch on.
    _Pinned pinned(
      ExerciseKind kind,
      PracticeItem word,
      GrammarBundle bundle,
      bool Function(Exercise) isTwin,
    ) {
      final inner = exerciseGenerators.singleWhere((g) => g.kind == kind);
      final allowing = ExerciseContext(
        unlocked: {for (final k in word.formOrder) bundleOf(word, k)},
        pool: [word],
        german: german,
        avoidMacronTwins: false,
      );
      final seed = Iterable<int>.generate(2000).firstWhere((seed) {
        try {
          return isTwin(inner.build(word, bundle, allowing, Random(seed)));
        } on CannotBuild {
          return false;
        }
      });
      return _Pinned(inner, word, bundle, seed);
    }

    final zuordnen = pinned(
      ExerciseKind.zuordnen,
      puella,
      puella.type,
      _isTwinPairing,
    );
    final formenKette = pinned(
      ExerciseKind.formenKette,
      legere,
      'ind.fut2.akt',
      _isTwinChain,
    );
    final c = _container([zuordnen, formenKette]);
    await c.read(settingsProvider.future);
    for (final avoid in [true, false, true]) {
      await c.read(settingsProvider.notifier).setAvoidMacronTwins(avoid);
      // A noun round asks zuordnen; a verb round cannot, and asks formenKette.
      for (final (file, isTwin) in [
        ('nouns', _isTwinPairing),
        ('verbs', _isTwinChain),
      ]) {
        final exercises = await _round(c, file);
        expect(exercises, isNotEmpty);
        expect(
          exercises.map(isTwin).toSet(),
          {!avoid},
          reason: '$file round with avoidMacronTwins $avoid',
        );
      }
    }
  });
}
