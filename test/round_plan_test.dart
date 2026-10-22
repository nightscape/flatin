import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/exercise_choice.dart';
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

void main() {
  late List<PracticeItem> items;
  late CourseFilter filter;
  late List<Topic> topics;
  late Map<String, PracticeItemCard> fresh;
  late Map<String, double> r;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final all = await loadAllPracticeItems();
    final curriculum = await loadCurriculum(curriculumAssets);
    final lessons = await loadLessonData(lessonDataAssets);
    filter = CourseFilter(
      Settings(courseWords: LessonRange(1, lastLesson)),
      curriculum,
      lessons,
    );
    items = all.where(filter.reachesPractice).toList();
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    topics = topicsOf(items, curriculum, nounTypeDisplays: nouns.displayByType);
    await FsrsStorage.syncCards(all);
    fresh = await FsrsStorage.syncGrammarCards(all);
    final rng = Random(5);
    r = {for (final id in fresh.keys) id: rng.nextDouble()};
  });

  /// Every card reviewed two days ago; due now when [due] says so, else
  /// tomorrow; [unreviewed] cards have no review and are due.
  SelectionInput input({
    required bool Function(PracticeItemCard) due,
    bool Function(PracticeItemCard) unreviewed = _never,
  }) => (
    cards: {
      for (final card in fresh.values)
        card.itemId: unreviewed(card)
            ? card.copyWith(due: _now)
            : card.copyWith(
                lastReview: _now.subtract(const Duration(days: 2)),
                due: due(card) ? _now : _now.add(const Duration(days: 1)),
              ),
    },
    items: items,
    filter: filter,
    retrievability: (c) => r[c.itemId]!,
    now: _now,
  );

  Set<GrammarBundle> offeredOf(Topic topic) => offeredBundles(
    topic,
    unlockedBundles(
      filter,
      items.where((i) => i.dataFileId == topic.dataFileId),
    ),
  );

  test('a blocked plan has 10 pairs of offered bundles, the weakest bundle '
      'first and in turn, and new words while the bundle has them', () {
    final index = BundleIndex(items, filter);
    final plan = input(due: (_) => true);
    int poolOf(Topic t) => {
      for (final b in offeredOf(t))
        ...index.wordsOfBundle[GrammarCardId(t.dataFileId, b)]!.words,
    }.length;
    final smallest = topics.reduce((a, b) => poolOf(a) <= poolOf(b) ? a : b);
    expect(poolOf(smallest), lessThan(roundLength));
    final sample = topics.where(
      (t) => t == smallest || t.id == 'verbs:1' || t.id == 'verbs:23',
    );
    expect(sample, hasLength(3));
    for (final topic in sample) {
      final offered = offeredOf(topic);
      final pairs = planBlocked(topic, offered, plan);
      expect(pairs, hasLength(roundLength), reason: topic.id);
      double rOf(GrammarBundle b) => r[GrammarCardId(topic.dataFileId, b)]!;
      final turn = [
        for (final b in topic.bundles)
          if (offered.contains(b)) b,
      ]..sort((a, b) => rOf(a).compareTo(rOf(b)));
      final used = <PracticeItem>{};
      for (final (i, (:word, :bundle)) in pairs.indexed) {
        expect(bundle, turn[i % turn.length], reason: '${topic.id} slot $i');
        final words =
            index.wordsOfBundle[GrammarCardId(topic.dataFileId, bundle)]!.words;
        expect(words, contains(word), reason: '${topic.id} slot $i');
        if (words.any((w) => !used.contains(w))) {
          expect(used, isNot(contains(word)), reason: '${topic.id} slot $i');
        }
        used.add(word);
      }
    }
  });

  test('a mixed plan takes no grammar card without a review as its anchor', () {
    final reviewedGrammar = fresh.keys
        .where((id) => id.startsWith('grammar:'))
        .take(3)
        .toSet();
    final plan = input(
      due: (c) => reviewedGrammar.contains(c.itemId),
      unreviewed: (c) =>
          c.itemId.startsWith('grammar:') &&
          !reviewedGrammar.contains(c.itemId),
    );
    final pairs = planMixed(plan, topics);
    expect(pairs, isNotEmpty);
    for (final (:word, :bundle) in pairs) {
      final id = GrammarCardId(word.dataFileId, bundle);
      expect(reviewedGrammar, contains(id));
    }
  });

  test('a mixed plan has 10 distinct words, and neighbours share a topic only '
      'where no order avoids it', () {
    final builds = BundleIndex.builds;
    final pairs = planMixed(input(due: (_) => true), topics);
    expect(BundleIndex.builds - builds, 1);
    expect(pairs, hasLength(roundLength));
    expect(pairs.map((p) => p.word).toSet(), hasLength(roundLength));

    final topicOf = {
      for (final t in topics)
        for (final b in t.bundles) GrammarCardId(t.dataFileId, b): t.id,
    };
    final ids = [
      for (final p in pairs)
        topicOf[GrammarCardId(p.word.dataFileId, p.bundle)]!,
    ];
    expect(ids.toSet().length, greaterThan(1));
    final most = ids
        .toSet()
        .map((t) => ids.where((x) => x == t).length)
        .reduce(max);
    var same = 0;
    for (var i = 1; i < ids.length; i++) {
      if (ids[i] == ids[i - 1]) same++;
    }
    expect(same, max(0, 2 * most - ids.length - 1), reason: '$ids');
  });

  test('spreading separates topics wherever the counts allow it', () {
    RoundPair p(String bundle) => (word: items.first, bundle: bundle);
    final spread = spreadTopics([
      p('a'),
      p('a'),
      p('a'),
      p('b'),
      p('b'),
    ], (pair) => pair.bundle);
    expect(spread.map((x) => x.bundle), ['a', 'b', 'a', 'b', 'a']);
  });
}

bool _never(PracticeItemCard _) => false;
