import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/word_focus.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/exercise_choice.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/selection.dart';
import 'package:latin_practice/data/topics.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/round_providers.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.utc(2026, 10, 20);

void main() {
  late List<PracticeItem> items;
  late Curriculum curriculum;
  late LessonData lessons;
  late List<Topic> topics;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    items = await loadAllPracticeItems();
    curriculum = await loadCurriculum(bookAssets);
    lessons = await loadLessonData(bookAssets);
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    topics = topicsOf(items, curriculum, nounTypeDisplays: nouns.displayByType);
  });

  Set<GrammarBundle> bundlesOf(String dataFileId, int lesson) => topics
      .singleWhere((t) => t.dataFileId == dataFileId && t.lesson == lesson)
      .bundles
      .toSet();

  test('every bundle of the items is in exactly one topic', () {
    final expected = {
      for (final item in items)
        for (final key in item.formOrder)
          (item.dataFileId, bundleOf(item, key)),
    };
    final listed = [
      for (final topic in topics)
        for (final bundle in topic.bundles) (topic.dataFileId, bundle),
    ];
    expect(listed.length, listed.toSet().length);
    expect(listed.toSet(), expected);
  });

  test('topics are in course order, nouns before verbs, with names', () {
    final order = [
      for (final t in topics) (t.lesson, t.dataFileId == 'nouns' ? 0 : 1),
    ];
    expect(
      order,
      [...order]..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2),
    );
    expect(order.toSet().length, order.length);
    for (final topic in topics) {
      expect(topic.name.trim(), isNotEmpty, reason: topic.id);
      expect(topic.id, '${topic.dataFileId}:${topic.lesson}');
    }
  });

  test(
    'the later topics hold the bundles that only the later entry teaches',
    () {
      final firstLesson = <(String, GrammarBundle), int>{};
      for (final item in items) {
        for (final key in item.formOrder) {
          final lesson = max(
            curriculum.typeLesson(item.dataFileId, item.type),
            curriculum.formLesson(item.dataFileId, key),
          );
          firstLesson.update(
            (item.dataFileId, bundleOf(item, key)),
            (l) => min(l, lesson),
            ifAbsent: () => lesson,
          );
        }
      }
      final expected = {
        for (final e in firstLesson.entries)
          if (e.value == laterLesson) e.key,
      };
      final listed = {
        for (final t in topics.where((t) => t.lesson == laterLesson))
          for (final b in t.bundles) (t.dataFileId, b),
      };
      expect(expected, isNotEmpty);
      expect(listed, expected);
    },
  );

  test('volume 2 verb topics group the bundles a lesson introduces', () {
    expect(bundlesOf('verbs', 23), {'ind.plusq.pass', 'ind.fut2.pass'});
    expect(bundlesOf('verbs', 10), {'ind.impf.akt'});
    expect(
      topics.singleWhere((t) => t.id == 'verbs:10').name,
      'Indikativ Imperfekt Aktiv',
    );
  });

  test('topic order equals the selection order of the grammar cards', () async {
    final filter = CourseFilter(
      Settings(courseWords: LessonRange.full),
      curriculum,
      lessons,
    );
    await FsrsStorage.syncCards(items);
    var cards = await FsrsStorage.syncGrammarCards(items);
    cards = {
      for (final card in cards.values)
        card.itemId: card.copyWith(
          due: card.itemId.startsWith('grammar:')
              ? _now
              : _now.add(const Duration(days: 1)),
        ),
    };
    final lessonOfTopic = {
      for (final t in topics)
        for (final b in t.bundles) (t.dataFileId, b): t.lesson,
    };
    final picked = <(String, GrammarBundle)>[];
    for (var n = 0; n < 25; n++) {
      final pair = selectPair(
        cards: cards,
        items: items,
        filter: filter,
        retrievability: (_) => 0.5,
        now: _now,
      )!;
      final id = pair.grammarCardId;
      picked.add((pair.word.dataFileId, pair.bundle));
      cards = {
        ...cards,
        id: cards[id]!.copyWith(
          lastReview: _now,
          due: _now.add(const Duration(days: 1)),
        ),
      };
    }
    final sortedLessons = [...lessonOfTopic.values]..sort();
    expect([for (final p in picked) lessonOfTopic[p]!], sortedLessons.take(25));
  });

  test('offered bundles are the topic bundles that are unlocked', () {
    final filter = CourseFilter(
      Settings(courseWords: LessonRange(1, 10)),
      curriculum,
      lessons,
    );
    final unlocked = unlockedBundles(
      filter,
      items.where(filter.reachesPractice),
    );
    final offered = {for (final t in topics) t.id: offeredBundles(t, unlocked)};
    for (final t in topics) {
      expect(offered[t.id], t.bundles.toSet().intersection(unlocked));
    }
    expect(offered['verbs:10'], {'ind.impf.akt'});
    expect(offered['verbs:23'], isEmpty);
  });
  test('the provider lists only the topics of the course position', () async {
    SharedPreferences.setMockInitialValues({
      'practice_settings': jsonEncode(
        Settings(courseWords: LessonRange(1, 10)).toJson(),
      ),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final listed = await container.read(
      topicsProvider(const AllWords()).future,
    );
    expect(listed.map((t) => t.id), contains('verbs:10'));
    expect(listed.map((t) => t.id), isNot(contains('verbs:23')));
    expect(
      listed.map((t) => t.id),
      everyElement(isIn(topics.map((t) => t.id))),
    );
  });
}
