import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/word_focus.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/topics.dart';
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/providers/reward_provider.dart';
import 'package:latin_practice/services/reward_storage.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/round_providers.dart';
import 'package:latin_practice/screens/grammar_start_screen.dart';
import 'package:latin_practice/screens/exercise_screen.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:latin_practice/screens/round_end_screen.dart';
import 'package:latin_practice/screens/round_screen.dart';
import 'package:latin_practice/services/fsrs_storage.dart';

import 'support/course_providers.dart';
import 'support/round_driver.dart';
import 'support/word_classification_harness.dart';

class _Stub implements ExerciseGenerator {
  int calls = 0;

  @override
  ExerciseKind get kind => ExerciseKind.formBilden;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    calls++;
    throw const CannotBuild('stub');
  }
}

/// No share of right answers and no error count anywhere on the screen.
void _expectNoScore() {
  expect(find.textContaining('%'), findsNothing);
  expect(find.textContaining(RegExp(r'\d+ von \d+ richtig')), findsNothing);
}

Future<void> _pumpStart(WidgetTester tester, {bool animation = true}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  seedSettings(
    Settings(courseWords: LessonRange(1, 1), rewardAnimation: animation),
  );
  await tester.pumpWidget(
    wrapInApp(
      const GrammarStartScreen(),
      forcedLocale: const Locale('de'),
      overrides: [exerciseRandomProvider.overrideWithValue(Random(17))],
    ),
  );
  await letItLoad(tester);
}

String _translation(Map<String, dynamic> json, String key) =>
    key.split('.').fold<dynamic>(json, (node, part) => node[part]) as String;

void main() {
  test('the wrong-answer texts name the answer, not the failure', () {
    for (final language in ['de', 'en']) {
      final json =
          jsonDecode(
                File('assets/flutter_i18n/$language.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final key in [
        'exercise.screen.wrong',
        'wordClassification.partiallyCorrect',
        'wordClassification.incorrect',
      ]) {
        expect(
          _translation(json, key).toLowerCase(),
          isNot(
            anyOf(
              contains('falsch'),
              contains('richtig'),
              contains('wrong'),
              contains('correct'),
            ),
          ),
          reason: '$language $key',
        );
      }
    }
  });

  testWidgets('the start page offers today\'s topic by its name and lists '
      'every topic, with no score', (tester) async {
    await _pumpStart(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GrammarStartScreen)),
    );
    final offer = container
        .read(todayOfferProvider(const AllWords()))
        .requireValue;
    final topics = container
        .read(topicsProvider(const AllWords()))
        .requireValue;
    const namer = DerivedTopicNamer();
    expect(find.text('Heute dran'), findsOneWidget);
    expect(
      find.text('Neues Thema: ${namer.name((offer as NewTopicOffer).topic)}'),
      findsOneWidget,
    );
    expect(find.text(namer.name(topics.first)), findsWidgets);
    expect(find.text('Lektion 1'), findsWidgets);
    _expectNoScore();
  });

  testWidgets('the start page names topics only through its namer', (
    tester,
  ) async {
    seedSettings(Settings(courseWords: LessonRange(1, 1)));
    await tester.pumpWidget(
      wrapInApp(
        const GrammarStartScreen(namer: _FixedNamer()),
        forcedLocale: const Locale('de'),
      ),
    );
    await letItLoad(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GrammarStartScreen)),
    );
    final topics = container
        .read(topicsProvider(const AllWords()))
        .requireValue;
    expect(find.text('Neues Thema: Thema X'), findsOneWidget);
    expect(find.text('Thema X'), findsNWidgets(topics.length));
    for (final topic in topics) {
      expect(find.text(topic.name), findsNothing);
    }
  });

  testWidgets('a round counts "Aufgabe n von 10", never 11, asks a wrong '
      'task again as "Noch einmal" and ends on the coins without '
      'a new building', (tester) async {
    await _pumpStart(tester);
    await tap(tester, 'round.start.go');
    await letItLoad(tester);

    expect(find.text('Aufgabe 1 von 10'), findsOneWidget);
    _expectNoScore();
    final first = shown(tester);
    await answer(tester, first, right: false);
    await letItLoad(tester);
    final stored = await tester.runAsync(FsrsStorage.loadCards);
    expect(stored![first.wordCardId]!.lastReview, isNotNull);
    expect(stored[first.grammarCardId]!.lastReview, isNull);
    expect(identical(shown(tester), first), isFalse);

    for (var n = 2; n <= 10; n++) {
      expect(find.text('Aufgabe $n von 10'), findsOneWidget);
      expect(find.textContaining('11'), findsNothing);
      _expectNoScore();
      await answer(tester, shown(tester), right: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('🪙 +10'), findsOneWidget, reason: 'task $n');
      expect(find.textContaining('Punkte'), findsNothing);
      await letItLoad(tester);
    }

    expect(find.text('Noch einmal'), findsOneWidget);
    expect(find.textContaining('11'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    _expectNoScore();
    await answer(tester, shown(tester), right: true);
    await letItLoad(tester);

    expect(find.byType(RoundEndScreen), findsOneWidget);
    expect(find.text('Runde geschafft!'), findsOneWidget);
    expect(find.text('+95 Münzen'), findsOneWidget);
    expect(find.text('Kontostand: 95 Münzen'), findsOneWidget);
    expect(find.byKey(const Key('round.end.canBuy')), findsNothing);
    expect(find.textContaining('⭐'), findsNothing);
    expect(find.textContaining('Neu in deiner Stadt'), findsNothing);
    expect(find.byKey(const Key('town.building.domus')), findsNothing);
    _expectNoScore();
    final after = await tester.runAsync(FsrsStorage.loadCards);
    expect(after![first.grammarCardId]!.lastReview, isNotNull);

    await tap(tester, 'round.end.done');
    await letItLoad(tester);
    expect(find.byType(GrammarStartScreen), findsOneWidget);
  });

  testWidgets('the end screen shows the bonus sum next to the points', (
    tester,
  ) async {
    seedSettings(Settings(courseWords: LessonRange(1, 1)));
    await tester.runAsync(
      () => RewardStorage.save(
        const RewardLedger(
          earned: {coins: 50},
          tagged: {
            coins: {'bonus': 20},
          },
        ),
      ),
    );
    await tester.pumpWidget(
      wrapInApp(
        Consumer(
          builder: (_, ref, _) => ref.watch(rewardsProvider).hasValue
              ? const RoundEndScreen(start: RewardLedger(), focus: AllWords())
              : const SizedBox(),
        ),
        forcedLocale: const Locale('de'),
      ),
    );
    await letItLoad(tester);

    expect(find.text('+30 Münzen'), findsOneWidget);
    expect(find.text('⭐ +20 Bonus'), findsOneWidget);
    expect(find.text('Kontostand: 50 Münzen'), findsOneWidget);
  });

  testWidgets('the end screen offers no purchase when every affordable '
      'building still waits for others', (tester) async {
    seedSettings(Settings(courseWords: LessonRange(1, 1)));
    await tester.runAsync(
      () => RewardStorage.save(
        const RewardLedger(
          earned: {coins: 300},
          buildings: ['domus', 'hortus', 'ager', 'fons', 'vinea'],
        ),
      ),
    );
    await tester.pumpWidget(
      wrapInApp(
        Consumer(
          builder: (_, ref, _) => ref.watch(rewardsProvider).hasValue
              ? const RoundEndScreen(start: RewardLedger(), focus: AllWords())
              : const SizedBox(),
        ),
        forcedLocale: const Locale('de'),
      ),
    );
    await letItLoad(tester);

    expect(find.byKey(const Key('round.end.canBuy')), findsNothing);
  });

  testWidgets('with the animation off a right answer shows no burst', (
    tester,
  ) async {
    await _pumpStart(tester, animation: false);
    await tap(tester, 'round.start.go');
    await letItLoad(tester);

    await answer(tester, shown(tester), right: true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Aufgabe 2 von 10'), findsOneWidget);
    expect(find.textContaining('🪙'), findsNothing);
  });

  testWidgets('home and drawer open the start page, which builds no '
      'exercise; a pair no kind fits shows its error on the round screen '
      'only', (tester) async {
    seedSettings(Settings(courseWords: LessonRange(1, 1)));
    final stub = _Stub();
    await tester.pumpWidget(
      wrapInApp(
        const HomeScreen(),
        overrides: [
          exerciseRegistryProvider.overrideWithValue([stub]),
        ],
      ),
    );
    await letItLoad(tester);

    for (final key in ['nouns', 'verbs', 'grammar']) {
      final button = find.byKey(Key('home.$key.button'));
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    }
    expect(find.textContaining('Assertion failed'), findsNothing);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await letItLoad(tester);
    await tester.tap(find.byKey(const Key('drawer.grammar')));
    await letItLoad(tester);
    expect(find.byType(GrammarStartScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(GrammarStartScreen))).pop();
    await letItLoad(tester);

    await tap(tester, 'home.grammar.button');
    await letItLoad(tester);
    expect(find.byType(GrammarStartScreen), findsOneWidget);
    expect(stub.calls, 0);
    expect(find.textContaining('no exercise kind fits'), findsNothing);

    await tap(tester, 'round.start.go');
    await letItLoad(tester);
    expect(find.byType(RoundScreen), findsOneWidget);
    expect(stub.calls, greaterThan(0));
    expect(find.textContaining('no exercise kind fits'), findsOneWidget);
  });

  _macronTwinTest();

  for (final dropdownFile in ['nouns', 'verbs']) {
    testWidgets('a noun round\'s typed form kinds take the nouns\' '
        'input setting: dropdown for $dropdownFile', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      seedSettings(
        Settings(
          courseWords: LessonRange(1, 20),
          inputStrategyIds: {dropdownFile: 'dropdown_all_forms'},
        ),
      );
      await tester.pumpWidget(
        wrapInApp(
          const GrammarStartScreen(),
          forcedLocale: const Locale('de'),
          overrides: [
            exerciseRandomProvider.overrideWithValue(Random(17)),
            exerciseRegistryProvider.overrideWithValue([
              for (final g in exerciseGenerators)
                if (ExerciseScreen.inputKinds.contains(g.kind)) g,
            ]),
          ],
        ),
      );
      await letItLoad(tester);
      await tap(tester, 'round.start.go');
      await letItLoad(tester);

      final seen = <(String, ExerciseKind)>{};
      while (find.byType(ExerciseScreen).evaluate().isNotEmpty) {
        final screen = tester.widget<ExerciseScreen>(
          find.byType(ExerciseScreen),
        );
        final file = screen.word.dataFileId;
        seen.add((file, screen.exercise.kind));
        expect(
          tester.widget(find.byKey(const Key('exercise.input'))) is TextField,
          file != dropdownFile,
          reason: '$file ${screen.exercise.kind.name}',
        );
        await answer(tester, screen.exercise, right: true);
        await letItLoad(tester);
      }
      expect(seen, {
        ('nouns', ExerciseKind.fehlerFinden),
        ('nouns', ExerciseKind.umformen),
      });
    });
  }

  for (final (kind, fits) in [
    (ExerciseKind.fehlerFinden, (Topic t) => t.dataFileId == 'nouns'),
    (ExerciseKind.formenKette, (Topic t) => t.bundles.contains('ind.fut2.akt')),
  ]) {
    testWidgets('a round\'s ${kind.name} takes the dropdown setting', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      seedSettings(
        Settings(
          inputStrategyIds: {
            'nouns': 'dropdown_distractors',
            'verbs': 'dropdown_distractors',
          },
        ),
      );
      await tester.pumpWidget(
        wrapInApp(
          const GrammarStartScreen(),
          forcedLocale: const Locale('de'),
          overrides: [
            exerciseRandomProvider.overrideWithValue(Random(17)),
            exerciseRegistryProvider.overrideWithValue([
              for (final g in exerciseGenerators)
                if (g.kind == kind) g,
            ]),
          ],
        ),
      );
      await letItLoad(tester);
      final topic = ProviderScope.containerOf(
        tester.element(find.byType(GrammarStartScreen)),
      ).read(topicsProvider(const AllWords())).requireValue.firstWhere(fits);
      await tap(tester, 'round.topic.${topic.id}');
      await letItLoad(tester);

      var shown = 0;
      while (find.byType(ExerciseScreen).evaluate().isNotEmpty) {
        final screen = tester.widget<ExerciseScreen>(
          find.byType(ExerciseScreen),
        );
        shown++;
        expect(
          find.descendant(
            of: find.byKey(const Key('exercise.input')),
            matching: find.byType(DropdownButtonFormField<String>),
          ),
          findsOneWidget,
          reason: screen.word.lemma,
        );
        await answer(tester, screen.exercise, right: true);
        await letItLoad(tester);
      }
      expect(shown, greaterThan(0));
    });
  }
}

void _macronTwinTest() => testWidgets(
  'the round driver answers right when the asked form has a '
  'macron twin in the all-forms dropdown',
  (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    seedSettings(
      Settings(
        courseWords: LessonRange(1, 20),
        inputStrategyIds: {'nouns': 'dropdown_all_forms'},
      ),
    );
    await tester.pumpWidget(
      wrapInApp(
        const GrammarStartScreen(),
        forcedLocale: const Locale('de'),
        overrides: [
          exerciseRandomProvider.overrideWithValue(Random(99)),
          exerciseRegistryProvider.overrideWithValue([
            for (final g in exerciseGenerators)
              if (ExerciseScreen.inputKinds.contains(g.kind)) g,
          ]),
        ],
      ),
    );
    await letItLoad(tester);
    await tap(tester, 'round.start.go');
    await letItLoad(tester);
    while (find.byType(ExerciseScreen).evaluate().isNotEmpty) {
      final screen = tester.widget<ExerciseScreen>(find.byType(ExerciseScreen));
      await answer(tester, screen.exercise, right: true);
      await letItLoad(tester);
    }
  },
);

final class _FixedNamer implements TopicNamer {
  const _FixedNamer();

  @override
  String name(Topic topic) => 'Thema X';
}
