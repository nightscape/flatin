// Every draw plays a round over the course up to the sentence lessons, which
// a loaded machine slows past the 30 s default.
@Timeout(Duration(minutes: 10))
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' show Rating;
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/game_rules.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/providers/reward_provider.dart';
import 'package:latin_practice/providers/round_providers.dart';

import 'support/course_providers.dart';
import 'support/gen_sentence_answers.dart';
import 'support/grammar_exercise_harness.dart';
import 'support/recording_rewards.dart';

typedef _Fraction = ({int top, int bottom});

/// The right share of ticking [ticked]: c·ρ^w / k with
/// ρ = (n + 1 − 2k) / (2(n − k)), as an exact fraction.
_Fraction _tickFraction(TickAnswer answer, Set<int> ticked) {
  final n = answer.options.length;
  final right = {
    for (final (i, o) in answer.options.indexed)
      if (o.mistake == null) i,
  };
  final k = right.length;
  final c = ticked.where(right.contains).length;
  final w = ticked.length - c;
  return (
    top: c * pow(n + 1 - 2 * k, w).toInt(),
    bottom: k * pow(2 * (n - k), w).toInt(),
  );
}

_Fraction _marksFraction(MarksAnswer answer, List<int> wordOf) => (
  top: [
    for (final (i, p) in answer.pills.indexed)
      if (wordOf[i] == p.word) p,
  ].length,
  bottom: answer.pills.length,
);

/// Null for an answer that has no right share.
_Fraction? _fractionOf(ExerciseAnswer answer, ExerciseResponse response) =>
    switch ((answer, response)) {
      (final MarksAnswer a, MarksResponse(:final wordOf)) => _marksFraction(
        a,
        wordOf,
      ),
      (final TickAnswer a, TickedOptions(:final ticked)) => _tickFraction(
        a,
        ticked,
      ),
      _ => null,
    };

bool _full(_Fraction f) => f.top == f.bottom;

/// The coins a first attempt earns: 10 when right, else one per full
/// quarter of the right share.
int _firstCoins(_Fraction? f, bool right) =>
    right ? 10 : (f == null ? 0 : 4 * f.top ~/ f.bottom);

/// The rating the sentence kinds gave before partial coins: Good for the
/// full share, Hard from half of it, Again below.
Rating _shareRatingBefore(_Fraction f) => _full(f)
    ? Rating.good
    : 2 * f.top >= f.bottom
    ? Rating.hard
    : Rating.again;

Attribution _attributionBefore(ExerciseAnswer answer, _Fraction f) =>
    switch (answer) {
      MarksAnswer() => (word: Rating.good, grammar: _shareRatingBefore(f)),
      _ => (word: _shareRatingBefore(f), grammar: _shareRatingBefore(f)),
    };

/// A building kind that fits every pair; the round asks it where no
/// sentence kind fits.
class _Fallback implements ExerciseGenerator {
  const _Fallback();

  @override
  ExerciseKind get kind => ExerciseKind.formBilden;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) => Exercise(
    wordCardId: word.id,
    grammarCardId: GrammarCardId(word.dataFileId, bundle),
    kind: kind,
    questionKey: 'q',
    answer: TypedAnswer(
      FormOption(
        text: word.forms.first,
        formKey: word.formOrder.first,
        lexemeId: word.id,
      ),
      [word.forms.first],
    ),
  );
}

const _sentenceKinds = {ExerciseKind.markieren, ExerciseKind.satzAnkreuzen};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rules = GameRules.parse(
    File(gameRulesAsset).readAsStringSync(),
    gameRulesAsset,
  );

  test('through the round, a first attempt of a sentence kind pays 10 when '
      'right and else a coin per quarter of its right share, never more than '
      'the share; with the right retry it pays below 10; the other kinds '
      'carry no partial; the ratings are those of before', () async {
    final corpus = await loadSentenceCorpus();
    final inSentences = {
      for (final s in corpus.sentences)
        for (final t in s.tokens.whereType<FormToken>()) t.lemma,
    };
    final words = await loadAllPracticeItems();
    final registry = <ExerciseGenerator>[
      for (final g in exerciseGenerators)
        if (_sentenceKinds.contains(g.kind)) g,
      const _Fallback(),
    ];
    final rng = Random(365);
    final reach = <String, int>{};
    for (var draw = 0; draw < 12; draw++) {
      seedSettings(
        Settings(
          courseWords: LessonRange(1, 24 + rng.nextInt(3)),
          deselectedWords: {
            for (final w in words)
              if (!inSentences.contains(w.lemma) && rng.nextInt(4) > 0) w.lemma,
          },
        ),
      );
      final sent = <RewardEvent>[];
      final c = ProviderContainer(
        retry: noRetry,
        overrides: [
          dataLanguageProvider.overrideWith((ref) => 'de'),
          exerciseRandomProvider.overrideWithValue(Random(draw)),
          exerciseRegistryProvider.overrideWithValue(registry),
          rewardsProvider.overrideWith(() => RecordingRewards(sent)),
        ],
      );
      addTearDown(c.dispose);
      final provider = roundProvider(const MixedRound());
      c.listen(provider, (_, _) {});
      var state = await c.read(provider.future);
      final chainOf = [for (var i = 0; i < state.queue.length; i++) i];
      final coinsOf = <int, int>{};
      final firstOf =
          <int, ({ExerciseKind kind, _Fraction? share, bool right})>{};
      final retriesOf = <int, int>{};
      var earned = 0;
      for (var n = 0; !state.isOver; n++) {
        expect(n, lessThan(60), reason: 'the round does not end');
        final task = state.queue.first;
        final chain = chainOf.removeAt(0);
        final exercise = task.exercise;
        final (right, wrong) = rightAndWrong(task.word, exercise);
        final ExerciseResponse response;
        if (task.isRetry) {
          final retries = retriesOf.update(chain, (r) => r + 1);
          response = retries < 3 && rng.nextInt(3) == 0 ? wrong : right;
        } else {
          retriesOf[chain] = 0;
          response = switch (exercise.answer) {
            _ when rng.nextInt(4) == 0 => right,
            final TickAnswer a => drawTicks(rng, a),
            final MarksAnswer a => drawMarks(rng, a),
            _ => wrong,
          };
        }
        final share = _fractionOf(exercise.answer, response);
        final full = share == null ? identical(response, right) : _full(share);
        if (share != null) {
          expect(
            attribute(task.word, exercise, response),
            _attributionBefore(exercise.answer, share),
            reason: 'draw $draw, answer $n',
          );
        }
        await c.read(provider.notifier).respond(response);
        state = await c.read(provider.future);
        final answered = sent.whereType<Answered>().last;
        expect(answered.right, full, reason: 'draw $draw, answer $n');
        if (share == null || full) {
          expect(answered.partial, 0, reason: 'draw $draw, answer $n');
        }
        final ledger = await c.read(rewardsProvider.future);
        expect(ledger.taggedOf(coins, 'bonus'), 0, reason: 'fresh cards');
        final gained = ledger.earnedOf(coins) - earned;
        expect(gained, greaterThanOrEqualTo(0));
        earned = ledger.earnedOf(coins);
        coinsOf.update(chain, (s) => s + gained, ifAbsent: () => gained);
        if (!task.isRetry) {
          firstOf[chain] = (kind: exercise.kind, share: share, right: full);
          expect(
            gained,
            _firstCoins(share, full),
            reason: 'draw $draw, answer $n',
          );
        } else {
          expect(gained, full ? 5 : 0, reason: 'draw $draw, answer $n');
        }
        if (!full) chainOf.add(chain);
        expect(chainOf, hasLength(state.queue.length));
      }
      for (final MapEntry(key: chain, value: first) in firstOf.entries) {
        final key = [
          first.share == null ? 'other' : first.kind.name,
          first.right
              ? 'right'
              : _firstCoins(first.share, false) > 0
              ? 'partial'
              : 'wrong',
        ].join(' ');
        reach.update(key, (n) => n + 1, ifAbsent: () => 1);
        expect(
          coinsOf[chain],
          first.right ? 10 : lessThan(10),
          reason: 'draw $draw, task $chain $key',
        );
      }
    }
    expect(
      reach.keys,
      containsAll([
        for (final k in _sentenceKinds) ...[
          '${k.name} partial',
          '${k.name} right',
        ],
      ]),
    );
    expect(reach.keys, containsAll(['other wrong', 'other right']));
  });

  test('a sentence answer pays a coin per quarter of its right share, ticking '
      'every option pays no more than the share, and the ratings are those of '
      'before', () async {
    final sentence = (await loadSentenceCorpus()).sentences.first;
    final word = (await loadAllPracticeItems()).first;
    ({String text, Mistake? mistake}) right(int i) =>
        (text: 'right $i', mistake: null);
    ({String text, Mistake? mistake}) wrong(int i) =>
        (text: 'wrong $i', mistake: Mistake.values.first);
    MarksAnswer marks(int words, List<int> pills) => MarksAnswer(
      'fixed',
      [for (var w = 0; w < words; w++) 'w$w'],
      [for (final (i, w) in pills.indexed) (role: 'role $i', word: w)],
      const FormOption(text: 'w0', formKey: 'nom.sg', lexemeId: 'fixed'),
    );
    final fixed = <(ExerciseAnswer, ExerciseResponse)>[
      // Ticking every option.
      (
        TickAnswer(sentence, [right(0), right(1), wrong(0), wrong(1)]),
        TickedOptions({0, 1, 2, 3}),
      ),
      (
        TickAnswer(sentence, [right(0), wrong(0), wrong(1), wrong(2)]),
        TickedOptions({0, 1, 2, 3}),
      ),
      (
        TickAnswer(sentence, [
          right(0),
          right(1),
          right(2),
          wrong(0),
          wrong(1),
          wrong(2),
        ]),
        TickedOptions({0, 1, 2, 3, 4, 5}),
      ),
      (
        TickAnswer(sentence, [right(0), right(1), wrong(0), wrong(1)]),
        TickedOptions({0}),
      ),
      (marks(4, [0, 2]), const MarksResponse([0, 0])),
      (marks(4, [0, 2]), const MarksResponse([2, 0])),
      (marks(5, [0, 1, 2, 3]), const MarksResponse([0, 1, 2, 4])),
    ];
    final rng = Random(3650);
    final drawn = <(ExerciseAnswer, ExerciseResponse)>[
      for (var i = 0; i < 400; i++)
        if (rng.nextBool())
          () {
            final a = drawTickAnswer(rng, sentence);
            return (a, drawTicks(rng, a));
          }()
        else
          () {
            final a = drawMarksAnswer(rng);
            return (a, drawMarks(rng, a));
          }(),
    ];
    for (final (i, (answer, response)) in [...fixed, ...drawn].indexed) {
      final share = _fractionOf(answer, response)!;
      final exercise = Exercise(
        wordCardId: word.id,
        grammarCardId: GrammarCardId(
          word.dataFileId,
          bundleOf(word, word.formOrder.first),
        ),
        kind: answer is TickAnswer
            ? ExerciseKind.satzAnkreuzen
            : ExerciseKind.markieren,
        questionKey: 'q',
        answer: answer,
      );
      final attribution = attribute(word, exercise, response);
      expect(attribution, _attributionBefore(answer, share), reason: '$i');
      final full = isRight(attribution);
      final event = Answered(
        right: full,
        firstAttempt: true,
        wordDifficulty: null,
        kind: exercise.kind.name,
        dataFile: 'f',
        partial: full ? 0 : partialOf(answer, response),
        at: DateTime(2026),
      );
      final gained = rules
          .gainsOf(const RewardLedger(), event)
          .fold(0, (s, g) => s + g.amount);
      expect(gained, _firstCoins(share, full), reason: '$i');
      expect(
        gained * share.bottom,
        full ? 10 * share.bottom : lessThanOrEqualTo(4 * share.top),
        reason: '$i: more than the share',
      );
    }
  });
}
