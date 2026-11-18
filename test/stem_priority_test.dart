import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' show Card;
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/selection.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/round_providers.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/gen_card_store.dart';
import 'support/latin_course.dart';

/// A drawn card store plus stem cards of drawn items, due before or after
/// [now].
(CardStore, Map<String, PracticeItemCard>) _drawStore(
  Random rng,
  List<PracticeItem> items,
  Map<String, PracticeItemCard> fresh,
  DateTime now,
) {
  final store = drawCardStore(rng, fresh, now);
  final share = [0.0, 0.05, 0.5][rng.nextInt(3)];
  final stems = <String, PracticeItemCard>{
    for (final item in items)
      for (final stem in item.derivation.stems.keys)
        if (rng.nextDouble() < share)
          StemCardId(item, stem): PracticeItemCard(
            itemId: StemCardId(item, stem),
            card: Card(cardId: StemCardId(item, stem).hashCode),
            due: rng.nextBool()
                ? now.subtract(dueOffsets[rng.nextInt(dueOffsets.length)])
                : now.add(dueOffsets[rng.nextInt(dueOffsets.length)]),
          ),
  };
  return (store, stems);
}

/// The stem card ids whose stem a practised form of [items] shows split,
/// read from the generated forms.
Set<String> _shownStems(List<PracticeItem> items, CourseFilter filter) => {
  for (final item in items)
    for (final key in filter.practicedForms(item.dataFileId, item.formLabels))
      if (item.derivation.forms[key] case GeneratedForm(
        sandhiRule: null,
        :final ending,
        :final stemName,
      ) when ending.isNotEmpty)
        StemCardId(item, stemName),
};

String _pairOf(SelectedPair? p) => p == null
    ? 'none'
    : '${p.word.id} ${p.bundle} ${p.anchorIsGrammar} ${p.anchorIsNew}';

void main() {
  late List<PracticeItem> items;
  late Map<String, PracticeItemCard> fresh;
  late CourseFilter filter;
  late List<(CourseFilter, BundleIndex, Set<String>)> courses;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    items = await loadAllPracticeItems();
    await FsrsStorage.syncCards(items);
    fresh = await FsrsStorage.syncGrammarCards(items);
    final curriculum = await loadCurriculum(latinCourse.books);
    final lessons = await loadLessonData(latinCourse.books);
    filter = CourseFilter(
      Settings(lastLesson: latinLastLesson),
      curriculum,
      lessons,
    );
    courses = [
      for (final f in [
        filter,
        for (final end in drawCourseEnds(Random(4184), 3))
          CourseFilter(
            Settings(
              lastLesson: latinLastLesson,
              courseWords: LessonRange(1, end),
            ),
            curriculum,
            lessons,
          ),
      ])
        (f, BundleIndex(items, f), _shownStems(items, f)),
    ];
  });

  test('only in selbst markieren does a due stem card move its own word '
      'card, and only its due, to the earlier date, when a practised form '
      'shows the stem split and the word was last reviewed before', () {
    final rng = Random(4180);
    var raised = 0;
    var notShown = 0;
    var reviewedSince = 0;
    for (var i = 0; i < 60; i++) {
      final now = DateTime.now().toUtc();
      final (filter, _, shown) = courses[rng.nextInt(courses.length)];
      final (store, stems) = _drawStore(rng, items, fresh, now);
      final cards = {...store.cards, ...stems};
      for (final mode in StemMarking.values) {
        final got = withStemPriority(cards, items, filter, mode, now);
        if (mode != StemMarking.selbstMarkieren) {
          expect(identical(got, cards), isTrue, reason: '$mode');
          continue;
        }
        final earliest = <String, DateTime>{};
        for (final MapEntry(key: id, value: s) in stems.entries) {
          if (s.due.isAfter(now)) continue;
          if (!shown.contains(id)) {
            notShown++;
            continue;
          }
          final lastReview = cards[StemCardId.wordCardOf(id)]!.lastReview;
          if (lastReview != null && !lastReview.isBefore(s.due)) {
            reviewedSince++;
            continue;
          }
          earliest.update(
            StemCardId.wordCardOf(id),
            (d) => s.due.isBefore(d) ? s.due : d,
            ifAbsent: () => s.due,
          );
        }
        expect(got.keys, cards.keys);
        for (final MapEntry(key: id, value: before) in cards.entries) {
          final stem = earliest[id];
          final due = stem != null && stem.isBefore(before.due)
              ? stem
              : before.due;
          if (due != before.due) raised++;
          expect(
            got[id]!.toMap(),
            before.copyWith(due: due).toMap(),
            reason: id,
          );
        }
      }
    }
    expect(raised, greaterThan(0));
    expect(notShown, greaterThan(0));
    expect(reviewedSince, greaterThan(0));
  });

  test('in every stem marking, the stem cards in the store change the '
      'selected pair only through the due dates they raise', () {
    final rng = Random(4181);
    for (var i = 0; i < 60; i++) {
      final now = DateTime.now().toUtc();
      final (filter, index, _) = courses[rng.nextInt(courses.length)];
      final (store, stems) = _drawStore(rng, items, fresh, now);
      double r(PracticeItemCard c) => store.r[c.itemId]!;
      for (final mode in StemMarking.values) {
        for (final includeNotDue in [false, true]) {
          final raised = withStemPriority(
            {...store.cards, ...stems},
            items,
            filter,
            mode,
            now,
          );
          SelectedPair? select(Map<String, PracticeItemCard> cards) =>
              selectPair(
                cards: cards,
                items: items,
                filter: filter,
                retrievability: r,
                now: now,
                includeNotDue: includeNotDue,
                index: index,
              );
          expect(
            _pairOf(select(raised)),
            _pairOf(
              select({
                for (final e in raised.entries)
                  if (!StemCardId.isStemCard(e.key)) e.key: e.value,
              }),
            ),
            reason: '$mode $includeNotDue',
          );
          if (mode != StemMarking.selbstMarkieren) {
            expect(
              _pairOf(select(raised)),
              _pairOf(select(store.cards)),
              reason: '$mode $includeNotDue',
            );
          }
        }
      }
    }
  });

  test('in selbst markieren with no confirmed mark, a word is selected '
      'raised to a stem due date at most once', () {
    final rng = Random(4182);
    const steps = [Duration(minutes: 1), Duration(hours: 1), Duration(days: 1)];
    var served = 0;
    for (var i = 0; i < 24; i++) {
      var now = DateTime.now().toUtc();
      final (filter, index, _) = courses[rng.nextInt(courses.length)];
      final (store, stems) = _drawStore(rng, items, fresh, now);
      final cards = {...store.cards, ...stems};
      final raisesServed = <(String, DateTime)>{};
      for (var step = 0; step < 12; step++) {
        now = now.add(steps[rng.nextInt(steps.length)]);
        final raised = withStemPriority(
          cards,
          items,
          filter,
          StemMarking.selbstMarkieren,
          now,
        );
        final pair = selectPair(
          cards: raised,
          items: items,
          filter: filter,
          retrievability: (c) => store.r[c.itemId]!,
          now: now,
          includeNotDue: false,
          index: index,
        );
        if (pair == null) break;
        final id = pair.word.id;
        final due = raised[id]!.due;
        if (due != cards[id]!.due) {
          served++;
          expect(raisesServed.add((id, due)), isTrue, reason: '$id $due');
        }
        cards[id] = cards[id]!.copyWith(
          lastReview: now,
          due: now.add(dueOffsets[rng.nextInt(dueOffsets.length)]),
        );
      }
    }
    expect(served, greaterThan(0));
  });

  test(
    'in selbst markieren a due stem card that no practised form shows '
    'split leaves its word card as it is, at every drawn course range',
    () async {
      final rng = Random(4183);
      final curriculum = await loadCurriculum(latinCourse.books);
      final lessons = await loadLessonData(latinCourse.books);
      final everyShown = _shownStems(items, filter);
      var shownOnlyUnpractised = 0;
      final moved = <String>[];
      for (final lesson in drawCourseEnds(rng, 8)) {
        final narrow = CourseFilter(
          Settings(
            lastLesson: latinLastLesson,
            courseWords: LessonRange(1, lesson),
          ),
          curriculum,
          lessons,
        );
        final practised = _shownStems(items, narrow);
        final now = DateTime.now().toUtc();
        final (store, stems) = _drawStore(rng, items, fresh, now);
        final cards = {...store.cards, ...stems};
        final got = withStemPriority(
          cards,
          items,
          narrow,
          StemMarking.selbstMarkieren,
          now,
        );
        final byWord = <String, List<String>>{};
        for (final MapEntry(key: id, value: s) in stems.entries) {
          if (!s.due.isAfter(now)) {
            byWord.putIfAbsent(StemCardId.wordCardOf(id), () => []).add(id);
          }
        }
        for (final MapEntry(key: word, value: due) in byWord.entries) {
          if (due.any(practised.contains)) continue;
          if (due.any(everyShown.contains)) {
            shownOnlyUnpractised++;
          }
          if (got[word]!.due != cards[word]!.due) moved.add('$lesson $word');
        }
      }
      expect(shownOnlyUnpractised, greaterThan(0));
      expect(moved, isEmpty);
    },
  );
}

/// Drawn ends of the course's word range, which the grammar range follows,
/// so that some forms are not practised.
List<int> drawCourseEnds(Random rng, int n) => [
  for (var i = 0; i < n; i++) 1 + rng.nextInt(latinLastLesson),
];
