import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' show Rating, Scheduler;
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/main.dart';
import 'package:latin_practice/models/course.dart';
import 'package:latin_practice/models/exercise.dart' show StemCardId;
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/course_provider.dart';
import 'package:latin_practice/providers/exam_provider.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/reward_provider.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/gen_language.dart';
import 'support/word_classification_harness.dart' show letItLoad;
import 'tracer/toy_assets.dart';

const _cases = 25;
const _steps = 14;
const _packIds = ['pack-a', 'pack-b'];
const _guard = 'test/fixtures/guard';

/// What one course must read back: its own kursstand, reviewed cards and packs.
class _Own {
  int kursstand = 2;
  final reviewed = <String>{};
  final packs = <String>{};

  /// Each stem card as stored after its last mark.
  final stems = <String, String>{};
}

Future<void> _expectOwn(
  ProviderContainer c,
  DrawnCourse course,
  _Own own,
  String reason,
) async {
  expect(
    (await c.read(settingsProvider.future)).kursstand,
    own.kursstand,
    reason: '$reason: kursstand of ${course.id}',
  );
  final cards = await c.read(fsrsCardsProvider.future);
  expect(
    cards.keys.every(
      (id) =>
          id.startsWith('${course.dataFileId}:') ||
          id.startsWith('grammar:${course.dataFileId}:'),
    ),
    isTrue,
    reason: '$reason: cards of ${course.id} are its own',
  );
  expect(
    {
      for (final e in cards.entries)
        if (StemCardId.isStemCard(e.key)) e.key: jsonEncode(e.value.toMap()),
    },
    own.stems,
    reason: '$reason: stem cards of ${course.id}',
  );
  expect(
    {
      for (final e in cards.entries)
        if (!e.key.startsWith('grammar:') &&
            !StemCardId.isStemCard(e.key) &&
            e.value.lastReview != null)
          e.key,
    },
    own.reviewed,
    reason: '$reason: reviewed cards of ${course.id}',
  );
  expect(
    {for (final p in await c.read(examPacksProvider.future)) p.id},
    own.packs,
    reason: '$reason: packs of ${course.id}',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each course reads back exactly its own kursstand, cards, stem cards '
      'and packs under any sequence of switches, reviews, marks and imports, '
      'and the reward ledger counts every answer', () async {
    var marks = 0;
    for (var seed = 0; seed < _cases; seed++) {
      final r = Random(seed);
      final courses = drawnCourses(r, min: 2);
      resetPracticeData();
      injectToyCourse(served: servedCourses(courses));
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(retry: noRetry);
      addTearDown(c.dispose);
      final own = {for (final k in courses) k.id: _Own()};
      var active = courses.first;
      var answers = 0;
      final log = <String>[];
      String reason() => 'seed $seed, ${log.join(', ')}';

      for (var step = 0; step < _steps; step++) {
        switch (r.nextInt(6)) {
          case 0:
            active = courses[r.nextInt(courses.length)];
            log.add('switch ${active.id}');
            await c.read(activeCourseProvider.notifier).select(active.id);
          case 1:
            final lesson = 1 + r.nextInt(2);
            log.add('kursstand $lesson');
            await c.read(settingsProvider.future);
            await c.read(settingsProvider.notifier).setKursstand(lesson);
            own[active.id]!.kursstand = lesson;
          case 2:
            final cards = await c.read(fsrsCardsProvider.future);
            final words = [
              for (final id in cards.keys)
                if (!id.startsWith('grammar:') && !StemCardId.isStemCard(id))
                  id,
            ]..sort();
            final id = words[r.nextInt(words.length)];
            log.add('review $id');
            await reviewWordCard(Scheduler(), cards, id, Rating.good);
            c.invalidate(fsrsCardsProvider);
            own[active.id]!.reviewed.add(id);
          case 3:
            log.add('answer');
            await c
                .read(rewardsProvider.notifier)
                .send(
                  Answered(
                    right: true,
                    firstAttempt: true,
                    wordDifficulty: null,
                    kind: 'bestimmen',
                    dataFile: active.dataFileId,
                    at: DateTime(2026, 1, 1),
                  ),
                );
            answers++;
          case 4:
            final packId = _packIds[r.nextInt(_packIds.length)];
            final target = r.nextInt(courses.length + 1);
            final kurs = target == courses.length ? null : courses[target].id;
            final belongs = (kurs ?? courses.first.id) == active.id;
            log.add('import $packId for ${kurs ?? 'nothing'}');
            await c.read(examPacksProvider.future);
            final imported = c
                .read(examPacksProvider.notifier)
                .import(drawnPack(packId, kurs));
            if (belongs) {
              await imported;
              own[active.id]!.packs.add(packId);
            } else {
              await expectLater(imported, throwsA(isA<ExamRejected>()));
            }
          case 5:
            final stems = [
              for (final item in await loadAllPracticeItems())
                for (final stem in item.derivation.stems.keys)
                  StemCardId(item, stem),
            ];
            if (stems.isEmpty) break;
            final id = stems[r.nextInt(stems.length)];
            final right = r.nextBool();
            log.add('mark $id $right');
            await storeStemReview(Scheduler(), id, right);
            c.invalidate(fsrsCardsProvider);
            final stored = (await c.read(fsrsCardsProvider.future))[id]!;
            own[active.id]!.stems[id] = jsonEncode(stored.toMap());
            marks++;
        }
        await _expectOwn(c, active, own[active.id]!, reason());
      }

      for (final k in courses) {
        await c.read(activeCourseProvider.notifier).select(k.id);
        await _expectOwn(c, k, own[k.id]!, 'seed $seed, revisit');
      }
      expect(
        (await c.read(rewardsProvider.future)).earnedOf(coins),
        10 * answers,
        reason: 'seed $seed: the ledger is the sum over all courses',
      );
      final keys = (await SharedPreferences.getInstance()).getKeys();
      expect(
        keys.where((k) => k.startsWith('rewards')),
        [if (answers > 0) 'rewards'],
        reason: 'seed $seed: one ledger',
      );
    }
    expect(marks, greaterThan(0), reason: 'no drawn history marked a stem');
  });

  test('each course reads its own stored stem marking, and stored settings '
      'without one read zeigen and keep their bytes', () async {
    final withoutMarking = <String>{};
    for (var seed = 0; seed < _cases; seed++) {
      final r = Random(seed);
      final courses = drawnCourses(r, min: 2);
      resetPracticeData();
      injectToyCourse(served: servedCourses(courses));
      String keyOf(int k) =>
          k == 0 ? 'practice_settings' : 'practice_settings.${courses[k].id}';
      final stored = <String, Object>{};
      final expected = <String, StemMarking>{};
      for (var k = 0; k < courses.length; k++) {
        final json = Settings(
          lastLesson: 2,
          kursstand: 1 + r.nextInt(2),
          stemMarking: StemMarking.values[r.nextInt(StemMarking.values.length)],
        ).toJson();
        if (r.nextBool()) json.remove('stemMarking');
        final kept = r.nextInt(4) > 0;
        if (kept) stored[keyOf(k)] = jsonEncode(json);
        if (kept && !json.containsKey('stemMarking')) {
          withoutMarking.add(k == 0 ? 'first' : 'other');
        }
        expected[courses[k].id] = StemMarking.values.byName(
          (kept ? json['stemMarking'] as String? : null) ?? 'zeigen',
        );
      }
      SharedPreferences.setMockInitialValues(stored);
      final c = ProviderContainer(retry: noRetry);
      addTearDown(c.dispose);
      for (final k in [...courses]..shuffle(r)) {
        await c.read(activeCourseProvider.notifier).select(k.id);
        expect(
          (await c.read(settingsProvider.future)).stemMarking,
          expected[k.id],
          reason: 'seed $seed: ${k.id} of ${stored.keys}',
        );
      }
      final prefs = await SharedPreferences.getInstance();
      expect(
        {for (final key in stored.keys) key: prefs.getString(key)},
        stored,
        reason: 'seed $seed',
      );
    }
    expect(withoutMarking, {'first', 'other'});
  });

  test('a stored active course that is not in the list reads as the first '
      'course until the next switch overwrites it', () async {
    for (var seed = 0; seed < _cases; seed++) {
      final r = Random(seed);
      final courses = drawnCourses(r, min: 2);
      resetPracticeData();
      injectToyCourse(served: servedCourses(courses));
      SharedPreferences.setMockInitialValues({
        activeCourseKey: 'gone-${r.nextInt(1000)}',
      });
      final c = ProviderContainer(retry: noRetry);
      addTearDown(c.dispose);
      expect(await c.read(activeCourseProvider.future), courses.first.id);
      final next = courses[1 + r.nextInt(courses.length - 1)].id;
      await c.read(activeCourseProvider.notifier).select(next);
      expect(
        (await SharedPreferences.getInstance()).getString(activeCourseKey),
        next,
      );
    }
  });

  group('data stored before the course list belongs to the first course', () {
    String guard(String name) => File('$_guard/$name').readAsStringSync();

    // Static examples: the stored files of the Latin-only app.
    for (final name in ['settings_default', 'settings_drawn']) {
      test(
        'stored $name loads unchanged into the first of two courses',
        () async {
          final drawn = drawnCourses(Random(1), min: 1, max: 1).single;
          resetPracticeData();
          injectToyCourse(
            served: {
              ...servedCourses([drawn]),
              coursesAsset:
                  '- lib/data/course.yaml\n- drawn/${drawn.id}/course.yaml',
            },
          );
          SharedPreferences.setMockInitialValues({
            'practice_settings': guard('$name.stored.json'),
          });
          final c = ProviderContainer(retry: noRetry);
          addTearDown(c.dispose);
          final first = await c.read(settingsProvider.future);
          await c
              .read(settingsProvider.notifier)
              .setRewardAnimation(first.rewardAnimation);
          final prefs = await SharedPreferences.getInstance();
          expect(
            prefs.getString('practice_settings'),
            guard('$name.saved.json'),
          );
          await c.read(activeCourseProvider.notifier).select(drawn.id);
          expect((await c.read(settingsProvider.future)).kursstand, 2);
          expect(prefs.getKeys(), containsAll(['practice_settings']));
        },
      );
    }

    test('stored cards and packs load into the first course only', () async {
      final drawn = drawnCourses(Random(2), min: 1, max: 1).single;
      resetPracticeData();
      injectToyCourse(
        served: {
          ...servedCourses([drawn]),
          coursesAsset:
              '- lib/data/course.yaml\n- drawn/${drawn.id}/course.yaml',
        },
      );
      final pack = File('test/fixtures/exam/synthetic.exam').readAsStringSync();
      final id = RegExp(r'^id: (.*)$', multiLine: true).firstMatch(pack)![1]!;
      final storedCards = guard('cards_reviewed.stored.json');
      SharedPreferences.setMockInitialValues({
        'fsrs_cards': storedCards,
        'exam_packs': jsonEncode({id: pack}),
      });
      final c = ProviderContainer(retry: noRetry);
      addTearDown(c.dispose);
      final latinCards = await c.read(fsrsCardsProvider.future);
      final reviewed = {
        for (final card in jsonDecode(storedCards)['cards'] as List)
          if (card['lastReview'] != null) card['itemId'] as String,
      };
      expect({
        for (final e in latinCards.entries)
          if (e.value.lastReview != null) e.key,
      }, reviewed);
      expect(
        [for (final p in await c.read(examPacksProvider.future)) p.id],
        [id],
      );

      await c.read(activeCourseProvider.notifier).select(drawn.id);
      expect(await c.read(examPacksProvider.future), isEmpty);
      expect(
        (await c.read(
          fsrsCardsProvider.future,
        )).keys.every((k) => k.contains(drawn.dataFileId)),
        isTrue,
      );
    });
  });

  testWidgets('the course switcher exists exactly when the list has two or '
      'more courses, and choosing a course makes it the active one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (var seed = 0; seed < 6; seed++) {
      final courses = drawnCourses(Random(seed));
      resetPracticeData();
      injectToyCourse(served: servedCourses(courses));
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(seed),
          retry: noRetry,
          child: const LatinPracticeApp(),
        ),
      );
      await letItLoad(tester);
      final switcher = find.byKey(const Key('course.switcher'));
      if (courses.length == 1) {
        expect(switcher, findsNothing, reason: 'seed $seed');
        expect(
          (await SharedPreferences.getInstance()).getKeys().where(
            (k) => k.startsWith('active_course') || k.contains('.kurs'),
          ),
          isEmpty,
        );
        continue;
      }
      final language = Localizations.localeOf(
        tester.element(find.byType(HomeScreen)),
      ).languageCode;
      final last = courses.last;
      await tester.tap(switcher);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('course.option.${last.id}')).last);
      await letItLoad(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('course.active'))).data,
        last.name[language],
        reason: 'seed $seed',
      );
      expect(
        (await SharedPreferences.getInstance()).getString(activeCourseKey),
        last.id,
      );
    }
  });
}
