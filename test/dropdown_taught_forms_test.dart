import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/exercise_screen.dart';
import 'package:latin_practice/screens/grammar_start_screen.dart';
import 'package:latin_practice/screens/practice_screen.dart';

import 'support/course_providers.dart';
import 'support/round_driver.dart';
import 'support/word_classification_harness.dart';

/// Words and grammar both narrowed to [lesson], every data file on
/// [strategyId].
Settings _settings(int lesson, String strategyId) => Settings()
    .withGrammarLinked(to: false)
    .withWordRange(LessonRange(lesson, lesson))
    .withGrammarRange(LessonRange(lesson, lesson))
    .setInputStrategy('nouns', strategyId)
    .setInputStrategy('verbs', strategyId);

Future<CourseFilter> _filter() async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(courseFilterProvider.future);
}

/// The spellings of [item]'s forms taught up to the grammar end and not
/// switched off, and of the others.
({Set<String> taught, Set<String> later}) _split(
  CourseFilter filter,
  PracticeItem item,
) {
  final taught = <String>{}, later = <String>{};
  for (final (i, label) in item.formLabels.indexed) {
    final isTaught =
        filter.curriculum.formLesson(item.dataFileId, label.key) <=
            filter.settings.courseGrammar.to &&
        filter.settings.offFeaturesOf(item.dataFileId, label).isEmpty;
    (isTaught ? taught : later).add(norm(item.forms[i]));
  }
  return (taught: taught, later: later.difference(taught));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const lesson = 26;
  for (final strategyId in ['dropdown_distractors', 'dropdown_all_forms']) {
    testWidgets('a round over lesson $lesson offers several taught forms in '
        '$strategyId', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      seedSettings(_settings(lesson, strategyId));
      final filter = (await tester.runAsync(_filter))!;
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

      var dropdowns = 0;
      while (find.byType(ExerciseScreen).evaluate().isNotEmpty) {
        final screen = tester.widget<ExerciseScreen>(
          find.byType(ExerciseScreen),
        );
        final input = find.byKey(const Key('exercise.input'));
        if (tester.widget(input) is! TextField) {
          dropdowns++;
          final options = dropdownOptions(tester).map(norm).toSet();
          final reason = '${screen.word.lemma} ${screen.exercise.kind.name}';
          final taught = _split(filter, screen.word).taught;
          expect(options.length, greaterThan(1), reason: reason);
          if (strategyId == 'dropdown_all_forms') {
            expect(options, taught, reason: reason);
          } else {
            expect(taught, containsAll(options), reason: reason);
          }
        }
        await answer(tester, screen.exercise, right: true);
        await letItLoad(tester);
      }
      expect(dropdowns, greaterThan(0));
    });

    testWidgets('practice over lesson $lesson offers taught forms and no '
        'later one in $strategyId', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      seedSettings(_settings(lesson, strategyId));
      final (filter, item) = (await tester.runAsync(() async {
        final filter = await _filter();
        final items = await loadAllPracticeItems();
        return (
          filter,
          items.firstWhere(
            (i) =>
                filter.reachesPractice(i) && _split(filter, i).later.isNotEmpty,
          ),
        );
      }))!;
      final split = _split(filter, item);

      await tester.pumpWidget(
        wrapInApp(PracticeScreen(item: item), forcedLocale: const Locale('de')),
      );
      await letItLoad(tester);

      final rows = tester
          .widgetList<DropdownButton<String>>(
            find.byType(DropdownButton<String>),
          )
          .where((d) => !d.items!.any((o) => o.value == item.translation));
      expect(
        rows.length,
        filter.practicedForms(item.dataFileId, item.formLabels).length,
      );
      for (final row in rows) {
        final options = {for (final o in row.items!) norm(o.value!)};
        expect(options.length, greaterThan(1), reason: item.lemma);
        if (strategyId == 'dropdown_all_forms') {
          expect(options, split.taught, reason: item.lemma);
        } else {
          expect(split.taught, containsAll(options), reason: item.lemma);
        }
      }
    });
  }
}
