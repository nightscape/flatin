// The Lernziel chip rows in the settings card at 360x640, for drawn stored
// settings of the real course: each row shows the presets of the Kursstand
// with exactly one selected chip, a tap on a preset stores that row's range
// and moves its bookmarks, the presets follow a Kursstand change, and the
// chips and squeezed pages keep their touch sizes. The home entry names the
// current ranges and opens the card.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/models/lernziel_chips.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:latin_practice/screens/kursstand_sliders.dart';
import 'package:latin_practice/screens/settings_screen.dart';
import 'package:latin_practice/widgets/kursstand_shelf.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/gen_settings.dart';
import 'support/kursstand_shelf_driver.dart';
import 'support/word_classification_harness.dart';
import 'support/latin_course.dart';

const _later = 'Später';

Future<ProviderContainer> _pump(WidgetTester tester, Widget screen) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapInApp(screen, forcedLocale: const Locale('de')));
  await letItLoad(tester);
  return ProviderScope.containerOf(
    tester.element(find.byType(screen.runtimeType)),
  );
}

Future<void> _store(
  WidgetTester tester,
  ProviderContainer container,
  Settings settings,
) async {
  SharedPreferences.setMockInitialValues({
    'practice_settings': jsonEncode(settings.toJson()),
  });
  container.invalidate(settingsProvider);
  await letItLoad(tester);
}

/// The chips of a row as shown: label and whether selected, in order.
List<(String, bool)> _row(WidgetTester tester, {required bool words}) => [
  for (final chip in tester.widgetList<ChoiceChip>(
    find.byWidgetPredicate(
      (w) =>
          w is ChoiceChip &&
          '${w.key}'.contains('lernziel.${words ? 'words' : 'grammar'}.'),
    ),
  ))
    ((chip.label as Text).data!, chip.selected),
];

void _expectRows(
  WidgetTester tester,
  Settings s,
  List<int> starts,
  String why,
) {
  final presets = chipsFor(s.kursstand, starts);
  for (final (words, range) in [
    (true, s.courseWords),
    (false, s.courseGrammar),
  ]) {
    final shown = _row(tester, words: words);
    expect(shown, [
      for (final p in presets) (lernzielLabel(p, _later), p == range),
      if (!presets.contains(range)) (lernzielLabel(range, _later), true),
    ], reason: '$why: the ${words ? 'word' : 'grammar'} row');
    expect(shown.where((c) => c.$2), hasLength(1), reason: why);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the chip rows select one chip, set the bookmarks and follow '
      'the Kursstand at 360x640', (tester) async {
    final starts = (await tester.runAsync(
      () => loadLessonData(latinCourse.books),
    ))!.bookStarts;
    final container = await _pump(tester, const SettingsScreen());
    final fixed = [
      Settings(courseWords: LessonRange(1, 1), kursstand: 1),
      Settings(courseWords: LessonRange(21, 21), kursstand: 21),
      Settings(courseWords: LessonRange(21, 24), kursstand: 24),
      Settings(
        courseWords: LessonRange(3, 30),
        courseGrammar: LessonRange(24, 24),
        grammarToLinked: false,
        kursstand: 24,
      ),
      Settings(
        courseWords: LessonRange(25, laterLesson),
        grammarFromLinked: true,
        kursstand: 24,
      ),
      Settings(kursstand: lastLesson),
    ];
    final rng = Random(3513);
    final cases = [
      ...fixed,
      for (var i = 0; i < 10; i++) drawLernzielSettings(rng, starts),
    ];
    for (final (i, s) in cases.indexed) {
      await _store(tester, container, s);
      final shown = container.read(settingsProvider).requireValue;
      final why =
          'case $i: K${s.kursstand}, ${s.courseWords}, '
          '${s.courseGrammar}';
      expect(tester.takeException(), isNull, reason: why);
      _expectRows(tester, shown, starts, why);

      final words = rng.nextBool() || i < fixed.length && i.isEven;
      final presets = chipsFor(shown.kursstand, starts);
      final preset = presets[rng.nextInt(presets.length)];
      final chip = find.byKey(
        Key(
          'lernziel.${words ? 'words' : 'grammar'}.'
          '${lernzielLabel(preset, _later)}',
        ),
      );
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
      await tester.tap(chip);
      await letItLoad(tester);
      final tapped = container.read(settingsProvider).requireValue;
      final oracle = chooseLernziel(shown, preset, words: words);
      expect(tapped.toJson(), oracle.toJson(), reason: '$why: tap $preset');
      final shelf = shelfPainter(tester);
      expect(shelf.words, oracle.courseWords, reason: '$why: word bookmarks');
      expect(shelf.grammar, oracle.courseGrammar, reason: '$why: grammar');
      _expectRows(tester, tapped, starts, '$why, after the tap');

      final n = 1 + rng.nextInt(lastLesson);
      await container.read(settingsProvider.notifier).setKursstand(n);
      await letItLoad(tester);
      final moved = container.read(settingsProvider).requireValue;
      expect(moved.kursstand, n);
      _expectRows(tester, moved, starts, '$why, Kursstand $n');
      expect(shelfPainter(tester).scale.kursstand, n, reason: why);
    }
    expect(
      tester.getSize(find.byType(KursstandSliders)).width - 2 * shelfInset,
      240,
      reason: 'the track the squeezed pages are sized for',
    );
  });

  testWidgets('the home entry names both ranges and opens the book view', (
    tester,
  ) async {
    final container = await _pump(tester, const HomeScreen());
    final s = Settings(
      courseWords: LessonRange(21, 24),
      courseGrammar: LessonRange(24, 24),
      grammarToLinked: false,
      kursstand: 24,
    );
    await _store(tester, container, s);
    String text(String row) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(Key('home.lernziel.$row')),
            matching: find.byType(Text),
          ),
        )
        .data!;
    expect(text('words'), 'Wörter L21–L24');
    expect(text('grammar'), 'Grammatik L24');
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('home.lernziel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home.lernziel')));
    await tester.pumpAndSettle();
    await letItLoad(tester);
    expect(find.byKey(const Key('kursstand.card')), findsOneWidget);
    expect(_row(tester, words: true), [
      ('L24', false),
      ('L21–L24', true),
      ('L1–L24', false),
    ]);
  });
}
