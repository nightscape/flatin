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

import 'support/exercise_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SentenceCorpus corpus;
  late List<PracticeItem> items;
  late Set<GrammarBundle> everyBundle;

  setUpAll(() async {
    corpus = await loadSentenceCorpus();
    items = await loadAllPracticeItems();
    everyBundle = {
      for (final w in items)
        for (final k in w.formOrder) bundleOf(w, k),
    };
  });

  PracticeItem itemOf(FormToken t) =>
      items.singleWhere((w) => w.lemma == t.lemma);

  Set<GrammarBundle> bundlesOf(Sentence s) => {
    for (final t in s.tokens.whereType<FormToken>()) bundleOf(itemOf(t), t.key),
  };

  ExerciseContext context({
    int reached = laterLesson,
    Set<GrammarBundle>? unlocked,
    List<PracticeItem>? pool,
  }) => ExerciseContext(
    unlocked: unlocked ?? everyBundle,
    pool: pool ?? items,
    german: fakeExerciseContext().german,
    sentences: corpus,
    reachedLesson: reached,
  );

  List<String> selected(
    ExerciseContext ctx, [
    OneSentence select = const OneSentence(),
  ]) => [for (final s in sentenceSlices(select, Cube(ctx))) s.sentence!.id];

  Matcher declines(String reason) =>
      throwsA(isA<CannotBuild>().having((e) => e.reason, 'reason', reason));

  test('a sentence above the reached lesson is not selected, one at it is', () {
    final at25 = corpus.sentences.firstWhere((s) => s.lesson == 25);
    final at24 = corpus.sentences.firstWhere((s) => s.lesson == 24);
    expect(selected(context(reached: 24)), contains(at24.id));
    expect(selected(context(reached: 24)), isNot(contains(at25.id)));
    expect(selected(context(reached: 25)), contains(at25.id));
  });

  test('a sentence with one locked bundle is not selected', () {
    final s = corpus.sentences.first;
    for (final locked in bundlesOf(s)) {
      expect(
        selected(context(unlocked: everyBundle.difference({locked}))),
        isNot(contains(s.id)),
        reason: locked,
      );
    }
    expect(selected(context(unlocked: bundlesOf(s))), contains(s.id));
  });

  test('a sentence with a word outside the pool is not selected', () {
    final s = corpus.sentences.first;
    final missing = itemOf(s.tokens.whereType<FormToken>().first);
    expect(
      selected(context(pool: [...items]..remove(missing))),
      isNot(contains(s.id)),
    );
  });

  test(
    'only the listed construction kinds are selected; none listed is all',
    () {
      String kindOf(String id) => corpus.sentences
          .singleWhere((s) => s.id == id)
          .construction
          .kind
          .name;
      final listed = {'pcPpp', 'frageNum'};
      expect(
        selected(
          context(),
          OneSentence(constructions: listed),
        ).map(kindOf).toSet(),
        listed,
      );
      expect(selected(context()).map(kindOf).toSet(), {
        for (final k in ConstructionKind.values) k.name,
      });
    },
  );

  test('every candidate is selected, in corpus order', () {
    final ids = selected(context());
    expect(ids, [for (final s in corpus.sentences) s.id]);
    expect(ids.length, greaterThan(1));
  });

  test('a construction name that names no kind is refused', () {
    expect(
      () => selected(context(), const OneSentence(constructions: {'pcPP'})),
      throwsA(isA<AssertionError>()),
    );
  });

  group('the build declines with the filter that left no sentence', () {
    test('lesson', () {
      final first = corpus.sentences.map((s) => s.lesson).reduce(min);
      expect(
        () => selected(context(reached: first - 1)),
        declines('no sentence up to lesson ${first - 1}'),
      );
    });

    test('construction', () {
      final first = corpus.sentences.map((s) => s.lesson).reduce(min);
      final later = {
        for (final k in ConstructionKind.values)
          if (corpus.sentences
              .where((s) => s.construction.kind == k)
              .every((s) => s.lesson > first))
            k.name,
      };
      expect(later, isNotEmpty);
      expect(
        () => selected(
          context(reached: first),
          OneSentence(constructions: later),
        ),
        declines('no sentence of $later up to lesson $first'),
      );
    });

    test('pool', () {
      expect(
        () => selected(context(pool: [])),
        declines(
          'no sentence up to lesson $laterLesson has its forms in the pool',
        ),
      );
    });

    test('bundles', () {
      expect(
        () => selected(context(unlocked: {})),
        declines(
          'every sentence up to lesson $laterLesson has a locked bundle',
        ),
      );
    });

    test('through the build of a spec', () {
      final word = items.firstWhere((w) => w.dataFileId == 'verbs');
      final bundle = bundleOf(word, word.formOrder.first);
      expect(
        () => SpecGenerator(
          KindSpec(
            kind: ExerciseKind.bestimmen,
            questionKey: 'q',
            select: const OneSentence(),
            params: const {},
            answer: const Typed(View.latin),
          ),
        ).build(word, bundle, context(reached: 0), Random(0)),
        declines('no sentence up to lesson 0'),
      );
    });
  });

  test('the selection equals the filters applied one by one', () {
    final names = [for (final k in ConstructionKind.values) k.name];
    final corpusItems = {
      for (final s in corpus.sentences)
        for (final t in s.tokens.whereType<FormToken>()) itemOf(t),
    };
    final corpusBundles = {for (final s in corpus.sentences) ...bundlesOf(s)};
    final rng = Random(349);
    final outcomes = <String, int>{};
    for (var run = 0; run < 400; run++) {
      final reached = rng.nextInt(laterLesson + 2);
      final dropBundles = rng.nextInt(4);
      final thin = rng.nextInt(3) == 0;
      final unlocked = {
        ...everyBundle.where((_) => !thin || rng.nextInt(10) > 0),
      }..removeAll((corpusBundles.toList()..shuffle(rng)).take(dropBundles));
      final dropItems = rng.nextInt(3);
      final dropped = (corpusItems.toList()..shuffle(rng))
          .take(dropItems)
          .toSet();
      final pool = [
        for (final w in items)
          if (!dropped.contains(w)) w,
      ];
      final constructions = rng.nextBool()
          ? null
          : {
              for (final n in names)
                if (rng.nextInt(3) == 0) n,
            };

      bool placed(FormToken t) {
        final w = pool.where((w) => w.lemma == t.lemma).firstOrNull;
        return w != null &&
            w.formOrder.contains(t.key) &&
            unlocked.contains(bundleOf(w, t.key));
      }

      final expected = [
        for (final s in corpus.sentences)
          if (s.lesson <= reached &&
              (constructions?.contains(s.construction.kind.name) ?? true) &&
              s.tokens.whereType<FormToken>().every(placed))
            s.id,
      ];
      final ctx = context(reached: reached, unlocked: unlocked, pool: pool);
      final select = OneSentence(constructions: constructions);
      final why =
          'reached $reached, kinds $constructions, '
          'dropped ${dropped.map((w) => w.id)}';
      if (expected.isEmpty) {
        expect(
          () => selected(ctx, select),
          throwsA(isA<CannotBuild>()),
          reason: why,
        );
        outcomes.update('none', (n) => n + 1, ifAbsent: () => 1);
      } else {
        expect(selected(ctx, select), expected, reason: why);
        final share = expected.length == corpus.sentences.length
            ? 'all'
            : 'some';
        outcomes.update(share, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    expect(outcomes.keys.toSet(), {'none', 'some', 'all'}, reason: '$outcomes');
  });
}
