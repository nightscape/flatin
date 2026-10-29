import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/home_screen.dart';

import 'support/course_providers.dart';
import 'support/word_classification_harness.dart';

void main() {
  testWidgets(
    'the home entry does not open a non-due item before the due list loads',
    (tester) async {
      seedSettings(Settings());
      final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
      final due = Completer<Map<String, List<PracticeItem>>>();

      await tester.pumpWidget(
        wrapInApp(
          const HomeScreen(),
          overrides: [
            practicableItemsByTypeProvider.overrideWith(
              (ref) async => {'nouns': nouns, 'verbs': []},
            ),
            dueItemsByTypeProvider.overrideWith((ref) => due.future),
          ],
        ),
      );
      await letItLoad(tester);

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('home.nouns.button')),
      );
      expect(button.onPressed, isNull);

      due.complete({
        'nouns': [nouns.last],
        'verbs': [],
      });
      await letItLoad(tester);

      final loaded = tester.widget<ElevatedButton>(
        find.byKey(const Key('home.nouns.button')),
      );
      expect(loaded.onPressed, isNotNull);
    },
  );
}
