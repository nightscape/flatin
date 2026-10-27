import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:latin_practice/screens/home_screen.dart';

import 'support/course_providers.dart';
import 'support/word_classification_harness.dart';

void main() {
  testWidgets('a type focus picked on the home screen survives a narrower '
      'course range', (tester) async {
    seedSettings(Settings());
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapInApp(const HomeScreen(), forcedLocale: const Locale('de')),
    );
    await letItLoad(tester);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    final before = await c.read(wordFocusesProvider.future);
    expect(before.map((f) => f.id), contains('verbs:Unregelmäßig'));

    await tester.tap(find.byKey(const Key('focus.picker')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('focus.option.verbs:Unregelmäßig')).last,
        matching: find.byType(Text),
      ),
    );
    await tester.pumpAndSettle();

    await c.read(settingsProvider.notifier).setWordRange(LessonRange(1, 1));
    await letItLoad(tester);
    expect(
      (await c.read(wordFocusesProvider.future)).map((f) => f.id),
      isNot(contains('verbs:Unregelmäßig')),
    );
    expect(tester.takeException(), isNull);
  });
}
