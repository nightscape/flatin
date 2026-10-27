import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/screens/kursstand_sliders.dart';
import 'package:latin_practice/theme.dart';
import 'package:latin_practice/widgets/kursstand_shelf.dart';

import 'kursstand_shelf_driver.dart';
import 'word_classification_harness.dart';

/// What a [KursstandSliders] under test reports: the settings it last
/// passed on, its scale, and what it painted, all in its own coordinates.
class SlidersProbe {
  SlidersProbe(this.settings);

  Settings settings;
  late BookScale scale;
  var labels = <Rect>[];
  var tops = <Offset>[];
  var spines = <Rect>[];
  final key = GlobalKey();

  /// The course the shelf shows; during a drag it runs ahead of [settings].
  Settings shown(WidgetTester tester) {
    final shelf = shelfPainter(tester);
    return Settings(
      courseWords: shelf.words,
      courseGrammar: shelf.grammar,
      grammarFromLinked: shelf.tiedFrom,
      grammarToLinked: shelf.tiedTo,
    );
  }

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
  final lessons = (await tester.runAsync(() => loadLessonData(bookAssets)))!;
  final probe = SlidersProbe(
    Settings(
      courseWords: words,
      courseGrammar: grammar,
      grammarFromLinked: from,
      grammarToLinked: to,
    ),
  );
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
                  bookStarts: lessons.bookStarts,
                  books: lessons.books,
                  onCourse: (s) => probe.settings = s,
                  onScale: (s) => probe.scale = s,
                  onPaintLabels: (l) => probe.labels = l,
                  onPaintPages: (t, s) {
                    probe.tops = t;
                    probe.spines = s;
                  },
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
