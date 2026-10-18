import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';

import 'support/course_providers.dart';
import 'support/word_classification_harness.dart';

void main() {
  testWidgets('a narrowed course offers no form it has not taught',
      (tester) async {
    seedSettings(Settings(courseWords: LessonRange(1, 5)));
    final curriculum = await lateGenitiveCurriculum();
    final rosa = (await loadPracticeItems('lib/data/latin_nouns.yaml'))
        .firstWhere((item) => item.lemma == 'rosa');
    tester.view.physicalSize = const Size(1200, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapInApp(
      WordClassificationScreen(item: rosa, formKey: 'nom.sg'),
      forcedLocale: const Locale('de'),
      overrides: [curriculumProvider.overrideWith((ref) async => curriculum)],
    ));
    await letItLoad(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();

    expect(find.text('Nominativ'), findsWidgets);
    expect(find.text('Genitiv'), findsNothing);
  });
}
