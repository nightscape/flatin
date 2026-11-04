import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/round_plan.dart';
import 'package:latin_practice/data/selection.dart';
import 'package:latin_practice/data/word_focus.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/models/settings.dart' hide Override;
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/lesson_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/providers/reward_provider.dart';
import 'package:latin_practice/providers/round_providers.dart';
import 'package:latin_practice/screens/grammar_start_screen.dart';
import 'package:latin_practice/screens/round_end_screen.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/course_providers.dart';
import 'support/key_echo_app.dart';
import 'support/gen_card_store.dart';
import 'support/gen_settings.dart';
import 'support/word_classification_harness.dart';

/// Builds a task for every pair: which exercise fits a pair is the sweep's
/// property, not the offer's.
final class _AnyPair implements ExerciseGenerator {
  const _AnyPair();

  @override
  ExerciseKind get kind => ExerciseKind.latDeWahl;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    final option = FormOption(
      text: word.lemma,
      formKey: word.formOrder.first,
      lexemeId: word.id,
    );
    return Exercise(
      wordCardId: word.id,
      grammarCardId: GrammarCardId(word.dataFileId, bundle),
      kind: kind,
      questionKey: 'exercise.latDeWahl.question',
      questionParams: {'form': word.lemma},
      answer: ChoiceAnswer([option], option),
    );
  }
}

typedef _Pool = ({
  List<PracticeItem> words,
  Set<String> cards,
  CourseFilter filter,
});

typedef _State = ({
  _Pool pool,
  Settings settings,
  WordFocus focus,
  CardStore store,
});

late List<PracticeItem> _items;
late Curriculum _curriculum;
late LessonData _lessons;
late Map<String, PracticeItemCard> _fresh;
late Map<String, Set<String>> _typesOf, _formsOf;
late Map<String, Map<String, Set<String>>> _featuresOf;
late Set<String> _lemmas, _topicKeys;
late GermanForms _german;
late SentenceCorpus _corpus;

Future<void> _load() async {
  SharedPreferences.setMockInitialValues({});
  _items = await loadAllPracticeItems();
  _curriculum = await loadCurriculum(bookAssets);
  _lessons = await loadLessonData(bookAssets);
  await FsrsStorage.syncCards(_items);
  _fresh = await FsrsStorage.syncGrammarCards(_items);
  final grammar = [
    for (final f in ['nouns', 'verbs'])
      (f, _items.where((i) => i.dataFileId == f)),
  ];
  _typesOf = {
    for (final (f, words) in grammar) f: {for (final w in words) w.type},
  };
  _formsOf = {
    for (final (f, words) in grammar)
      f: {for (final w in words) ...w.formOrder},
  };
  _featuresOf = {for (final (f, _) in grammar) f: {}};
  for (final (f, words) in grammar) {
    for (final w in words) {
      for (final l in w.formLabels) {
        for (final MapEntry(:key, :value) in l.features.entries) {
          _featuresOf[f]!.putIfAbsent(key, () => {}).add(value);
        }
      }
    }
  }
  _lemmas = {for (final i in _items) i.lemma};
  _topicKeys = {for (final t in _curriculum.courseTopics) t.key};
  final container = ProviderContainer(
    overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
  );
  _german = await container.read(germanFormsProvider.future);
  _corpus = await container.read(sentenceCorpusProvider.future);
  container.dispose();
}

T _pick<T>(Random rng, List<T> xs) => xs[rng.nextInt(xs.length)];

_State _draw(Random rng, DateTime now, {required bool anyFocus}) {
  final settings = drawSettings(
    rng,
    firstOnly: 0.25,
    full: 0.25,
    types: _typesOf,
    forms: _formsOf,
    features: _featuresOf,
    off: _pick(rng, [0.0, 0.3, 1.0]),
    formsOff: _pick(rng, [0.0, 0.0, 0.3, 1.0]),
    featuresOff: _pick(rng, [0.0, 0.0, 0.0, 0.15]),
    forced: 0.1,
    words: _lemmas,
    wordsOff: _pick(rng, [0.0, 0.0, 0.3, 1.0]),
    topics: _topicKeys,
    topicsOff: _pick(rng, [0.0, 0.0, 0.0, 0.3]),
  );
  final store = drawCardStore(rng, _fresh, now);
  final WordFocus focus = anyFocus
      ? _pick(rng, const [
          AllWords(),
          FileFocus('nouns'),
          FileFocus('verbs'),
          FileFocus('vocab'),
        ])
      : const AllWords();
  return (
    pool: _pool(settings, focus),
    settings: settings,
    focus: focus,
    store: store,
  );
}

_State _static(Settings settings, CardStore store) => (
  pool: _pool(settings, const AllWords()),
  settings: settings,
  focus: const AllWords(),
  store: store,
);

/// Every card as synced: new and due.
CardStore _synced(DateTime now) =>
    drawCardStore(Random(0), _fresh, now, emptyChance: 1);

/// An empty course: words of lesson 1 only, every noun and verb type off,
/// nothing reviewed.
_State _emptyCourse(DateTime now) => _static(
  Settings(courseWords: LessonRange(1, 1), disabledTypes: _typesOf),
  _synced(now),
);

/// Nothing reviewed; rosa of lesson 1, forced on, comes first in the course,
/// and the grammar range holds none of its forms.
_State _forcedOnWordWithoutForm(DateTime now) => _static(
  Settings(
    courseWords: LessonRange(23, 32),
    courseGrammar: LessonRange(23, 39),
    grammarToLinked: false,
    forcedOnWords: {'rosa'},
  ),
  _synced(now),
);

/// unus is in the word range, the grammar range holds none of its forms, and
/// its card is the only reviewed one: due, with the lowest R.
_State _reviewedWordWithoutForm(DateTime now) {
  const id = 'nouns:unus';
  final store = _synced(now);
  final lastReview = now.subtract(const Duration(days: 2));
  store.cards[id] = PracticeItemCard(
    itemId: id,
    card: fsrs.Card(
      cardId: store.cards[id]!.card.cardId,
      state: fsrs.State.review,
      stability: 1,
      difficulty: 5,
      lastReview: lastReview,
    ),
    lastReview: lastReview,
    due: now.subtract(const Duration(hours: 1)),
  );
  store.r[id] = 0;
  return _static(
    Settings(
      courseWords: LessonRange(18, 34),
      courseGrammar: LessonRange(13, 31),
      grammarToLinked: false,
    ),
    (cards: store.cards, r: store.r, empty: false),
  );
}

/// The static states first, then [count] random draws.
List<(int, _State Function(DateTime))> _cases(
  int masterSeed,
  int count, {
  required bool anyFocus,
}) {
  final master = Random(masterSeed);
  final seeds = [for (var i = 0; i < count; i++) master.nextInt(1 << 30)];
  return [
    (0, _emptyCourse),
    (1, _forcedOnWordWithoutForm),
    (2, _reviewedWordWithoutForm),
    for (final seed in seeds)
      (seed, (now) => _draw(Random(seed), now, anyFocus: anyFocus)),
  ];
}

/// The pool: the words of the focus that [CourseFilter.reachesPractice]
/// lets through with a practised form, and their cards.
_Pool _pool(Settings settings, WordFocus focus) {
  final filter = CourseFilter(settings, _curriculum, _lessons);
  final words = [
    for (final w in _items)
      if (focus.includes(w) &&
          filter.reachesPractice(w) &&
          w.formLabels.any((l) => filter.formPracticed(w.dataFileId, l)))
        w,
  ];
  return (
    words: words,
    cards: {
      for (final w in words) ...[
        PracticeItemCard.generateItemId(w),
        for (final l in w.formLabels)
          if (filter.formPracticed(w.dataFileId, l)) GrammarCardId.of(w, l.key),
      ],
    },
    filter: filter,
  );
}

/// The classes of a drawn state, for the reach check.
Set<String> _classes(_State s, DateTime now) {
  final pool = s.pool;
  final st = s.settings;
  bool emptyWith(Settings changed) => _pool(changed, s.focus).words.isEmpty;
  final due = pool.cards.where((id) => !s.store.cards[id]!.due.isAfter(now));
  return {
    if (s.store.empty) 'empty store',
    if (pool.words.isEmpty) ...[
      if (!emptyWith(st.copyWith(disabledTypes: {}))) 'empty by types off',
      if (!emptyWith(
        st.copyWith(
          courseWords: LessonRange.full,
          courseGrammar: LessonRange.full,
        ),
      ))
        'empty by range',
      if (!emptyWith(st.copyWith(deselectedWords: {}))) 'empty by deselection',
    ] else ...[
      if (due.isEmpty) 'nothing due',
      if (due.isNotEmpty && due.length < pool.cards.length) 'some due',
      if (due.length == pool.cards.length) 'all due',
      if (pool.cards.any((id) => s.store.cards[id]!.lastReview == null))
        'new cards',
    ],
  };
}

String _describe(int seed, _State s, DateTime now) {
  final pool = s.pool;
  final due = pool.cards.where((id) => !s.store.cards[id]!.due.isAfter(now));
  final st = s.settings;
  return 'seed $seed: focus ${s.focus.id}, words ${st.courseWords}, '
      'grammar ${st.courseGrammar}, types off '
      '${st.disabledTypes.map((f, t) => MapEntry(f, t.length))}, on '
      '${st.forcedOnTypes.map((f, t) => MapEntry(f, t.length))}, forms off '
      '${st.disabledForms.map((f, t) => MapEntry(f, t.length))}, '
      'words off ${st.deselectedWords.length} on ${st.forcedOnWords.length}, '
      'topics off ${st.deselectedTopics.length}, features off '
      '${st.disabledFeatures.map((f, a) => MapEntry(f, a.length))}, '
      'empty store ${s.store.empty}; pool ${pool.words.length} words, '
      '${pool.cards.length} cards, ${due.length} due: ${_classes(s, now)}';
}

/// The drawn cards and R, and the course data loaded once.
List<Override> _overridesOf(_State s, int seed) => [
  curriculumProvider.overrideWith((ref) async => _curriculum),
  lessonDataProvider.overrideWith((ref) async => _lessons),
  germanFormsProvider.overrideWith((ref) async => _german),
  sentenceCorpusProvider.overrideWith((ref) async => _corpus),
  fsrsCardsProvider.overrideWith((ref) async => s.store.cards),
  fsrsSchedulerProvider.overrideWithValue(TableScheduler.of(s.store)),
  exerciseRandomProvider.overrideWithValue(Random(seed)),
  exerciseRegistryProvider.overrideWithValue(const [_AnyPair()]),
];

/// With nothing due, the pairs a mixed round must hold: from the cards of
/// lowest R (ties: earlier due, then id), each the anchor with its strongest
/// partner, every grammar card without a review taken from the start.
List<String> _expectedPairs(_State s) {
  final pool = s.pool;
  final index = BundleIndex(pool.words, pool.filter);
  double r(String id) => s.store.r[id]!;
  final taken = {
    for (final id in pool.cards)
      if (id.startsWith('grammar:') && s.store.cards[id]!.lastReview == null)
        id,
  };
  final order = pool.cards.where((id) => !taken.contains(id)).toList()
    ..sort((a, b) {
      if (r(a) != r(b)) return r(a).compareTo(r(b));
      final byDue = s.store.cards[a]!.due.compareTo(s.store.cards[b]!.due);
      return byDue != 0 ? byDue : a.compareTo(b);
    });
  String strongest(Iterable<String> ids) {
    final untaken = ids.where((id) => !taken.contains(id));
    return (untaken.isEmpty ? ids : untaken).reduce((a, b) {
      if (r(a) != r(b)) return r(a) > r(b) ? a : b;
      final byLesson = index.lessonOf[a]! - index.lessonOf[b]!;
      if (byLesson != 0) return byLesson < 0 ? a : b;
      return a.compareTo(b) <= 0 ? a : b;
    });
  }

  final pairs = <String>[];
  for (final anchor in order) {
    if (pairs.length == roundLength) break;
    if (taken.contains(anchor)) continue;
    final ofBundle = index.wordsOfBundle[anchor];
    if (ofBundle != null) {
      final word = strongest(ofBundle.words.map((w) => w.id));
      pairs.add('$word|${ofBundle.bundle}');
      taken.addAll([word, anchor]);
    } else {
      final word = index.bundlesOfWord.keys.singleWhere((w) => w.id == anchor);
      final bundleOf = {
        for (final b in index.bundlesOfWord[word]!)
          GrammarCardId(word.dataFileId, b) as String: b,
      };
      pairs.add('$anchor|${bundleOf[strongest(bundleOf.keys)]}');
      taken.add(anchor);
    }
  }
  return pairs..sort();
}

String _head(StackTrace st) => st.toString().split('\n').take(12).join('\n');

void _expectNone(List<String> failures) => expect(
  failures,
  isEmpty,
  reason:
      '${failures.length} failing cases; the first ones:\n'
      '${failures.take(3).join('\n\n')}',
);

void _expectReach(Map<String, int> counts, List<String> classes) {
  for (final name in classes) {
    expect(counts[name] ?? 0, greaterThan(0), reason: '$name: $counts');
  }
}

const _allClasses = [
  'empty by types off',
  'empty by range',
  'empty by deselection',
  'nothing due',
  'some due',
  'all due',
  'new cards',
  'empty store',
];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _load();
  });

  test('the offer is the due offer with a due card in the pool, '
      'NothingToPractise for an empty pool, else NothingDue; the round it '
      'starts has 1 to roundLength tasks, with nothing due the cards of '
      'lowest R', () async {
    final counts = <String, int>{};
    final failures = <String>[];
    for (final (seed, draw) in _cases(3523, 300, anyFocus: true)) {
      final now = DateTime.now().toUtc();
      final s = draw(now);
      for (final c in _classes(s, now)) {
        counts.update(c, (n) => n + 1, ifAbsent: () => 1);
      }
      final pool = s.pool;
      final anyDue = pool.cards.any(
        (id) => !s.store.cards[id]!.due.isAfter(now),
      );

      seedSettings(s.settings);
      final container = ProviderContainer(
        retry: noRetry,
        overrides: [
          dataLanguageProvider.overrideWith((ref) => 'de'),
          ..._overridesOf(s, seed),
        ],
      );
      try {
        final offer = await container
            .listen(todayOfferProvider(s.focus).future, (_, _) {})
            .read();
        expect(
          offer,
          pool.words.isEmpty
              ? isA<NothingToPractise>()
              : anyDue
              ? anyOf(isA<MixedOffer>(), isA<NewTopicOffer>())
              : isA<NothingDue>(),
        );
        final request = requestOf(offer, s.focus);
        if (request == null) continue;
        final round = container.listen(
          roundProvider(request).future,
          (_, _) {},
        );
        final state = await round.read();
        expect(state.total, inInclusiveRange(1, roundLength));
        if (offer is NothingDue) {
          expect(
            [for (final t in state.queue) '${t.word.id}|${t.bundle}']..sort(),
            _expectedPairs(s),
          );
        }
      } catch (e, st) {
        failures.add('${_describe(seed, s, now)}\n$e\n${_head(st)}');
      } finally {
        container.dispose();
      }
    }
    _expectNone(failures);
    _expectReach(counts, _allClasses);
  });

  testWidgets('the start button and the round-end "again" button show '
      'exactly when a tap starts a round with a task; the start page says '
      'nothing is due exactly when no card of the pool is due', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final counts = <String, int>{};
    final failures = <String>[];

    Future<void> expectButton(String key, bool canStart) async {
      final button = find.byKey(Key(key));
      expect(button.evaluate().isNotEmpty, canStart, reason: key);
      if (!canStart) return;
      await tester.tap(button);
      await letItLoad(tester);
      expect(
        find.textContaining('round.task{n=1,'),
        findsOneWidget,
        reason:
            'on screen: '
            '${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data)}',
      );
    }

    for (final (seed, draw) in _cases(3524, 100, anyFocus: false)) {
      final now = DateTime.now().toUtc();
      final s = draw(now);
      for (final c in _classes(s, now)) {
        counts.update(c, (n) => n + 1, ifAbsent: () => 1);
      }
      final canStart = s.pool.words.isNotEmpty;

      Future<void> pump(Widget home) async {
        seedSettings(s.settings);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          wrapInKeyEchoAppWith(home, overrides: _overridesOf(s, seed)),
        );
        await letItLoad(tester);
      }

      try {
        await pump(const GrammarStartScreen());
        expect(
          find.text('round.start.nothingDue'),
          s.pool.cards.any((id) => !s.store.cards[id]!.due.isAfter(now))
              ? findsNothing
              : findsOneWidget,
        );
        await expectButton('round.start.go', canStart);

        await pump(
          Consumer(
            builder: (_, ref, _) =>
                ref.watch(rewardsProvider).hasValue &&
                    ref.watch(todayOfferProvider(const AllWords())).hasValue
                ? const RoundEndScreen(start: RewardLedger(), focus: AllWords())
                : const SizedBox(),
          ),
        );
        expect(find.byType(RoundEndScreen), findsOneWidget);
        await expectButton('round.end.again', canStart);
      } catch (e, st) {
        failures.add('${_describe(seed, s, now)}\n$e\n${_head(st)}');
      }
    }
    _expectNone(failures);
    _expectReach(counts, _allClasses);
  });
}
