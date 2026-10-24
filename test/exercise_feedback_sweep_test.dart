import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_feedback.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

import 'exercise_pair_sweep_test.dart' show sweep;

/// Builds, on the first call for a word, every kind that fits it, so that the
/// sweep reaches kinds the selection would only ask later.
class _Recording implements ExerciseGenerator {
  _Recording(this._inner, this._all, this._built, this._teed);

  final ExerciseGenerator _inner;
  final List<ExerciseGenerator> _all;
  final List<(PracticeItem, Exercise)> _built;
  final Set<String> _teed;

  @override
  ExerciseKind get kind => _inner.kind;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    if (_teed.add(word.id)) {
      for (final g in _all) {
        try {
          _built.add((word, g.build(word, bundle, ctx, Random(0))));
        } on CannotBuild {
          continue;
        }
      }
    }
    return _inner.build(word, bundle, ctx, rng);
  }
}

List<ExerciseResponse> _responses(Exercise exercise) =>
    switch (exercise.answer) {
      TypedAnswer(:final expected) => [
        TypedText(expected.text),
        const TypedText('xyz'),
      ],
      ChoiceAnswer(:final options, :final right) => [
        for (final o in [right, options.firstWhere((o) => o != right)])
          ChosenOption(o),
      ],
      MatchingAnswer(:final pairs) => [MatchedPairs(pairs)],
    };

void main() {
  late List<PracticeItem> items;
  late GermanForms german;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    items = await loadAllPracticeItems();
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    german = await container.read(germanFormsProvider.future);
    container.dispose();
  });

  void expectFeedback(GermanForms forms, String locale) {
    final built = <(PracticeItem, Exercise)>[];
    final teed = <String>{};
    sweep(
      items,
      forms,
      locale,
      registry: [
        for (final g in exerciseGenerators)
          _Recording(g, exerciseGenerators, built, teed),
      ],
    );
    expect(built, isNotEmpty);
    for (final (word, exercise) in built) {
      for (final response in _responses(exercise)) {
        expect(
          feedbackLines(word, exercise, response),
          isNotEmpty,
          reason: '${word.id} ${exercise.kind.name} $response',
        );
      }
    }
  }

  test(
    'every built exercise has feedback lines for a right and a wrong response '
    'in the German UI',
    () => expectFeedback(german, 'de'),
    tags: 'sweep',
  );

  test(
    'every built exercise has feedback lines for a right and a wrong response '
    'in the English UI',
    () => expectFeedback(const NoForms(), 'en'),
    tags: 'sweep',
  );
}
