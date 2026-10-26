import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/selection.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.utc(2026, 10, 20);

late List<PracticeItem> _items;
late Curriculum _curriculum;
late LessonData _lessons;

CourseFilter _filter(int upToLesson) => CourseFilter(
  Settings(courseWords: LessonRange(1, upToLesson)),
  _curriculum,
  _lessons,
);

/// Every card, reviewed unless [reviewed] is false, due one day after [_now]
/// unless listed in [due].
Map<String, PracticeItemCard> _cards(
  Map<String, PracticeItemCard> all,
  Set<String> due, {
  Map<String, DateTime> dueAt = const {},
  bool reviewed = true,
}) => {
  for (final card in all.values)
    card.itemId: card.copyWith(
      lastReview: reviewed ? _now.subtract(const Duration(days: 2)) : null,
      due:
          dueAt[card.itemId] ??
          (due.contains(card.itemId)
              ? _now
              : _now.add(const Duration(days: 1))),
    ),
};

SelectedPair? _select(
  Map<String, PracticeItemCard> cards,
  CourseFilter filter,
  Map<String, double> r,
) => selectPair(
  cards: cards,
  items: _items,
  filter: filter,
  retrievability: (card) => r[card.itemId] ?? 0.5,
  now: _now,
);

String _wordId(PracticeItem word) => PracticeItemCard.generateItemId(word);

void main() {
  late Map<String, PracticeItemCard> all;
  late CourseFilter filter;
  late PracticeItem amare;
  late PracticeItem vocare;
  late List<GrammarBundle> amareBundles;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    _items = await loadAllPracticeItems();
    _curriculum = await loadCurriculum(curriculumAssets);
    _lessons = await loadLessonData(lessonDataAssets);
    await FsrsStorage.syncCards(_items);
    all = await FsrsStorage.syncGrammarCards(_items);
    filter = _filter(laterLesson);
    final verbs = _items.where((i) => i.dataFileId == 'verbs');
    amare = verbs.firstWhere((i) => i.id == 'verbs:laudare');
    vocare = verbs.firstWhere((i) => i.id == 'verbs:vocare');
    amareBundles = {
      for (final key in amare.formOrder) bundleOf(amare, key),
    }.toList()..sort();
  });

  GrammarCardId grammar(PracticeItem w, GrammarBundle b) =>
      GrammarCardId(w.dataFileId, b);

  test('a due grammar card with the lowest R is the anchor and a confident '
      'word of its bundle the partner', () {
    final bundle = bundleOf(amare, 'ind.praes.akt.3.sg');
    final g = grammar(amare, bundle);
    final sameBundle = _items.where(
      (w) =>
          filter.reachesPractice(w) &&
          w.formOrder.any((k) => grammar(w, bundleOf(w, k)) == g),
    );
    expect(sameBundle.length, greaterThan(2));
    final strongest = sameBundle.last;
    final r = {
      g: 0.1,
      _wordId(amare): 0.3,
      for (final w in sameBundle) _wordId(w): 0.4,
      _wordId(strongest): 0.9,
    };
    final pair = _select(_cards(all, {g, _wordId(amare)}), filter, r)!;

    expect(pair.anchorIsGrammar, isTrue);
    expect(pair.grammarCardId, g);
    expect(pair.word, strongest);
  });

  test('a due word with the lowest R is the anchor and its most confident '
      'bundle the partner', () {
    final w = _wordId(amare);
    final strongestBundle = amareBundles[3];
    final r = {
      w: 0.1,
      for (final b in amareBundles) grammar(amare, b): 0.5,
      grammar(amare, strongestBundle): 0.95,
    };
    final pair = _select(
      _cards(all, {w, grammar(amare, amareBundles[0])}),
      filter,
      r,
    )!;

    expect(pair.anchorIsGrammar, isFalse);
    expect(pair.word, amare);
    expect(pair.bundle, strongestBundle);
  });

  test('only due cards can be the anchor, however low their R', () {
    final due = grammar(amare, amareBundles[1]);
    final r = {
      _wordId(vocare): 0.0,
      for (final b in amareBundles) grammar(amare, b): 0.0,
      due: 0.2,
    };
    final pair = _select(_cards(all, {due}), filter, r)!;

    expect(pair.grammarCardId, due);
  });

  test('equal R: the earlier due date anchors, then the smaller id', () {
    final a = _wordId(amare), v = _wordId(vocare);
    final r = {a: 0.3, v: 0.3};
    final early = _now.subtract(const Duration(hours: 1));

    expect(
      _select(_cards(all, {a, v}, dueAt: {v: early}), filter, r)!.word,
      vocare,
    );
    final byId = _select(_cards(all, {a, v}), filter, r)!.word;
    expect(_wordId(byId), a.compareTo(v) < 0 ? a : v);
  });

  test('equal R among partners: the earlier lesson, then the smaller id', () {
    final bundle = bundleOf(amare, 'ind.praes.akt.3.sg');
    final g = grammar(amare, bundle);
    final r = {g: 0.1};
    final pair = _select(_cards(all, {g}), filter, r)!;
    final candidates = _items.where(
      (w) =>
          filter.reachesPractice(w) &&
          w.formOrder.any((k) => grammar(w, bundleOf(w, k)) == g),
    );

    final firstLesson = candidates
        .map(_lessons.lessonNumberOf)
        .reduce((a, b) => a < b ? a : b);
    final first = candidates.where(
      (w) => _lessons.lessonNumberOf(w) == firstLesson,
    );
    expect(
      _wordId(pair.word),
      first.map(_wordId).reduce((a, b) => a.compareTo(b) < 0 ? a : b),
    );
  });

  test('nothing due gives no pair', () {
    expect(_select(_cards(all, {}), filter, {}), isNull);
  });

  test('no word in the course gives no pair', () {
    final none = selectPair(
      cards: _cards(all, all.keys.toSet()),
      items: const [],
      filter: filter,
      retrievability: (_) => 0.5,
      now: _now,
    );

    expect(none, isNull);
  });

  test('a card without a stored card is a programming error', () {
    expect(
      () => selectPair(
        cards: const {},
        items: [amare],
        filter: filter,
        retrievability: (_) => 0.5,
        now: _now,
      ),
      throwsStateError,
    );
  });

  test('a reviewed due word is the anchor before new grammar cards', () {
    final g = grammar(amare, 'ind.praes.akt');
    final cards = _cards(all, {_wordId(amare), g}, reviewed: false);
    cards[_wordId(amare)] = cards[_wordId(amare)]!.copyWith(
      lastReview: _now.subtract(const Duration(days: 2)),
    );
    final pair = _select(cards, filter, {_wordId(amare): 0.9})!;

    expect(pair.anchorIsGrammar, isFalse);
    expect(pair.word, amare);
  });

  test('with only new cards due, the earliest lesson is the anchor', () {
    final cards = _cards(all, all.keys.toSet(), reviewed: false);
    final pair = _select(cards, filter, {})!;
    final earliest = _items
        .where(filter.reachesPractice)
        .map(_lessons.lessonNumberOf)
        .reduce((a, b) => a < b ? a : b);

    expect(_lessons.lessonNumberOf(pair.word), earliest);
  });

  test('new cards alternate between nouns and verbs on equal lessons, and '
      'follow course order with Good answers', () {
    final scheduler = fsrs.Scheduler();
    var cards = _cards(all, all.keys.toSet(), reviewed: false);
    final picked = <SelectedPair>[];
    for (var i = 0; i < 20; i++) {
      final pair = _select(cards, filter, {})!;
      picked.add(pair);
      for (final id in [_wordId(pair.word), pair.grammarCardId as String]) {
        final (:card, :reviewLog) = scheduler.reviewCard(
          cards[id]!.card,
          fsrs.Rating.good,
          reviewDateTime: _now,
        );
        cards = {
          ...cards,
          id: cards[id]!.copyWith(
            card: card,
            lastReview: _now,
            due: _now.add(const Duration(days: 1)),
          ),
        };
      }
    }
    final lessons = [for (final p in picked) _lessons.lessonNumberOf(p.word)];

    expect(picked.any((p) => p.word.dataFileId == 'verbs'), isTrue);
    expect(picked.any((p) => p.word.dataFileId == 'nouns'), isTrue);
    expect(lessons, [...lessons]..sort());
  });

  test(
    'the first two new anchors of equal lesson come from different files',
    () {
      final scheduler = fsrs.Scheduler();
      var cards = _cards(all, all.keys.toSet(), reviewed: false);
      final files = <String>[];
      for (var i = 0; i < 2; i++) {
        final pair = _select(cards, filter, {})!;
        files.add(pair.word.dataFileId);
        for (final id in [_wordId(pair.word), pair.grammarCardId as String]) {
          final (:card, :reviewLog) = scheduler.reviewCard(
            cards[id]!.card,
            fsrs.Rating.good,
            reviewDateTime: _now,
          );
          cards = {
            ...cards,
            id: cards[id]!.copyWith(
              card: card,
              lastReview: _now,
              due: _now.add(const Duration(days: 1)),
            ),
          };
        }
      }
      expect(files.toSet(), hasLength(2));
    },
  );

  test(
    'every noun word card reviewed does not skew the alternation of new grammar '
    'cards',
    () {
      final scheduler = fsrs.Scheduler();
      var cards = _cards(all, all.keys.toSet(), reviewed: false);
      final nounWords = _items.where((w) => w.dataFileId == 'nouns');
      for (final w in nounWords) {
        final id = _wordId(w);
        cards[id] = cards[id]!.copyWith(
          lastReview: _now.subtract(const Duration(days: 2)),
          due: _now.add(const Duration(days: 1)),
        );
      }
      final files = <String>[];
      for (var i = 0; i < 4; i++) {
        final pair = _select(cards, filter, {})!;
        files.add(pair.word.dataFileId);
        final id = pair.grammarCardId as String;
        final (:card, :reviewLog) = scheduler.reviewCard(
          cards[id]!.card,
          fsrs.Rating.good,
          reviewDateTime: _now,
        );
        cards = {
          ...cards,
          id: cards[id]!.copyWith(
            card: card,
            lastReview: _now,
            due: _now.add(const Duration(days: 1)),
          ),
        };
      }

      expect(files.toSet(), hasLength(2));
    },
  );

  test('a bundle the course has not taught is neither anchor nor partner', () {
    final narrow = _filter(3);
    final taught = {
      for (final w in _items.where(narrow.reachesPractice))
        for (final label in w.formLabels)
          if (narrow.formPracticed(w.dataFileId, label))
            grammar(w, bundleOf(w, label.key)),
    };
    final locked = grammar(amare, 'konj.impf.akt');
    expect(taught, isNot(contains(locked)));
    expect(taught, isNotEmpty);
    final r = {locked: 0.0, for (final g in taught) g: 0.6};

    final asAnchor = _select(_cards(all, {locked, ...taught}), narrow, r)!;
    expect(asAnchor.grammarCardId, isNot(locked));
    expect(taught, contains(asAnchor.grammarCardId));

    final word = _items.firstWhere(
      (w) => w.dataFileId == 'verbs' && narrow.reachesPractice(w),
    );
    final lockedForWord = {
      for (final k in word.formOrder) grammar(word, bundleOf(word, k)),
    }.difference(taught);
    final asPartner = _select(_cards(all, {_wordId(word)}), narrow, {
      for (final g in lockedForWord) g: 1.0,
      for (final g in taught) g: 0.2,
    })!;
    expect(lockedForWord, isNotEmpty);
    expect(taught, contains(asPartner.grammarCardId));
  });

  test('a word outside the course is neither anchor nor partner', () {
    final narrow = _filter(3);
    final outside = _items.firstWhere(
      (w) => w.dataFileId == 'verbs' && !narrow.reachesPractice(w),
    );
    final g = grammar(amare, 'ind.praes.akt');
    final r = {_wordId(outside): 0.0, g: 0.1};
    final pair = _select(_cards(all, {_wordId(outside), g}), narrow, r)!;

    expect(pair.anchorIsGrammar, isTrue);
    expect(pair.word, isNot(outside));
  });

  group('taken', () {
    SelectedPair? selectTaken(
      Map<String, PracticeItemCard> cards,
      Map<String, double> r,
      Set<String> taken,
    ) => selectPair(
      cards: cards,
      items: _items,
      filter: filter,
      retrievability: (card) => r[card.itemId] ?? 0.5,
      now: _now,
      taken: taken,
    );

    test('a taken card is never the anchor', () {
      final g = grammar(amare, bundleOf(amare, 'ind.praes.akt.3.sg'));
      final w = _wordId(amare);
      final cards = _cards(all, {g, w});
      final r = {g: 0.1, w: 0.3};

      expect(selectTaken(cards, r, {})!.grammarCardId, g);
      final pair = selectTaken(cards, r, {g})!;
      expect(pair.anchorIsGrammar, isFalse);
      expect(pair.word, amare);
      expect(selectTaken(cards, r, {g, w}), isNull);
    });

    test('a taken card is a partner only when no untaken card fits', () {
      final bundle = bundleOf(amare, 'ind.praes.akt.3.sg');
      final g = grammar(amare, bundle);
      final words = _items
          .where(
            (w) =>
                filter.reachesPractice(w) &&
                w.formOrder.any((k) => grammar(w, bundleOf(w, k)) == g),
          )
          .toList();
      final strongest = words.last;
      final r = {
        g: 0.1,
        for (final w in words) _wordId(w): 0.4,
        _wordId(strongest): 0.9,
      };
      final cards = _cards(all, {g});

      expect(selectTaken(cards, r, {})!.word, strongest);
      final others = selectTaken(cards, r, {_wordId(strongest)})!.word;
      expect(others, isNot(strongest));
      expect(
        selectTaken(cards, r, {for (final w in words) _wordId(w)})!.word,
        strongest,
      );
    });
  });

  test('anchorIsNew says whether the anchor card was never reviewed', () {
    final g = grammar(amare, 'ind.praes.akt');
    expect(_select(_cards(all, {g}), filter, {})!.anchorIsNew, isFalse);
    expect(
      _select(_cards(all, {g}, reviewed: false), filter, {})!.anchorIsNew,
      isTrue,
    );
  });
}
