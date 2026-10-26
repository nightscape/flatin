import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';

import 'support/course_providers.dart';
import 'support/stored_settings.dart';
import 'support/word_classification_harness.dart' show letItLoad;

Finder _text(String key) => find.byKey(Key(key));

String _plain(WidgetTester tester, String key) =>
    tester.widget<Text>(_text(key)).textSpan!.toPlainText();

Future<void> _tapChip(WidgetTester tester, String key) async {
  await tester.ensureVisible(_text(key));
  await tester.pumpAndSettle();
  await tester.tap(_text(key));
  await tester.pumpAndSettle();
  await letItLoad(tester);
}

/// The x of [lesson] on the shared scale: the centre of its bar.
double _x(WidgetTester tester, int lesson) =>
    tester.getCenter(_text('kursstand.words.bar.$lesson')).dx;

/// Moves one thumb of [slider] onto [lesson], as a drag that ends there.
Future<void> _set(
  WidgetTester tester,
  String slider, {
  required bool start,
  required int lesson,
}) async {
  final widget = tester.widget<RangeSlider>(_text(slider));
  final rect = tester.getRect(_text(slider));
  final unit = (_x(tester, lesson) - rect.left - 24) / (rect.width - 48);
  final v = start
      ? RangeValues(unit, widget.values.end)
      : RangeValues(widget.values.start, unit);
  widget.onChanged!(v);
  widget.onChangeEnd!(v);
  await tester.pumpAndSettle();
  await letItLoad(tester);
}

Future<void> _move(WidgetTester tester, String slider, int from, int to) async {
  final values = tester.widget<RangeSlider>(_text(slider)).values;
  final rect = tester.getRect(_text(slider));
  final endFirst =
      (_x(tester, from) - rect.left - 24) / (rect.width - 48) > values.end;
  for (final start in endFirst ? [false, true] : [true, false]) {
    await _set(tester, slider, start: start, lesson: start ? from : to);
  }
}

/// Drags the thumb on [lesson] by [dx] pixels.
Future<void> _dragThumb(
  WidgetTester tester,
  String slider,
  int lesson,
  double dx,
) async {
  await tester.dragFrom(
    Offset(_x(tester, lesson), tester.getCenter(_text(slider)).dy),
    Offset(dx, 0),
  );
  await tester.pumpAndSettle();
  await letItLoad(tester);
}

Future<void> _open(
  WidgetTester tester,
  Settings settings, {
  String? page,
  Curriculum? curriculum,
}) => openSettingsWith(
  tester,
  settings.toJson(),
  page: page,
  overrides: [
    if (curriculum != null)
      curriculumProvider.overrideWith((ref) async => curriculum),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the card shows histograms, sliders, chains, summary and reset', (
    tester,
  ) async {
    await _open(tester, Settings());

    expect(_text('kursstand.words.slider'), findsOneWidget);
    expect(_text('kursstand.grammar.slider'), findsOneWidget);
    expect(_text('kursstand.words.bar.1'), findsOneWidget);
    expect(_text('kursstand.words.bar.$laterLesson'), findsOneWidget);
    expect(_text('kursstand.grammar.bar.$laterLesson'), findsOneWidget);
    expect(_text('kursstand.chain.left'), findsOneWidget);
    expect(_text('kursstand.chain.right'), findsOneWidget);
    expect(
      _plain(tester, 'kursstand.summary'),
      matches(r'^L1 – Später:  \d+ Wörter  ·  \d+ Themen$'),
    );
    expect(find.text('Auf Kursstand zurücksetzen'), findsOneWidget);
  });

  testWidgets('both sliders and both histograms share one scale', (
    tester,
  ) async {
    await _open(tester, Settings());

    expect(
      tester.getRect(_text('kursstand.words.slider')).width,
      tester.getRect(_text('kursstand.grammar.slider')).width,
    );
    for (final lesson in [1, 20, lastLesson, laterLesson]) {
      expect(
        tester.getCenter(_text('kursstand.words.bar.$lesson')).dx,
        tester.getCenter(_text('kursstand.grammar.bar.$lesson')).dx,
        reason: 'lesson $lesson',
      );
    }
  });

  testWidgets('the words reach Später, the linked grammar with them', (
    tester,
  ) async {
    await _open(tester, Settings(courseWords: LessonRange(10, 20)));

    await _move(tester, 'kursstand.words.slider', 12, laterLesson);
    final stored = await storedSettings();
    expect(stored['courseWords'], LessonRange(12, laterLesson).toJson());
    expect(stored['courseGrammar'], LessonRange(1, laterLesson).toJson());
  });

  testWidgets('each chain symbol toggles its own link', (tester) async {
    await _open(tester, Settings(courseWords: LessonRange(10, 20)));

    await tester.tap(_text('kursstand.chain.right'));
    await tester.pumpAndSettle();
    await letItLoad(tester);
    var stored = await storedSettings();
    expect(stored['grammarToLinked'], isFalse);
    expect(stored['grammarFromLinked'], isFalse);

    await tester.tap(_text('kursstand.chain.left'));
    await tester.pumpAndSettle();
    await letItLoad(tester);
    stored = await storedSettings();
    expect(stored['grammarFromLinked'], isTrue);
    expect(stored['courseGrammar'], LessonRange(10, 20).toJson());
  });

  testWidgets('the grammar range follows the word range while linked', (
    tester,
  ) async {
    await _open(tester, Settings());

    await _move(tester, 'kursstand.words.slider', 21, 23);

    final stored = await storedSettings();
    expect(stored['courseWords'], LessonRange(21, 23).toJson());
    expect(stored['courseGrammar'], LessonRange(1, 23).toJson());
  });

  testWidgets('dragging the word thumbs to the ends stops at L1 and Später', (
    tester,
  ) async {
    await _open(tester, Settings(courseWords: LessonRange(10, 20)));

    await _dragThumb(tester, 'kursstand.words.slider', 20, 1000);
    expect(
      (await storedSettings())['courseWords'],
      LessonRange(10, laterLesson).toJson(),
    );

    await _dragThumb(tester, 'kursstand.words.slider', 10, -1000);
    expect(
      (await storedSettings())['courseWords'],
      LessonRange(1, laterLesson).toJson(),
    );
  });

  testWidgets('the grammar slider moves on its own when unlinked', (
    tester,
  ) async {
    await _open(tester, Settings(grammarToLinked: false));

    await _move(tester, 'kursstand.words.slider', 1, 5);
    await _move(tester, 'kursstand.grammar.slider', 3, 12);

    final stored = await storedSettings();
    expect(stored['courseWords'], LessonRange(1, 5).toJson());
    expect(stored['courseGrammar'], LessonRange(3, 12).toJson());
  });

  group('a tap on a bar moves the nearer handle', () {
    Future<void> tapBar(WidgetTester tester, String bar, int lesson) async {
      await tester.tap(_text('kursstand.$bar.bar.$lesson'));
      await tester.pumpAndSettle();
      await letItLoad(tester);
    }

    for (final (lesson, expected, why) in [
      (5, LessonRange(5, 20), 'left of the range moves the start'),
      (30, LessonRange(10, 30), 'right of the range moves the end'),
      (12, LessonRange(12, 20), 'inside, nearer the start'),
      (18, LessonRange(10, 18), 'inside, nearer the end'),
    ]) {
      testWidgets('words: $lesson, $why', (tester) async {
        await _open(tester, Settings(courseWords: LessonRange(10, 20)));

        await tapBar(tester, 'words', lesson);

        expect((await storedSettings())['courseWords'], expected.toJson());
      });
    }

    testWidgets('grammar bar, chain open: moves only the grammar', (
      tester,
    ) async {
      await _open(
        tester,
        Settings(
          grammarToLinked: false,
          courseWords: LessonRange(10, 20),
          courseGrammar: LessonRange(5, 20),
        ),
      );

      await tapBar(tester, 'grammar', laterLesson);

      final stored = await storedSettings();
      expect(stored['courseGrammar'], LessonRange(5, laterLesson).toJson());
      expect(stored['courseWords'], LessonRange(10, 20).toJson());
    });

    testWidgets('grammar bar, chain closed: moves the grammar and opens '
        'the chain', (tester) async {
      await _open(tester, Settings(courseWords: LessonRange(10, 20)));

      await tapBar(tester, 'grammar', 30);

      final stored = await storedSettings();
      expect(stored['courseWords'], LessonRange(10, 20).toJson());
      expect(stored['courseGrammar'], LessonRange(1, 30).toJson());
      expect(stored['grammarToLinked'], isFalse);
    });
  });

  testWidgets('a bar tap that moves a thumb into another book widens that '
      'book', (tester) async {
    await _open(tester, Settings(courseWords: LessonRange(25, 32)));
    double width() => tester.getSize(_text('kursstand.words.bar.3')).width;
    final before = width();

    await tester.tap(_text('kursstand.words.bar.10'));
    await tester.pumpAndSettle();
    await letItLoad(tester);

    expect(
      (await storedSettings())['courseWords'],
      LessonRange(10, 32).toJson(),
    );
    expect(width(), greaterThan(before));
  });

  testWidgets('a word chip flips the word against the range', (tester) async {
    await _open(tester, Settings(courseWords: LessonRange(21, 23)));

    await _tapChip(tester, 'kursstand.word.rosa');
    expect((await storedSettings())['forcedOnWords'], ['rosa']);

    final lessons = await loadLessonData(lessonDataAssets);
    final inside = lessons
        .lessonWords[lessons.lessonNames.firstWhere(
          (n) => lessonNumber(n) == 21,
        )]!
        .first;
    await _tapChip(tester, 'kursstand.word.$inside');
    expect((await storedSettings())['deselectedWords'], [inside]);

    await _tapChip(tester, 'kursstand.word.rosa');
    expect((await storedSettings())['forcedOnWords'], isEmpty);
  });

  testWidgets('a topic chip flips the topic against the grammar range', (
    tester,
  ) async {
    final topics = (await loadCurriculum(curriculumAssets)).courseTopics;
    final earlier = topics.firstWhere((t) => t.lesson <= 3);
    final later = topics.firstWhere((t) => t.lesson > 3 && t.lesson < 40);
    await _open(tester, Settings(courseWords: LessonRange(1, 3)));

    await _tapChip(tester, 'kursstand.topic.${earlier.key}');
    await _tapChip(tester, 'kursstand.topic.${later.key}');

    final stored = await storedSettings();
    expect(stored['deselectedTopics'], [earlier.key]);
    expect(stored['forcedOnTopics'], [later.key]);
  });

  testWidgets(
    'a word outside the word range is greyed and a tap forces it on',
    (tester) async {
      final lessons = await loadLessonData(lessonDataAssets);
      final inRange = (await loadAllPracticeItems()).firstWhere(
        (i) => lessons.lessonNumberOf(i) == 21,
      );

      await _open(
        tester,
        Settings(courseWords: LessonRange(21, 23)),
        page: 'words',
      );

      expect(isChecked(tester, _text('word.rosa')), isFalse);
      expect(
        find.descendant(
          of: _text('word.rosa'),
          matching: find.text('außerhalb des Bereichs'),
        ),
        findsOneWidget,
      );
      expect(
        titleColor(tester, _text('word.${normalizeDiacritics(inRange.lemma)}')),
        Colors.black,
        reason: 'a word the course has reached must not look greyed',
      );
      expect(
        titleColor(tester, _text('word.rosa')),
        isNot(Colors.black),
        reason: 'an out-of-range word row must look greyed',
      );

      await tester.tap(_text('word.rosa'));
      await tester.pumpAndSettle();
      await letItLoad(tester);

      expect(isChecked(tester, _text('word.rosa')), isTrue);
      expect((await storedSettings())['forcedOnWords'], ['rosa']);
    },
  );

  testWidgets('a word whose type is taught later says from which lesson', (
    tester,
  ) async {
    final lessons = await loadLessonData(lessonDataAssets);
    final item = (await loadAllPracticeItems()).firstWhere(
      (i) => lessons.lessonNumberOf(i) == 21,
    );
    final curriculum = await lateTypeCurriculum(item.dataFileId, item.type, 32);

    await _open(
      tester,
      Settings(courseWords: LessonRange(21, 23)),
      page: 'words',
      curriculum: curriculum,
    );

    final tile = _text('word.${normalizeDiacritics(item.lemma)}');
    expect(
      find.descendant(of: tile, matching: find.text('ab Lektion 32')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.text('außerhalb des Bereichs')),
      findsNothing,
    );
    expect(
      titleColor(tester, tile),
      isNot(Colors.black),
      reason: 'a word whose type is taught later must look greyed',
    );

    expect(isChecked(tester, tile), isTrue);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await letItLoad(tester);

    expect(isChecked(tester, tile), isFalse);
    expect((await storedSettings())['deselectedWords'], [item.lemma]);
  });

  testWidgets('a type forced on clears the gap of its word', (tester) async {
    final lessons = await loadLessonData(lessonDataAssets);
    final item = (await loadAllPracticeItems()).firstWhere(
      (i) => lessons.lessonNumberOf(i) == 21,
    );
    final curriculum = await lateTypeCurriculum(item.dataFileId, item.type, 32);

    await _open(
      tester,
      Settings(
        courseWords: LessonRange(21, 23),
        forcedOnTypes: {
          item.dataFileId: {item.type},
        },
      ),
      page: 'words',
      curriculum: curriculum,
    );

    final tile = _text('word.${normalizeDiacritics(item.lemma)}');
    expect(
      find.descendant(of: tile, matching: find.byType(Text)),
      findsOneWidget,
    );
    expect(titleColor(tester, tile), Colors.black);
  });

  testWidgets('a word forced on outside the word range is not greyed', (
    tester,
  ) async {
    await _open(
      tester,
      Settings(courseWords: LessonRange(21, 23), forcedOnWords: {'rosa'}),
      page: 'words',
    );

    expect(isChecked(tester, _text('word.rosa')), isTrue);
    expect(titleColor(tester, _text('word.rosa')), Colors.black);
    expect(
      find.descendant(
        of: _text('word.rosa'),
        matching: find.text('außerhalb des Bereichs'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'a word whose forms are all taught later says from which lesson',
    (tester) async {
      final lessons = await loadLessonData(lessonDataAssets);
      final item = (await loadAllPracticeItems()).firstWhere(
        (i) => lessons.lessonNumberOf(i) == 21,
      );
      final curriculum = await lateFormsCurriculum(item.dataFileId, 30);

      await _open(
        tester,
        Settings(courseWords: LessonRange(21, 23)),
        page: 'words',
        curriculum: curriculum,
      );

      final tile = _text('word.${normalizeDiacritics(item.lemma)}');
      expect(
        find.descendant(of: tile, matching: find.text('ab Lektion 30')),
        findsOneWidget,
      );
      expect(titleColor(tester, tile), isNot(Colors.black));
    },
  );

  testWidgets('a grammar gap below the grammar range names the grammar', (
    tester,
  ) async {
    final lessons = await loadLessonData(lessonDataAssets);
    final item = (await loadAllPracticeItems()).firstWhere(
      (i) => lessons.lessonNumberOf(i) == 21,
    );
    final curriculum = await lateFormsCurriculum(item.dataFileId, 2);
    final (axis, value) = basicFormFeature[item.dataFileId]!;
    final basic = item.formLabels.firstWhere((l) => l.features[axis] == value);

    await _open(
      tester,
      Settings(
        grammarToLinked: false,
        courseGrammar: LessonRange(5, 40),
        disabledForms: {
          item.dataFileId: {basic.key},
        },
      ),
      page: 'words',
      curriculum: curriculum,
    );

    final tile = _text('word.${normalizeDiacritics(item.lemma)}');
    expect(
      find.descendant(
        of: tile,
        matching: find.text('Grammatik außerhalb des Bereichs'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('reset clears the overrides and keeps the ranges', (
    tester,
  ) async {
    await _open(
      tester,
      Settings(
        courseWords: LessonRange(1, 5),
        forcedOnWords: {'rosa'},
        deselectedWords: {'servus'},
        forcedOnTopics: {'41/verbs/ger'},
        deselectedTopics: {'1/nouns/*'},
      ),
    );

    await tester.tap(_text('kursstand.reset'));
    await tester.pumpAndSettle();
    await letItLoad(tester);

    final stored = await storedSettings();
    expect(stored['forcedOnWords'], isEmpty);
    expect(stored['deselectedWords'], isEmpty);
    expect(stored['forcedOnTopics'], isEmpty);
    expect(stored['deselectedTopics'], isEmpty);
    expect(stored['courseWords'], LessonRange(1, 5).toJson());
  });

  testWidgets('overrides survive a slider move', (tester) async {
    await _open(
      tester,
      Settings(forcedOnWords: {'rosa'}, deselectedWords: {'servus'}),
    );

    await _move(tester, 'kursstand.words.slider', 1, 12);

    final stored = await storedSettings();
    expect(stored['forcedOnWords'], ['rosa']);
    expect(stored['deselectedWords'], ['servus']);
    expect(stored['courseWords'], LessonRange(1, 12).toJson());
  });

  testWidgets('the tiles open the detail pages', (tester) async {
    await _open(tester, Settings());

    for (final page in ['words', 'nouns', 'verbs', 'input']) {
      await openSettingsPage(tester, page);
      expect(
        _text('settings.${page == 'input' ? 'input' : page}.title'),
        findsOneWidget,
        reason: page,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
