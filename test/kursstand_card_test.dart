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
import 'support/kursstand_shelf_driver.dart';
import 'support/stored_settings.dart';
import 'support/word_classification_harness.dart' show letItLoad;

Finder _text(String key) => find.byKey(Key(key));

String _plain(WidgetTester tester, String key) =>
    tester.widget<Text>(_text(key)).data!;

Future<void> _tapChip(WidgetTester tester, String key) async {
  await tester.ensureVisible(_text(key));
  await tester.pumpAndSettle();
  await tester.tap(_text(key));
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

  testWidgets('the card shows the shelf, both summaries and reset', (
    tester,
  ) async {
    await _open(tester, Settings());

    expect(shelfPainter(tester).scale.bookStarts, isNotEmpty);
    expect(_text('kursstand.words.slider'), findsOneWidget);
    expect(_text('kursstand.grammar.slider'), findsOneWidget);
    expect(
      _plain(tester, 'kursstand.summary.words'),
      matches(r'^\d+ Wörter  ·  L1 – Später$'),
    );
    expect(
      _plain(tester, 'kursstand.summary.grammar'),
      matches(r'^\d+ Themen  ·  L1 – Später$'),
    );
    expect(find.text('Auf Kursstand zurücksetzen'), findsOneWidget);
  });

  testWidgets('the words reach Später, the linked grammar with them', (
    tester,
  ) async {
    await _open(tester, Settings(courseWords: LessonRange(10, 20)));

    await dragRange(tester, words: true, to: LessonRange(12, laterLesson));
    final stored = await storedSettings();
    expect(stored['courseWords'], LessonRange(12, laterLesson).toJson());
    expect(stored['courseGrammar'], LessonRange(1, laterLesson).toJson());
  });

  testWidgets('each screen-reader tie button ties or unties its bound', (
    tester,
  ) async {
    await _open(tester, Settings(courseWords: LessonRange(10, 20)));
    Future<void> tie(String side) async {
      tester
          .widget<Semantics>(_text('kursstand.tie.$side'))
          .properties
          .onTap!();
      await tester.pumpAndSettle();
      await letItLoad(tester);
    }

    await tie('right');
    var stored = await storedSettings();
    expect(stored['grammarToLinked'], isFalse);
    expect(stored['grammarFromLinked'], isFalse);

    await tie('left');
    stored = await storedSettings();
    expect(stored['grammarFromLinked'], isTrue);
    expect(stored['courseGrammar'], LessonRange(10, 20).toJson());
  });

  testWidgets('the grammar range follows the word range while linked', (
    tester,
  ) async {
    await _open(tester, Settings());

    await dragRange(tester, words: true, to: LessonRange(21, 23));

    final stored = await storedSettings();
    expect(stored['courseWords'], LessonRange(21, 23).toJson());
    expect(stored['courseGrammar'], LessonRange(1, 23).toJson());
  });

  testWidgets('dragging the word ribbons to the ends stops at L1 and Später', (
    tester,
  ) async {
    await _open(tester, Settings(courseWords: LessonRange(10, 20)));

    for (final (start, dx, expected) in [
      (false, 1000.0, LessonRange(10, laterLesson)),
      (true, -1000.0, LessonRange(1, laterLesson)),
    ]) {
      await tester.dragFrom(
        shelfGrip(tester, words: true, start: start),
        Offset(dx, 0),
      );
      await tester.pumpAndSettle();
      await letItLoad(tester);
      expect((await storedSettings())['courseWords'], expected.toJson());
    }
  });

  testWidgets('the grammar ribbons move on their own when unlinked', (
    tester,
  ) async {
    await _open(tester, Settings(grammarToLinked: false));

    await dragRange(tester, words: true, to: LessonRange(1, 5));
    await dragRange(tester, words: false, to: LessonRange(3, 12));

    final stored = await storedSettings();
    expect(stored['courseWords'], LessonRange(1, 5).toJson());
    expect(stored['courseGrammar'], LessonRange(3, 12).toJson());
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

    await dragRange(tester, words: true, to: LessonRange(1, 12));

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
