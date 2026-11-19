import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' show Rating, Scheduler;
import 'package:latin_practice/data/languages/language.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/course.dart';
import 'package:latin_practice/providers/course_provider.dart';
import 'package:latin_practice/providers/exam_provider.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:latin_practice/screens/exam_list_screen.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/gen_language.dart';
import 'support/key_echo_app.dart';
import 'support/word_classification_harness.dart' show letItLoad;
import 'tracer/toy_assets.dart';

final _en = Language.parse(
  File('lib/data/languages/en.yaml').readAsStringSync(),
);

const _alphabet = 'abcdefghijklmnopqrstuvwxyz';

String _word(Random r) => String.fromCharCodes([
  for (var i = 0; i < 1 + r.nextInt(8); i++)
    _alphabet.codeUnitAt(r.nextInt(26)),
]);

String _spaces(Random r) => [' ', '\t', '\n', '  ', '  '][r.nextInt(5)];

String _flipCase(String c) =>
    c == c.toLowerCase() ? c.toUpperCase() : c.toLowerCase();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the English answer rules accept spacing, first-letter case and '
      'apostrophe variants and refuse every other change', () {
    // Generators: drawn words of 1..4 parts (new, English-only: the answer
    // rules are one function of text); no shared generator draws free text.
    for (var seed = 0; seed < 300; seed++) {
      final r = Random(seed);
      final parts = [for (var i = 0; i < 1 + r.nextInt(4); i++) _word(r)];
      final w = parts.join(' ');
      final expected = _en.fold(w);
      String n(String s) => normalizeAnswer(_en, s);

      final spaced = parts.map((p) => '$p${_spaces(r)}').join().trimRight();
      expect(
        n('${_spaces(r)}${parts.join(_spaces(r))}${_spaces(r)}'),
        n(expected),
        reason: 'seed $seed spacing',
      );
      expect(n(spaced), n(w), reason: 'seed $seed inner runs');
      expect(
        n('${_flipCase(w[0])}${w.substring(1)}'),
        n(w),
        reason: 'seed $seed first letter',
      );
      expect(n("don’t $w"), n("don't $w"), reason: 'seed $seed apostrophe');

      final at = 1 + r.nextInt(w.length > 1 ? w.length - 1 : 1);
      if (w.length > 1 && w[at] != ' ') {
        expect(
          n('${w.substring(0, at)}${_flipCase(w[at])}${w.substring(at + 1)}'),
          isNot(n(w)),
          reason: 'seed $seed later case',
        );
      }
      final i = r.nextInt(w.length);
      if (w[i] != ' ') {
        final other = _alphabet[(_alphabet.indexOf(w[i]) + 1) % 26];
        expect(
          n('${w.substring(0, i)}$other${w.substring(i + 1)}'),
          isNot(n(w)),
          reason: 'seed $seed other letter',
        );
      }
    }
  });

  test('switching to the English course and back, or starting on it, leaves '
      'the Latin cards and settings as they were', () async {
    // Generators: the reviewed Latin card is drawn from the real items by
    // seed; the stored state is the real card store.
    for (var seed = 0; seed < 3; seed++) {
      resetPracticeData();
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(retry: noRetry);
      addTearDown(c.dispose);
      await c.read(activeCourseProvider.future);
      final cards = await c.read(fsrsCardsProvider.future);
      final ids = [
        for (final id in cards.keys)
          if (!id.startsWith('grammar:')) id,
      ]..sort();
      await reviewWordCard(
        Scheduler(),
        cards,
        ids[Random(seed).nextInt(ids.length)],
        Rating.good,
      );
      await c.read(settingsProvider.future);
      await c.read(settingsProvider.notifier).setKursstand(1 + seed);

      Future<Map<String, Object>> stored() async {
        final prefs = await SharedPreferences.getInstance();
        return {for (final k in prefs.getKeys()) k: prefs.get(k)!};
      }

      final before = await stored();
      await c.read(activeCourseProvider.notifier).select('englisch');
      await c.read(examPacksProvider.future);
      await c.read(settingsProvider.future);
      await c.read(activeCourseProvider.notifier).select('latein');
      c.invalidate(fsrsCardsProvider);
      await c.read(fsrsCardsProvider.future);
      final after = await stored();
      expect(
        {
          for (final e in after.entries)
            if (e.key != activeCourseKey) e.key: e.value,
        },
        {
          for (final e in before.entries)
            if (e.key != activeCourseKey) e.key: e.value,
        }..removeWhere((k, _) => k.startsWith('practice_settings.')),
        reason: 'seed $seed',
      );

      resetPracticeData();
      final d = ProviderContainer(retry: noRetry);
      addTearDown(d.dispose);
      SharedPreferences.setMockInitialValues({
        ...before,
        activeCourseKey: 'englisch',
      });
      expect(await d.read(courseProvider.future), isA<Course>());
      expect((await d.read(courseProvider.future)).id, 'englisch');
      await d.read(settingsProvider.future);
      await d.read(examPacksProvider.future);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('practice_settings'), before['practice_settings']);
    }
  });

  test('the real list loads both courses', () async {
    final courses = await loadCourses();
    expect([for (final c in courses) c.id], ['latein', 'englisch']);
    expect(courses.last.dataFiles, isEmpty);
  });

  group('exam-only course', () {
    const optional = ['gloss_files', 'books', 'sentences', 'game_rules'];

    Map<String, String> served(Random r, Set<String> keep) {
      final data = servedCourses(drawnCourses(r, max: 1));
      final first = data.keys.firstWhere((k) => k.endsWith('/course.yaml'));
      final present = {
        'gloss_files': 'gloss_files: {}',
        'books': 'books: [$toyDir/toy_book_1.yaml]',
        'sentences': 'sentences: $toyDir/toy_sentences.yaml',
        'game_rules': 'game_rules: lib/data/game_rules.yaml',
      };
      return {
        ...data,
        coursesAsset: '- $first\n- drawn/exam/course.yaml',
        'drawn/exam/course.yaml': [
          'id: examonly',
          'name: {de: Prüfung, en: Exam}',
          'language: $toyDir/toy_language.yaml',
          'data_files: []',
          for (final k in keep) present[k]!,
        ].join('\n'),
      };
    }

    Future<void> boot(
      WidgetTester tester,
      Map<String, String> assets,
      String active,
    ) async {
      resetPracticeData();
      SharedPreferences.setMockInitialValues({activeCourseKey: active});
      injectToyCourse(served: assets);
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        KeyedSubtree(
          key: UniqueKey(),
          child: wrapInKeyEchoAppWith(const HomeScreen()),
        ),
      );
      await letItLoad(tester);
    }

    testWidgets('its home screen shows the switcher and the exams button '
        'only, and the exams screen opens, for any subset of the optional '
        'manifest keys; a course with data shows the full menu', (
      tester,
    ) async {
      // Generators: all 16 subsets of the optional keys (exhaustive, so no
      // random draw); the data course is drawnCourses (reused).
      const hidden = [
        'home.grammar.button',
        'home.wordClassification.button',
        'home.lookup.button',
        'home.lernziel',
        'home.kursstand',
        'home.town',
      ];
      for (var mask = 0; mask < 16; mask++) {
        final keep = {
          for (var i = 0; i < 4; i++)
            if (mask >> i & 1 == 1) optional[i],
        };
        final assets = served(Random(mask), keep);
        await boot(tester, assets, 'examonly');
        expect(find.byKey(const Key('course.switcher')), findsOneWidget);
        expect(find.byKey(const Key('home.exam.button')), findsOneWidget);
        expect(
          find.textContaining('home.error'),
          findsNothing,
          reason: '$mask',
        );
        for (final key in hidden) {
          expect(find.byKey(Key(key)), findsNothing, reason: '$mask $key');
        }
        expect(find.byType(ElevatedButton), findsOneWidget, reason: '$mask');
        await tester.tap(find.byKey(const Key('home.exam.button')));
        await letItLoad(tester);
        expect(find.byType(ExamListScreen), findsOneWidget, reason: '$mask');
        expect(tester.takeException(), isNull);
        expect(
          find.textContaining('home.error'),
          findsNothing,
          reason: '$mask',
        );

        final dataId = RegExp(
          r'drawn/([^/]+)/course.yaml',
        ).firstMatch(assets[coursesAsset]!)![1]!;
        await boot(tester, assets, dataId);
        for (final key in hidden.take(3)) {
          expect(find.byKey(Key(key)), findsOneWidget, reason: '$mask $key');
        }
        expect(find.byKey(const Key('home.exam.button')), findsOneWidget);
      }
    });
  });
  group('data course without a manifest key', () {
    const optional = ['gloss_files', 'books', 'sentences', 'game_rules'];

    ({Map<String, String> assets, String id}) dataCourseWithout(
      Random r,
      Set<String> dropped,
    ) {
      final courses = drawnCourses(r, min: 1, max: 1);
      final assets = servedCourses(courses);
      final key = 'drawn/${courses.single.id}/course.yaml';
      final kept = <String>[];
      var inDropped = false;
      for (final line in assets[key]!.split('\n')) {
        if (dropped.any((k) => line.startsWith('$k:'))) {
          inDropped = true;
          continue;
        }
        if (inDropped && line.startsWith('  ')) continue;
        inDropped = false;
        kept.add(line);
      }
      assets[key] = kept.join('\n');
      return (assets: assets, id: courses.single.id);
    }

    const checkOrder = ['gloss_files', 'sentences', 'game_rules', 'books'];

    Set<String> subset(int mask) => {
      for (var i = 0; i < 4; i++)
        if (mask >> i & 1 == 1) optional[i],
    };

    test('the loader refuses a data course without any of the four keys and '
        'names the manifest and the first missing key', () async {
      // Generators: all 16 subsets of the four keys (exhaustive, so no
      // random draw); the data course is drawnCourses (reused).
      for (var mask = 0; mask < 16; mask++) {
        final dropped = subset(mask);
        final d = dataCourseWithout(Random(mask), dropped);
        injectToyCourse(served: d.assets);
        if (dropped.isEmpty) {
          expect((await loadCourses()).single.id, d.id);
        } else {
          await expectLater(
            loadCourses(),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                allOf(
                  contains('drawn/${d.id}/course.yaml'),
                  contains(checkOrder.firstWhere(dropped.contains)),
                ),
              ),
            ),
            reason: '$dropped',
          );
        }
      }
    });
    test('the loader refuses the Latin manifest without any of the four '
        'keys and names the manifest and the first missing key', () async {
      // Generators: all 15 non-empty subsets of the four keys (exhaustive).
      final manifest = File('lib/data/course.yaml').readAsStringSync();
      for (var mask = 1; mask < 16; mask++) {
        final dropped = subset(mask);
        final kept = <String>[];
        var inDropped = false;
        for (final line in manifest.split('\n')) {
          if (dropped.any((k) => line.startsWith('$k:'))) {
            inDropped = true;
            continue;
          }
          if (inDropped && (line.startsWith('  ') || line.startsWith('- '))) {
            continue;
          }
          inDropped = false;
          kept.add(line);
        }
        injectToyCourse(
          served: {
            coursesAsset: '- lib/data/course.yaml',
            'lib/data/course.yaml': kept.join('\n'),
          },
        );
        await expectLater(
          loadCourses(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('lib/data/course.yaml'),
                contains(checkOrder.firstWhere(dropped.contains)),
              ),
            ),
          ),
          reason: '$dropped',
        );
      }
    });
    test('the loader refuses the Latin manifest whose gloss files lack the '
        'noun or the verb role and names the manifest and the first missing '
        'role', () async {
      // Generators: the gloss roles are every subset of {noun, verb} that
      // misses one (exhaustive over 3).
      final manifest = File('lib/data/course.yaml').readAsStringSync();
      final files = {
        'noun': 'lib/data/german_nouns.yaml',
        'verb': 'lib/data/german_verbs.yaml',
      };
      for (final roles in [
        <String>{},
        {'noun'},
        {'verb'},
      ]) {
        final map = [for (final r in roles) '$r: ${files[r]}'].join(', ');
        final edited = manifest.replaceFirst(
          RegExp(r'^gloss_files: .*$', multiLine: true),
          'gloss_files: {$map}',
        );
        injectToyCourse(
          served: {
            coursesAsset: '- lib/data/course.yaml',
            'lib/data/course.yaml': edited,
          },
        );
        await expectLater(
          loadCourses(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('lib/data/course.yaml'),
                contains(roles.contains('noun') ? 'verb' : 'noun'),
              ),
            ),
          ),
          reason: '$roles',
        );
      }
    });
  });
}
