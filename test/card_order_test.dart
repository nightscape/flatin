import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/round_plan.dart';
import 'package:latin_practice/data/selection.dart';
import 'package:latin_practice/data/topics.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.utc(2026, 10, 20);

String _wordId(PracticeItem word) => PracticeItemCard.generateItemId(word);

String _anchorOf(SelectedPair pair) =>
    pair.anchorIsGrammar ? pair.grammarCardId : _wordId(pair.word);

String _pairId(RoundPair p) => '${p.word.id}|${p.bundle}';

final _golden = {
  (1, 0.3, 0.0): [
    'nouns:lux|Konsonantische-Deklination-mf',
    'verbs:decernere|ind.fut.pass',
    'nouns:septimus|Adjektiv-a-o',
    'nouns:cicero|Konsonantische-Deklination-mf',
    'nouns:turpis|Adjektiv-zweiendig',
    'verbs:circumdare|ind.fut.pass',
    'nouns:hic|Pronomen-hic',
    'nouns:mos|Konsonantische-Deklination-mf',
    'verbs:adesse|konj.perf.akt',
    'nouns:barbarus|Adjektiv-a-o',
  ],
  (2, 0.05, 0.2): [
    'verbs:stringere|konj.impf.akt',
    'nouns:saevus|Adjektiv-a-o',
    'verbs:ruere|konj.impf.akt',
    'nouns:infestus|Adjektiv-a-o',
    'verbs:delectare|konj.impf.akt',
    'nouns:celer|Adjektiv-dreiendig',
    'nouns:caelum|O-Deklination-neutrum',
    'nouns:foedus|Konsonantische-Deklination-n',
    'nouns:iratus|Adjektiv-a-o',
    'verbs:metuere|konj.impf.akt',
  ],
  (3, 0.02, 0.0): [
    'nouns:pietas|Konsonantische-Deklination-mf',
    'nouns:praeda|A-Deklination',
    'nouns:comes|Konsonantische-Deklination-mf',
    'verbs:auferre|part.perf.pass',
    'verbs:dolere|ind.praes.pass',
    'verbs:spectare|inf.fut.akt',
    'nouns:mare|Konsonantische-Deklination-i-n',
    'nouns:tristis|Adjektiv-zweiendig',
    'nouns:occultus|Adjektiv-a-o',
    'nouns:vox|Konsonantische-Deklination-mf',
  ],
};

void main() {
  late List<PracticeItem> items;
  late CourseFilter filter;
  late List<Topic> topics;
  late Map<String, PracticeItemCard> fresh;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final all = await loadAllPracticeItems();
    final curriculum = await loadCurriculum(bookAssets);
    final lessons = await loadLessonData(bookAssets);
    filter = CourseFilter(
      Settings(courseWords: LessonRange.full),
      curriculum,
      lessons,
    );
    items = all.where(filter.reachesPractice).toList();
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    topics = topicsOf(items, curriculum, nounTypeDisplays: nouns.displayByType);
    await FsrsStorage.syncCards(all);
    fresh = await FsrsStorage.syncGrammarCards(all);
  });

  /// Seeded: a share [dueShare] of the cards due, a share [newShare] of the
  /// word cards new and due, the rest reviewed and due tomorrow.
  SelectionInput state(int seed, double dueShare, double newShare) {
    final rng = Random(seed);
    final r = <String, double>{};
    final cards = <String, PracticeItemCard>{};
    for (final card in fresh.values) {
      r[card.itemId] = rng.nextDouble();
      final isNew =
          !card.itemId.startsWith('grammar:') && rng.nextDouble() < newShare;
      final due = rng.nextDouble() < dueShare;
      cards[card.itemId] = isNew
          ? card.copyWith(due: _now)
          : card.copyWith(
              lastReview: _now.subtract(const Duration(days: 2)),
              due: due ? _now : _now.add(const Duration(days: 1)),
            );
    }
    return (
      cards: cards,
      items: items,
      filter: filter,
      retrievability: (c) => r[c.itemId]!,
      now: _now,
    );
  }

  Set<String> cardsOf(RoundPair p) => {
    _wordId(p.word),
    GrammarCardId(p.word.dataFileId, p.bundle),
  };

  test('with enough due cards, a mixed round is the one of due cards only', () {
    for (final MapEntry(key: (seed, dueShare, newShare), value: pairs)
        in _golden.entries) {
      expect(
        planMixed(state(seed, dueShare, newShare), topics).map(_pairId),
        pairs,
        reason: 'seed $seed',
      );
    }
  });

  test('with no card due, a mixed round fills up with the lowest R first', () {
    final input = state(4, 0, 0);
    final pairs = planMixed(input, topics);

    expect(pairs, hasLength(roundLength));
    final weakest = input.cards.values.reduce(
      (a, b) => input.retrievability(a) <= input.retrievability(b) ? a : b,
    );
    expect(pairs.expand(cardsOf), contains(weakest.itemId));
  });

  test('with a few due cards, a mixed round has them and fills up with '
      'cards not due', () {
    final input = state(5, 0, 0);
    final due = input.cards.keys
        .where((id) => !id.startsWith('grammar:'))
        .take(3)
        .toSet();
    final cards = {
      for (final MapEntry(:key, :value) in input.cards.entries)
        key: due.contains(key) ? value.copyWith(due: _now) : value,
    };
    final pairs = planMixed((
      cards: cards,
      items: input.items,
      filter: input.filter,
      retrievability: input.retrievability,
      now: input.now,
    ), topics);

    expect(pairs, hasLength(roundLength));
    expect(pairs.map((p) => _wordId(p.word)), containsAll(due));
  });

  test('the anchors come in the order of an independent oracle: due reviewed '
      'by R, due new by course order, then the rest by R; ties by due date, '
      'then id', () {
    final master = Random(352);
    final rs = [0.1, 0.2, 0.3, 0.5, 0.8];
    final offsets = [1, 2, 3];
    final classes = <String, int>{};
    void count(String name) =>
        classes.update(name, (n) => n + 1, ifAbsent: () => 1);

    for (var run = 0; run < 300; run++) {
      final rng = Random(master.nextInt(1 << 30));
      final subset = {
        for (var i = 0; i < 2 + rng.nextInt(5); i++)
          items[rng.nextInt(items.length)],
      }.toList();
      final index = BundleIndex(subset, filter);
      final ids = [
        for (final w in index.bundlesOfWord.keys) _wordId(w),
        ...index.wordsOfBundle.keys,
      ];
      final dueMode = run % 3;
      final newShare = run % 2 == 0 ? 0.0 : 0.4;
      final r = <String, double>{};
      final cards = <String, PracticeItemCard>{};
      for (final id in ids) {
        r[id] = rs[rng.nextInt(rs.length)];
        final isDue = switch (dueMode) {
          0 => true,
          1 => false,
          _ => rng.nextBool(),
        };
        final hours = Duration(hours: offsets[rng.nextInt(offsets.length)]);
        cards[id] = fresh[id]!.copyWith(
          lastReview: rng.nextDouble() < newShare
              ? null
              : _now.subtract(const Duration(days: 2)),
          due: isDue ? _now.subtract(hours) : _now.add(hours),
        );
      }
      bool due(String id) => !cards[id]!.due.isAfter(_now);
      bool reviewed(String id) => cards[id]!.lastReview != null;

      final reviewedIn = <String, int>{};
      for (final id in ids) {
        if (id.startsWith('grammar:') && reviewed(id)) {
          final file = index.fileOf[id]!;
          reviewedIn[file] = (reviewedIn[file] ?? 0) + 1;
        }
      }
      int tier(String id) => due(id) ? (reviewed(id) ? 0 : 1) : 2;
      int oracle(String a, String b) {
        final byTier = tier(a) - tier(b);
        if (byTier != 0) return byTier;
        if (tier(a) == 1) {
          final byLesson = index.lessonOf[a]! - index.lessonOf[b]!;
          if (byLesson != 0) return byLesson;
          final byReviewed =
              (reviewedIn[index.fileOf[a]] ?? 0) -
              (reviewedIn[index.fileOf[b]] ?? 0);
          if (byReviewed != 0) return byReviewed;
        } else {
          if (r[a] != r[b]) return r[a]! < r[b]! ? -1 : 1;
          final byDue = cards[a]!.due.compareTo(cards[b]!.due);
          if (byDue != 0) return byDue;
        }
        return a.compareTo(b);
      }

      List<String> anchors({required bool includeNotDue}) {
        final taken = <String>{};
        while (true) {
          final pair = selectPair(
            cards: cards,
            items: subset,
            filter: filter,
            retrievability: (c) => r[c.itemId]!,
            now: _now,
            taken: taken,
            includeNotDue: includeNotDue,
            index: index,
          );
          if (pair == null) return [...taken];
          final anchor = _anchorOf(pair);
          expect(taken.add(anchor), isTrue);
          final partners = pair.anchorIsGrammar
              ? index.wordsOfBundle[anchor]!.words.map(_wordId)
              : index.bundlesOfWord[pair.word]!.map(
                  (b) => GrammarCardId(pair.word.dataFileId, b) as String,
                );
          final untaken = partners.where((p) => !taken.contains(p));
          final strongest = (untaken.isEmpty ? partners : untaken).reduce((
            a,
            b,
          ) {
            if (r[a] != r[b]) return r[a]! > r[b]! ? a : b;
            final byLesson = index.lessonOf[a]! - index.lessonOf[b]!;
            if (byLesson != 0) return byLesson < 0 ? a : b;
            return a.compareTo(b) <= 0 ? a : b;
          });
          final partner = pair.anchorIsGrammar
              ? _wordId(pair.word)
              : pair.grammarCardId as String;
          expect(partner, strongest, reason: 'run $run anchor $anchor');
        }
      }

      final sorted = [...ids]..sort(oracle);
      expect(anchors(includeNotDue: true), sorted, reason: 'run $run');
      expect(
        anchors(includeNotDue: false),
        sorted.where(due).toList(),
        reason: 'run $run',
      );

      count(switch (dueMode) {
        0 => 'all due',
        1 => 'none due',
        _ => 'mixed',
      });
      if (ids.any((id) => !reviewed(id))) count('with new');
      if (ids.every(reviewed)) count('without new');
      if (ids.any((id) => tier(id) == 1) && ids.any((id) => tier(id) == 2)) {
        count('new due and not due');
      }
      if (ids.any((id) => tier(id) == 0) && ids.any((id) => tier(id) == 2)) {
        count('reviewed due and not due');
      }
    }

    for (final name in [
      'all due',
      'none due',
      'mixed',
      'with new',
      'without new',
      'new due and not due',
      'reviewed due and not due',
    ]) {
      expect(classes[name] ?? 0, greaterThan(0), reason: name);
    }
  });
}
