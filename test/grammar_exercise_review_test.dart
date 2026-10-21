import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/grammar_exercise_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container() => ProviderContainer(
    retry: noRetry,
    overrides: [
      dataLanguageProvider.overrideWith((ref) => 'de'),
      exerciseRandomProvider.overrideWithValue(Random(139)),
    ],
  );

  for (final (name, pick) in [
    ('right', (ExerciseResponse r, ExerciseResponse _) => r),
    ('wrong', (ExerciseResponse _, ExerciseResponse w) => w),
  ]) {
    test('a $name response reviews the word card and the grammar card of '
        'the picked exercise as the attribution rates them', () async {
      SharedPreferences.setMockInitialValues({});
      final c = container();
      addTearDown(c.dispose);
      final asked = (await c.read(nextGrammarExerciseProvider.future))!;
      final (:word, :exercise) = asked;
      final before = await c.read(fsrsCardsProvider.future);
      final scheduler = c.read(fsrsSchedulerProvider);
      final (right, wrong) = rightAndWrong(word, exercise);
      final response = pick(right, wrong);
      final rating = attribute(word, exercise, response);

      await reviewExerciseCards(scheduler, before, asked, response);

      final stored = await FsrsStorage.loadCards();
      final ratings = {
        exercise.wordCardId: rating.word,
        exercise.grammarCardId: rating.grammar,
      };
      for (final MapEntry(key: id, value: r) in ratings.entries) {
        final expected = r == null
            ? before[id]!.card
            : scheduler.reviewCard(before[id]!.card, r).card;
        expect(stored[id]!.card.stability, expected.stability, reason: id);
        expect(stored[id]!.card.state, expected.state, reason: id);
        expect(stored[id]!.lastReview != null, r != null, reason: id);
      }
      final others = {...stored.keys}..removeAll(ratings.keys);
      for (final id in others) {
        expect(stored[id]!.lastReview, before[id]!.lastReview, reason: id);
      }
    });
  }
}
