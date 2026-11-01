import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/exercise_feedback.dart';
import 'package:latin_practice/data/exercise_interpreter.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/exercise_fakes.dart';
import 'support/exercise_invariants.dart';
import 'support/gen_sentence_learner.dart';
import 'support/grammar_exercise_harness.dart';

/// The pills each supported construction asks, head first: the corpus marks
/// a construction's head and its reference word.
const _roles = {
  ConstructionKind.pcPpa: ['participle', 'reference'],
  ConstructionKind.pcPpp: ['participle', 'reference'],
  ConstructionKind.aciPassiv: ['participle', 'subject'],
  ConstructionKind.doppelterAkkusativ: ['predicative', 'object'],
};

/// The rating rule written as shares: all right Good, half or more Hard,
/// less Again.
Rating _ratingOf(int right, int all) => right == all
    ? Rating.good
    : right / all >= 0.5
    ? Rating.hard
    : Rating.again;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SentenceCorpus corpus;
  late List<PracticeItem> items;
  late SentenceLearner everything;
  final generator =
      generatorFor(ExerciseKind.markieren, exerciseGenerators) as SpecGenerator;

  setUpAll(() async {
    corpus = await loadSentenceCorpus();
    items = await loadAllPracticeItems();
    everything = (
      reached: laterLesson,
      unlocked: {
        for (final w in items)
          for (final k in w.formOrder) bundleOf(w, k),
      },
      pool: items,
      practised: (_, _) => true,
    );
  });

  ExerciseContext contextOf(SentenceLearner l) => ExerciseContext(
    unlocked: l.unlocked,
    pool: l.pool,
    german: fakeExerciseContext().german,
    sentences: corpus,
    reachedLesson: l.reached,
    formPracticed: l.practised,
  );

  /// Everything, but the form of token [at] of sentence [id] switched off.
  SentenceLearner formOff(String id, int Function(Construction c) at) {
    final s = corpus.sentences.singleWhere((s) => s.id == id);
    final t = s.tokens[at(s.construction)] as FormToken;
    final word = itemOfToken(items, t);
    return (
      reached: everything.reached,
      unlocked: everything.unlocked,
      pool: items,
      practised: (w, l) => !(w.id == word.id && l.key == t.key),
    );
  }

  SentenceLearner headOff(String id) => formOff(id, (c) => c.head);

  SentenceLearner referenceOff(String id) => formOff(id, (c) => c.reference!);

  /// Every (word, bundle) a form token of the corpus holds.
  List<(PracticeItem, GrammarBundle)> heldPairs() => {
    for (final s in corpus.sentences)
      for (final t in s.tokens.whereType<FormToken>())
        (itemOfToken(items, t), bundleOf(itemOfToken(items, t), t.key)),
  }.toList();

  /// Whether token [i] of [s] is a form of [word] in [bundle].
  bool marks(Sentence s, int i, PracticeItem word, GrammarBundle bundle) =>
      switch (s.tokens[i]) {
        FormToken(:final lemma, :final key) =>
          lemma == word.lemma && bundleOf(word, key) == bundle,
        HeadwordToken() => false,
      };

  /// Whether token [i] of [s] is a form of [word] in [bundle] that [learner]
  /// practises.
  bool rates(
    SentenceLearner learner,
    Sentence s,
    int i,
    PracticeItem word,
    GrammarBundle bundle,
  ) =>
      marks(s, i, word, bundle) &&
      learner.practised(
        word,
        word.formLabels[word.formOrder.indexOf((s.tokens[i] as FormToken).key)],
      );

  /// Checks one build of [word] in [bundle] for [learner] against the corpus
  /// fields; returns whether it built, and the pill roles at which a visible
  /// sentence marks the pair with a switched-off form.
  ({bool built, Set<String> switchedOff}) expectBuild(
    SentenceLearner learner,
    PracticeItem word,
    GrammarBundle bundle,
    int seed,
  ) {
    final ctx = contextOf(learner);
    final visible = visibleSentences(
      corpus,
      learner,
      constructions: {for (final k in _roles.keys) k.name},
    );
    final pillsOf = [
      for (final s in visible) [s.construction.head, s.construction.reference!],
    ];
    final fitting = [
      for (final (j, s) in visible.indexed)
        if (pillsOf[j].any((i) => rates(learner, s, i, word, bundle))) s,
    ];
    final switchedOff = {
      for (final (j, s) in visible.indexed)
        for (final (role, i) in [('head', 0), ('reference', 1)])
          if (marks(s, pillsOf[j][i], word, bundle) &&
              !rates(learner, s, pillsOf[j][i], word, bundle))
            role,
    };
    final why = '${word.id} $bundle, reached ${learner.reached}';
    final Exercise e;
    try {
      e = generator.build(word, bundle, ctx, Random(seed));
    } on CannotBuild catch (decline) {
      expect(fitting, isEmpty, reason: '$why: ${decline.reason}');
      expect(decline.reason, isNotEmpty);
      return (built: false, switchedOff: switchedOff);
    }
    expect(fitting, isNotEmpty, reason: why);
    final answer = e.answer as MarksAnswer;
    expect(
      [for (final s in fitting) s.id],
      contains(answer.sentenceId),
      reason: why,
    );
    final s = fitting.singleWhere((s) => s.id == answer.sentenceId);
    final c = s.construction;
    expect(_roles.keys, contains(c.kind), reason: why);
    expect(answer.words, [for (final t in s.tokens) t.text], reason: why);
    expect(answer.pills, [
      (role: _roles[c.kind]![0], word: c.head),
      (role: _roles[c.kind]![1], word: c.reference!),
    ], reason: why);
    expect(answer.target.lexemeId, word.id, reason: why);
    expect(bundleOf(word, answer.target.formKey), bundle, reason: why);
    expect(
      learner.practised(
        word,
        word.formLabels[word.formOrder.indexOf(answer.target.formKey)],
      ),
      isTrue,
      reason: why,
    );
    expect(e.wordCardId, word.id);
    expect(e.grammarCardId, GrammarCardId(word.dataFileId, bundle));
    expect(generator.objections(e, word, bundle, ctx), isEmpty, reason: why);
    expect(
      violations(e, generator.spec, word, bundle, ctx),
      isEmpty,
      reason: why,
    );
    return (built: true, switchedOff: switchedOff);
  }

  test('every held pair builds on a sentence whose construction marks it at '
      'a practised form, with the pills of its corpus fields, or declines '
      'with a reason', () {
    final outcomes = <bool, int>{};
    final switchedOff = <String, int>{};
    void count(({bool built, Set<String> switchedOff}) o) {
      outcomes.update(o.built, (n) => n + 1, ifAbsent: () => 1);
      for (final role in o.switchedOff) {
        switchedOff.update(role, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    final pairs = heldPairs();
    final fixed = <SentenceLearner>[
      everything,
      (
        reached: 1,
        unlocked: everything.unlocked,
        pool: items,
        practised: everything.practised,
      ),
      (
        reached: laterLesson,
        unlocked: const {},
        pool: items,
        practised: everything.practised,
      ),
      for (var n = 1; n <= 6; n++) headOff('l24-aci-$n'),
      for (final s in corpus.sentences)
        if (_roles.containsKey(s.construction.kind)) referenceOff(s.id),
    ];
    for (final learner in fixed) {
      for (final (word, bundle) in pairs) {
        if (word.isVocab) continue;
        count(expectBuild(learner, word, bundle, 0));
      }
    }
    final fixedSwitchedOff = {...switchedOff};
    final rng = Random(322);
    for (var run = 0; run < 80; run++) {
      final learner = drawSentenceLearner(rng, corpus, items);
      final withOff = [
        for (final (word, bundle) in pairs)
          if ([
            for (final (i, k) in word.formOrder.indexed)
              if (bundleOf(word, k) == bundle) word.formLabels[i],
          ].any((l) => !learner.practised(word, l)))
            (word, bundle),
      ];
      for (final (word, bundle) in [
        ...(pairs.toList()..shuffle(rng)).take(4),
        ...(withOff..shuffle(rng)).take(2),
      ]) {
        if (word.isVocab) continue;
        count(expectBuild(learner, word, bundle, run));
      }
    }
    expect(outcomes.keys.toSet(), {true, false}, reason: '$outcomes');
    for (final role in ['head', 'reference']) {
      final fixedRuns = fixedSwitchedOff[role] ?? 0;
      expect(fixedRuns, greaterThan(0), reason: '$role off, static');
      expect(
        (switchedOff[role] ?? 0) - fixedRuns,
        greaterThan(0),
        reason: '$role off, drawn',
      );
    }
  });

  test('every sentence of a supported construction builds for the word of '
      'its head and of its reference', () {
    final ctx = contextOf(everything);
    for (final s in corpus.sentences) {
      if (!_roles.containsKey(s.construction.kind)) continue;
      for (final i in [s.construction.head, s.construction.reference!]) {
        final t = s.tokens[i] as FormToken;
        final word = itemOfToken(items, t);
        final seen = <String>{};
        for (var seed = 0; seed < 40 && !seen.contains(s.id); seed++) {
          final e = generator.build(
            word,
            bundleOf(word, t.key),
            ctx,
            Random(seed),
          );
          seen.add((e.answer as MarksAnswer).sentenceId);
        }
        expect(seen, contains(s.id), reason: '${s.id} token $i');
      }
    }
  });

  test('a context without the corpus declines every pair with its reason', () {
    final ctx = fakeExerciseContext(unlocked: everything.unlocked, pool: items);
    for (final (word, bundle) in heldPairs()) {
      if (word.isVocab) continue;
      expect(
        () => generator.build(word, bundle, ctx, Random(0)),
        throwsA(
          isA<CannotBuild>().having(
            (e) => e.reason,
            'reason',
            'the context holds no sentences',
          ),
        ),
      );
    }
  });

  test('the rating is Good for all pills right, Hard from half, Again below; '
      'never Easy', () {
    final fixed = [(2, 2), (1, 2), (3, 4), (1, 3), (0, 2), (1, 1), (0, 1)];
    final rng = Random(3220);
    final drawn = <(int, int)>[];
    for (var i = 0; i < 300; i++) {
      final all = 1 + rng.nextInt(8);
      drawn.add((rng.nextInt(all + 1), all));
    }
    for (final (right, all) in [...fixed, ...drawn]) {
      final rating = marksRating(right, all);
      expect(rating, _ratingOf(right, all), reason: '$right of $all');
      expect(rating, isNot(Rating.easy));
    }
    expect(marksRating(1, 2), Rating.hard);
    expect(marksRating(3, 4), Rating.hard);
    expect(marksRating(1, 3), Rating.again);
    expect(marksRating(2, 2), Rating.good);
  });

  test('a placement rates the grammar by its share of right pills and names '
      'each pill right or wrong in the feedback', () {
    final ctx = contextOf(everything);
    final rng = Random(3221);
    var checked = 0;
    for (final (word, bundle) in heldPairs()) {
      if (word.isVocab) continue;
      final Exercise e;
      try {
        e = generator.build(word, bundle, ctx, Random(checked));
      } on CannotBuild {
        continue;
      }
      final answer = e.answer as MarksAnswer;
      final n = answer.pills.length;
      final unmarked = [
        for (var w = 0; w < answer.words.length; w++)
          if (answer.pills.every((p) => p.word != w)) w,
      ];
      final placements = <List<int>>[
        rightMarks(answer).wordOf,
        for (var alone = 0; alone < n; alone++)
          [
            for (final (i, p) in answer.pills.indexed)
              i == alone ? unmarked.first : p.word,
          ],
        [for (final p in answer.pills.reversed) p.word],
        for (var k = 0; k < 4; k++)
          [
            for (final p in answer.pills)
              rng.nextBool() ? p.word : unmarked[rng.nextInt(unmarked.length)],
          ],
      ];
      for (final wordOf in placements) {
        final response = MarksResponse(wordOf);
        final right = [
          for (final (i, p) in answer.pills.indexed) wordOf[i] == p.word,
        ];
        expect(attribute(word, e, response), (
          word: Rating.good,
          grammar: _ratingOf(right.where((r) => r).length, n),
        ), reason: '$wordOf');
        final lines = feedbackLines(word, e, response);
        expect(
          [for (final l in lines) l.key],
          [
            for (final (i, p) in answer.pills.indexed)
              'exercise.tap.feedback.${p.role}.${right[i] ? 'right' : 'wrong'}',
          ],
        );
        for (final (i, p) in answer.pills.indexed) {
          expect(lines[i].params['word'], answer.words[p.word]);
          if (!right[i]) {
            expect(lines[i].params['chosen'], answer.words[wordOf[i]]);
          }
        }
      }
      checked++;
    }
    expect(checked, greaterThan(10));
  });
}
