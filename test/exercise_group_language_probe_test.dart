import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/exercise_sort_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/exercise_fakes.dart';
import 'support/word_classification_harness.dart';

const _german = [
  'Indikativ',
  'Konjunktiv',
  'Präsens',
  'Imperfekt',
  'Futur',
  'Perfekt',
  'Plusquamperfekt',
  'Aktiv',
  'Passiv',
];

void main() {
  for (final language in ['en', 'de']) {
    testWidgets('app locale $language: sort and tick group names', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'app_locale': language});
      final c = ProviderContainer(retry: noRetry);
      addTearDown(c.dispose);
      final byType = await tester.runAsync(
        () => c.read(practicableItemsByTypeProvider.future),
      );
      final vocare = byType!['verbs']!.singleWhere(
        (i) => i.id == 'verbs:vocare',
      );
      for (final (kind, bundle, unlocked) in [
        (
          ExerciseKind.ankreuzen,
          'ind.fut.akt',
          ['ind.impf.akt', 'ind.fut.akt'],
        ),
        (
          ExerciseKind.sortieren,
          'ind.perf.akt',
          ['ind.perf.akt', 'ind.plusq.akt', 'ind.fut2.akt'],
        ),
      ]) {
        final e = exerciseGenerators
            .singleWhere((g) => g.kind == kind)
            .build(
              vocare,
              bundle,
              fakeExerciseContext(unlocked: unlocked.toSet(), pool: [vocare]),
              Random(0),
            );
        final groups = (e.answer as SortingAnswer).groups;
        tester.view.physicalSize = const Size(390, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          wrapInApp(
            ExerciseSortWidget(word: vocare, exercise: e, onResponse: (_) {}),
            forcedLocale: Locale(language),
          ),
        );
        await tester.pumpAndSettle();
        final text = [
          for (final t in tester.widgetList<Text>(find.byType(Text)))
            t.data ?? t.textSpan?.toPlainText() ?? '',
        ].join(' | ');
        // ignore: avoid_print
        print('PROBE $language $kind groups=$groups');
        expect(
          _german.where((w) => RegExp('\\b$w\\b').hasMatch(text)),
          language == 'en' ? isEmpty : isNotEmpty,
          reason: '$kind in $language: $text',
        );
      }
    });
  }
}
