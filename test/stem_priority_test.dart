import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' show Card;
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/selection.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/fsrs_card.dart';
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

String _pairOf(SelectedPair? p) => p == null
    ? 'none'
    : '${p.word.id} ${p.bundle} ${p.anchorIsGrammar} ${p.anchorIsNew}';

void main() {
  late List<PracticeItem> items;
  late Map<String, PracticeItemCard> fresh;
  late CourseFilter filter;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    items = await loadAllPracticeItems();
    await FsrsStorage.syncCards(items);
    fresh = await FsrsStorage.syncGrammarCards(items);
    filter = CourseFilter(
      Settings(lastLesson: latinLastLesson),
      await loadCurriculum(latinCourse.books),
      await loadLessonData(latinCourse.books),
    );
  });

  test('only in selbst markieren does a due stem card move its own word '
      'card, and only its due, to the earlier date', () {
    final rng = Random(4180);
    var raised = 0;
    for (var i = 0; i < 60; i++) {
      final now = DateTime.now().toUtc();
      final (store, stems) = _drawStore(rng, items, fresh, now);
      final cards = {...store.cards, ...stems};
      for (final mode in StemMarking.values) {
        final got = withStemPriority(cards, mode, now);
        if (mode != StemMarking.selbstMarkieren) {
          expect(identical(got, cards), isTrue, reason: '$mode');
          continue;
        }
        final earliest = <String, DateTime>{};
        for (final MapEntry(key: id, value: s) in stems.entries) {
          if (s.due.isAfter(now)) continue;
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
  });

  test('in every stem marking, the stem cards in the store change the '
      'selected pair only through the due dates they raise', () {
    final rng = Random(4181);
    final index = BundleIndex(items, filter);
    for (var i = 0; i < 60; i++) {
      final now = DateTime.now().toUtc();
      final (store, stems) = _drawStore(rng, items, fresh, now);
      double r(PracticeItemCard c) => store.r[c.itemId]!;
      for (final mode in StemMarking.values) {
        for (final includeNotDue in [false, true]) {
          final raised = withStemPriority(
            {...store.cards, ...stems},
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
}
