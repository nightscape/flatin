import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/main.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/stored_settings.dart';
import 'support/word_classification_harness.dart' show letItLoad;

Finder _key(String key) => find.byKey(Key(key));

/// Drags one thumb of a range slider from the stop [from] to the stop [to].
Future<void> _dragThumb(
  WidgetTester tester,
  String slider,
  int from,
  int to,
) async {
  double x(int stop) => tester.getCenter(_key('kursstand.words.bar.$stop')).dx;
  final y = tester.getCenter(_key(slider)).dy;
  final gesture = await tester.startGesture(Offset(x(from), y));
  // The drag claims the thumb nearest to where it is recognised, so first
  // move past the touch slop, then to the target.
  await gesture.moveBy(Offset(to > from ? 20 : -20, 0));
  await gesture.moveTo(Offset(x(to), y));
  await gesture.up();
  await tester.pumpAndSettle();
  await letItLoad(tester);
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byType(DrawerButton));
  await tester.pumpAndSettle();
  await tester.tap(_key('drawer.settings'));
  await tester.pumpAndSettle();
  await letItLoad(tester);
}

Future<void> _openWordsPage(WidgetTester tester) async {
  await tester.tap(_key('settings.tile.words'));
  await tester.pumpAndSettle();
  await letItLoad(tester);
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  await letItLoad(tester);
}

Future<void> _closeScreen(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_drop_down).last);
  await tester.pumpAndSettle();
  await letItLoad(tester);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

Future<Set<String>> _practicable(WidgetTester tester) async {
  final byType = await _container(
    tester,
  ).read(practicableItemsByTypeProvider.future);
  return {for (final items in byType.values) ...items.map((i) => i.id)};
}

/// What the grammar YAML and the lesson lists alone say practice offers,
/// computed without the course filter.
class _Expected {
  _Expected(this.items, this.lessons, this.curriculum);

  final List<PracticeItem> items;
  final LessonData lessons;
  final Curriculum curriculum;

  Iterable<FormKey> taughtForms(PracticeItem item, int grammar) => [
    for (final label in item.formLabels)
      if (curriculum.formLesson(item.dataFileId, label.key) <= grammar)
        label.key,
  ];

  bool reaches(PracticeItem item, int grammar) =>
      curriculum.typeLesson(item.dataFileId, item.type) <= grammar &&
      taughtForms(item, grammar).isNotEmpty;

  Set<String> ids(int fromLesson, int toLesson) => {
    for (final item in items)
      if (fromLesson <= lessons.lessonNumberOf(item) &&
          lessons.lessonNumberOf(item) <= toLesson &&
          reaches(item, toLesson))
        item.id,
  };

  PracticeItem firstWhere(bool Function(PracticeItem) test) =>
      items.firstWhere(test);
}

Future<void> _expectTaughtUpTo(
  WidgetTester tester,
  _Expected expected,
  Set<String> practicable,
  int fromLesson,
  int toLesson,
) async {
  final byId = {for (final item in expected.items) item.id: item};
  final filter = await _container(tester).read(courseFilterProvider.future);
  for (final id in practicable) {
    final item = byId[id]!;
    expect(
      expected.lessons.lessonNumberOf(item),
      inInclusiveRange(fromLesson, toLesson),
      reason: item.lemma,
    );
    expect(
      expected.curriculum.typeLesson(item.dataFileId, item.type),
      lessThanOrEqualTo(toLesson),
      reason: item.lemma,
    );
    final asked = filter.practicedForms(item.dataFileId, item.formLabels);
    expect(asked, isNotEmpty, reason: item.lemma);
    for (final key in asked) {
      expect(
        expected.curriculum.formLesson(item.dataFileId, key),
        lessThanOrEqualTo(toLesson),
        reason: '${item.lemma} $key',
      );
    }
  }
}

Future<_Expected> _expected() async => _Expected(
  await loadAllPracticeItems(),
  await loadLessonData(lessonDataAssets),
  await loadCurriculum(curriculumAssets),
);

Future<Map<String, dynamic>> _stored() => storedSettings();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> startApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 60000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(retry: noRetry, child: const LatinPracticeApp()),
    );
    await letItLoad(tester);
  }

  testWidgets(
    'Kursstand L21-L23: practice offers exactly what the YAML teaches',
    (tester) async {
      final expected = await _expected();
      await startApp(tester);
      await _openSettings(tester);

      await _dragThumb(tester, 'kursstand.words.slider', laterLesson, 23);
      await _dragThumb(tester, 'kursstand.words.slider', 1, 21);

      final stored = await _stored();
      expect(stored['courseWords'], {'from': 21, 'to': 23});
      expect(stored['grammarToLinked'], isTrue);
      expect(stored['courseGrammar'], {'from': 1, 'to': 23});

      final wanted = expected.ids(21, 23);
      expect(wanted, isNotEmpty);
      final practicable = await _practicable(tester);
      expect(practicable, wanted);

      await _expectTaughtUpTo(tester, expected, practicable, 21, 23);

      await _closeScreen(tester);
      for (final button in ['home.nouns.button', 'home.verbs.button']) {
        await tester.tap(_key(button));
        await tester.pumpAndSettle();
        await letItLoad(tester);
        final shown = tester.widget<PracticeScreen>(
          find.byType(PracticeScreen),
        );
        expect(practicable, contains(shown.item.id), reason: button);
        await _closeScreen(tester);
      }
    },
  );

  testWidgets('overrides survive a slider move and reset clears them', (
    tester,
  ) async {
    final expected = await _expected();
    await startApp(tester);
    await _openSettings(tester);
    await _dragThumb(tester, 'kursstand.words.slider', laterLesson, 23);
    await _dragThumb(tester, 'kursstand.words.slider', 1, 21);

    final inside = expected.firstWhere(
      (i) =>
          expected.ids(21, 23).contains(i.id) &&
          expected.items.where((o) => o.lemma == i.lemma).length == 1,
    );
    final outside = expected.firstWhere(
      (i) =>
          expected.lessons.lessonNumberOf(i) == 1 &&
          expected.reaches(i, 23) &&
          expected.items.where((o) => o.lemma == i.lemma).length == 1,
    );
    final range2123 = expected.ids(21, 23);
    expect(range2123, isNot(contains(outside.id)));

    await _openWordsPage(tester);
    await tester.tap(_key('word.${outside.lemma}'));
    await tester.pumpAndSettle();
    await letItLoad(tester);
    await tester.tap(_key('word.${inside.lemma}'));
    await tester.pumpAndSettle();
    await letItLoad(tester);
    await _back(tester);

    final withOverrides = {...range2123, outside.id}..remove(inside.id);
    expect(await _practicable(tester), withOverrides);
    final stored = await _stored();
    expect(stored['forcedOnWords'], [outside.lemma]);
    expect(stored['deselectedWords'], [inside.lemma]);

    await _dragThumb(tester, 'kursstand.words.slider', 23, 24);
    expect((await _stored())['courseWords'], {'from': 21, 'to': 24});
    final range2124 = expected.ids(21, 24);
    final moved = {...range2124, outside.id}..remove(inside.id);
    final practicableAfterMove = await _practicable(tester);
    expect(practicableAfterMove, moved);
    expect(practicableAfterMove, contains(outside.id));
    expect(practicableAfterMove, isNot(contains(inside.id)));
    final afterMove = await _stored();
    expect(afterMove['forcedOnWords'], [outside.lemma]);
    expect(afterMove['deselectedWords'], [inside.lemma]);

    await tester.tap(_key('kursstand.reset'));
    await tester.pumpAndSettle();
    await letItLoad(tester);

    final afterReset = await _stored();
    expect(afterReset['forcedOnWords'], isEmpty);
    expect(afterReset['deselectedWords'], isEmpty);
    expect(afterReset['courseWords'], {'from': 21, 'to': 24});
    final afterResetItems = await _practicable(tester);
    expect(afterResetItems, range2124);
    await _expectTaughtUpTo(tester, expected, afterResetItems, 21, 24);
  });
}
