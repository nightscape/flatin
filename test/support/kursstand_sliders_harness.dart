import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/screens/kursstand_sliders.dart';
import 'package:latin_practice/theme.dart';

import 'word_classification_harness.dart';

/// What a [KursstandSliders] under test reports: the settings its
/// callbacks lead to, its scale, and what it painted, all in its own
/// coordinates.
class SlidersProbe {
  SlidersProbe(this.settings);

  Settings settings;
  late BookScale scale;
  var chains = <(Offset, Offset, Offset)>[];
  var labels = <Rect>[];
  final key = GlobalKey();

  Offset origin(WidgetTester tester) => tester.getTopLeft(find.byKey(key));

  /// The track centre of the word or the grammar slider.
  double y(WidgetTester tester, {required bool words}) =>
      tester
          .getCenter(
            find.byKey(Key('kursstand.${words ? 'words' : 'grammar'}.slider')),
          )
          .dy -
      origin(tester).dy;
}

/// Pumps the Kursstand sliders on the real books, [width] wide, at the top
/// left of a German app.
Future<SlidersProbe> pumpSliders(
  WidgetTester tester, {
  required LessonRange words,
  required LessonRange grammar,
  required bool from,
  required bool to,
  ThemeData? theme,
  Key? boundary,
  double width = 366,
}) async {
  final bookStarts = (await tester.runAsync(
    () => loadLessonData(lessonDataAssets),
  ))!.bookStarts;
  final probe = SlidersProbe(
    Settings(
      courseWords: words,
      courseGrammar: grammar,
      grammarFromLinked: from,
      grammarToLinked: to,
    ),
  );
  Widget bar(int lesson) => Container(height: 10, color: outlineColor);
  await tester.pumpWidget(
    wrapInApp(
      Theme(
        data: theme ?? romanTheme,
        child: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox(
                width: width,
                child: KursstandSliders(
                  key: probe.key,
                  settings: probe.settings,
                  bookStarts: bookStarts,
                  wordBar: bar,
                  grammarBar: bar,
                  onWords: (r) =>
                      probe.settings = probe.settings.withWordRange(r),
                  onGrammar: (r) =>
                      probe.settings = probe.settings.withGrammarRange(r),
                  onLinked: ({from, to}) => probe.settings = probe.settings
                      .withGrammarLinked(from: from, to: to),
                  onScale: (s) => probe.scale = s,
                  onPaintChains: (e) => probe.chains = e,
                  onPaintLabels: (l) => probe.labels = l,
                ),
              ),
            ),
          ),
        ),
      ),
      forcedLocale: const Locale('de'),
    ),
  );
  await letItLoad(tester);
  await tester.pumpAndSettle();
  return probe;
}
