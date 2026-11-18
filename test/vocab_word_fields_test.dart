// Generators: no random generators except the schema test's seeded draw of
// vocab specs and the spelling that gets brackets (reused: grammarTree and
// grammarSource of test/support/grammar_breaker.dart). The other properties
// range over every vocab item of the real course, because the vocab data is
// the input space: the real items are what the learner meets.
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/input_strategy.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/providers/lookup_provider.dart';
import 'package:latin_practice/screens/exercise_screen.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/grammar_breaker.dart';
import 'support/latin_course.dart';
import 'support/stored_settings.dart';
import 'support/word_classification_harness.dart';

const _vocabPath = 'lib/data/latin_vocab.yaml';

Future<List<PracticeItem>> _vocab() => loadPracticeItems(_vocabPath);

Exercise _askingFor(PracticeItem item) {
  final expected = FormOption(
    text: item.forms.single,
    formKey: item.formOrder.single,
    lexemeId: item.id,
  );
  return Exercise(
    wordCardId: item.id,
    grammarCardId: GrammarCardId(item.dataFileId, item.type),
    kind: ExerciseKind.formTippen,
    questionKey: 'exercise.screen.sampleQuestion',
    languageName: latinLang.name,
    answer: TypedAnswer(expected, item.acceptedForms.single),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every spelling a vocab item accepts is an answer and a lookup hit, '
      'and an item with a note is found by its lemma', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      retry: noRetry,
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    addTearDown(container.dispose);
    final index = await container.read(formIndexProvider.future);
    final vocab = await _vocab();

    var variants = 0;
    var noted = 0;
    for (final item in vocab) {
      final spellings = item.acceptedForms.single;
      variants += spellings.length - 1;
      if (item.note != null) noted++;
      for (final spelling in spellings) {
        expect(item.accepts(0, spelling), isTrue, reason: spelling);
        expect(
          index.find(spelling).where((r) => r.wordKey == item.wordKey),
          isNotEmpty,
          reason: '${item.id}: "$spelling" finds the item',
        );
      }
    }
    expect(variants, greaterThan(0), reason: 'the course has a variant');
    expect(noted, greaterThan(0), reason: 'the course has a noted word');
  });

  test('a lemma spelling with a bracket is refused, and the same spec '
      'without it loads', () {
    final source = File(_vocabPath).readAsStringSync();
    final tree = grammarTree(source);
    final items = tree['items'] as List;
    final tried = <String>{};
    for (var seed = 0; seed < 40; seed++) {
      final r = Random(seed);
      final fresh = grammarTree(source);
      final spec = (fresh['items'] as List)[r.nextInt(items.length)] as Map;
      final parts = spec['parts'] as Map<String, dynamic>;
      final part = parts.keys.single;
      final spellings = [
        for (final s
            in parts[part] is List ? parts[part] as List : [parts[part]])
          '$s',
      ];
      if (r.nextBool() && spellings.length == 1) {
        spellings.add('${spellings[0]}x');
      }
      final at = r.nextInt(spellings.length);
      tried.add(at == 0 ? 'first' : 'variant');
      final bracket = ['(', ')', ' (note)', '(a)'][r.nextInt(4)];

      parts[part] = spellings.length == 1 ? spellings.single : spellings;
      parseGrammarFiles(lang: latinLang, refuseBracketLemmas: true, {
        _vocabPath: grammarSource(fresh),
      });

      spellings[at] = '${spellings[at]}$bracket';
      parts[part] = spellings;
      expect(
        () => parseGrammarFiles(lang: latinLang, refuseBracketLemmas: true, {
          _vocabPath: grammarSource(fresh),
        }),
        throwsA(
          isA<SchemaError>()
              .having((e) => e.rule, 'rule', 'S3')
              .having((e) => e.message, 'message', contains('has brackets')),
        ),
        reason: 'seed $seed: ${spellings[at]}',
      );
    }
    expect(tried, {'first', 'variant'});
  });

  test(
    'a word with a note is listed with its note, the pronoun of the same '
    'lemma keeps its own lesson, and a note that no item has is refused',
    () async {
      final lessons = await loadLessonData(latinCourse.books);
      final items = await loadAllPracticeItems();
      final noted = items.where((i) => i.note != null).toList();
      expect(noted, isNotEmpty);
      for (final item in noted) {
        final plain = items.where(
          (i) => i.lemma == item.lemma && i.note == null,
        );
        expect(plain, isNotEmpty, reason: '${item.lemma} has a homograph');
        for (final other in plain) {
          expect(other.wordKey, isNot(item.wordKey));
          expect(
            lessons.lessonNumberOf(other),
            isNot(lessons.lessonNumberOf(item)),
            reason:
                '${item.lemma} and its homograph are told apart by the lesson',
          );
        }
        assertLessonsCoverItems(lessons, items);

        final typo = LessonData(
          wordToLesson: {...lessons.wordToLesson, '${item.wordKey}x': 1},
          notedWords: {...lessons.notedWords, '${item.wordKey}x'},
          lessonWords: lessons.lessonWords,
          bookByLesson: lessons.bookByLesson,
          books: lessons.books,
        );
        expect(
          () => assertLessonsCoverItems(typo, items),
          throwsA(
            isStateError.having(
              (e) => e.message,
              'message',
              contains('${item.wordKey}x'),
            ),
          ),
        );
      }
    },
  );

  testWidgets('the exercise screen shows the note of a vocab word and no '
      'note widget for a word without one', (tester) async {
    final vocab = (await tester.runAsync(_vocab))!;
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final item in vocab) {
      await tester.pumpWidget(
        wrapInApp(
          ExerciseScreen(
            key: ValueKey(item.id),
            word: item,
            exercise: _askingFor(item),
            inputStrategy: InputStrategy.byId('text_field'),
            optionForms: item.formOrder.toSet(),
            onResponse: (_) {},
          ),
          forcedLocale: const Locale('de'),
        ),
      );
      await tester.pump();
      final note = find.byKey(const Key('exercise.note'));
      if (item.note == null) {
        expect(note, findsNothing, reason: item.id);
      } else {
        expect(tester.widget<Text>(note).data, item.note, reason: item.id);
      }
    }
  });

  testWidgets('the practice screen shows the note under the lemma of a '
      'vocab word and no note widget for a word without one', (tester) async {
    final vocab = (await tester.runAsync(_vocab))!;
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final item
        in vocab.where((i) => i.note != null).followedBy(vocab.take(3))) {
      await tester.pumpWidget(
        wrapInApp(
          PracticeScreen(key: ValueKey(item.id), item: item),
          forcedLocale: const Locale('de'),
        ),
      );
      await letItLoad(tester);
      final note = find.byKey(const Key('practice.note'));
      if (item.note == null) {
        expect(note, findsNothing, reason: item.id);
      } else {
        expect(tester.widget<Text>(note).data, item.note, reason: item.id);
      }
    }
  });

  testWidgets('the word list shows the note beside a noted word and switches '
      'off only that word, not its homograph', (tester) async {
    final items = (await tester.runAsync(loadAllPracticeItems))!;
    final noted = items.where((i) => i.note != null).toList();
    expect(noted, isNotEmpty);
    for (final item in noted) {
      await openSettingsWith(tester, {}, page: 'words');
      await tester.enterText(find.byKey(const Key('words.search')), item.lemma);
      await tester.pumpAndSettle();

      final note = find.byKey(Key('word.note.${item.wordKey}'));
      expect(tester.widget<Text>(note).data, item.note);
      for (final other in items.where(
        (i) => i.lemma == item.lemma && i.note == null,
      )) {
        expect(find.byKey(Key('word.note.${other.wordKey}')), findsNothing);
        expect(find.byKey(Key('word.${other.wordKey}')), findsOneWidget);
      }

      await tester.tap(find.byKey(Key('word.${item.wordKey}')));
      await tester.pumpAndSettle();
      expect((await storedSettings())['deselectedWords'], [item.wordKey]);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
