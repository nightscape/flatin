import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/exercise_match.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/screens/exercise_match_widget.dart';

import 'support/exercise_fakes.dart';
import 'support/i18n_keys.dart';
import 'support/word_classification_harness.dart';

const _bundle = 'ind.praes.akt';

class _SameGerman implements GermanForms {
  const _SameGerman();

  @override
  bool covers(PracticeItem item, FormKey key) => true;

  @override
  String render(PracticeItem item, FormKey key) => 'immer gleich';

  @override
  List<String> accepted(PracticeItem item, FormKey key) => [render(item, key)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PracticeItem vocare;
  late PracticeItem nominal;
  setUpAll(() async {
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
    final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
    nominal = nouns.first;
  });

  const generator = MatchGenerator();
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle, {
    ExerciseContext? ctx,
  }) => generator.build(
    word,
    bundle,
    ctx ?? fakeExerciseContext(unlocked: {bundle}, pool: [word]),
    Random(3),
  );

  MatchingAnswer answerOf(Exercise e) => e.answer as MatchingAnswer;

  group('build', () {
    test('four Latin forms to four German texts of a real verb', () {
      final exercise = build(vocare, _bundle);
      final pairs = answerOf(exercise).pairs;

      expect(exercise.kind, ExerciseKind.zuordnen);
      expect(exercise.questionKey, 'exercise.match.question');
      expect(exercise.wordCardId, vocare.id);
      expect(exercise.grammarCardId, GrammarCardId('verbs', _bundle));
      expect(pairs, hasLength(4));
      for (final (latin, german) in pairs) {
        final index = vocare.formOrder.indexOf(latin.formKey);
        expect(bundleOf(vocare, latin.formKey), _bundle);
        expect(latin.text, vocare.forms[index]);
        expect(german.formKey, latin.formKey);
        expect(german.text, '${vocare.lemma}@${latin.formKey}');
        expect(latin.builtWrongBy, isNull);
        expect(german.builtWrongBy, isNull);
      }
      expect(pairs.map((p) => norm(p.$1.text)).toSet(), hasLength(4));
      expect(pairs.map((p) => p.$2.text).toSet(), hasLength(4));
    });

    test('a real verb gets the German texts of the German verb data', () {
      final latinVerbs = parseGrammarFiles({
        for (final path in [
          'lib/data/latin_nouns.yaml',
          'lib/data/latin_verbs.yaml',
        ])
          path: File(path).readAsStringSync(),
      }).singleWhere((f) => f.dataFileId == 'verbs');
      final german = GrammarGermanForms(
        File('lib/data/german_verbs.yaml').readAsStringSync(),
        latinVerbs,
      );
      final exercise = build(
        vocare,
        _bundle,
        ctx: ExerciseContext(
          unlocked: {_bundle},
          pool: [vocare],
          german: german,
        ),
      );
      const expected = {
        'ind.praes.akt.1.sg': 'ich rufe',
        'ind.praes.akt.1.pl': 'wir rufen',
        'ind.praes.akt.2.sg': 'du rufst',
        'ind.praes.akt.2.pl': 'ihr ruft',
        'ind.praes.akt.3.sg': 'er/sie/es ruft',
        'ind.praes.akt.3.pl': 'sie (Pl.) rufen',
      };
      final pairs = answerOf(exercise).pairs;
      expect(pairs, hasLength(4));
      for (final (latin, germanOption) in pairs) {
        expect(germanOption.text, expected[latin.formKey]);
      }
    });

    test('a noun bundle builds as well', () {
      final bundle = bundleOf(nominal, nominal.formOrder.first);
      expect(answerOf(build(nominal, bundle)).pairs, hasLength(4));
    });

    test('a word without German forms cannot be built', () {
      expect(
        () => build(
          vocare,
          _bundle,
          ctx: const ExerciseContext(
            unlocked: {_bundle},
            pool: [],
            german: FakeGermanForms(coversAll: false),
          ),
        ),
        throwsA(
          isA<CannotBuild>().having(
            (e) => e.reason,
            'reason',
            contains('no German form'),
          ),
        ),
      );
    });

    test('a bundle with a form without German text cannot be built', () async {
      final latinVerbs = parseGrammarFiles({
        for (final path in [
          'lib/data/latin_nouns.yaml',
          'lib/data/latin_verbs.yaml',
        ])
          path: File(path).readAsStringSync(),
      }).singleWhere((f) => f.dataFileId == 'verbs');
      final german = GrammarGermanForms(
        File('lib/data/german_verbs.yaml').readAsStringSync(),
        latinVerbs,
      );
      final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final venire = verbs.singleWhere((i) => i.id == 'verbs:venire');
      for (final bundle in ['ind.praes.pass', 'imp.praes.akt']) {
        expect(
          () => build(
            venire,
            bundle,
            ctx: ExerciseContext(
              unlocked: {bundle},
              pool: [venire],
              german: german,
            ),
          ),
          throwsA(isA<CannotBuild>()),
          reason: bundle,
        );
      }
    });

    test('a locked bundle cannot be built', () {
      expect(
        () => build(
          vocare,
          _bundle,
          ctx: fakeExerciseContext(unlocked: {'ind.praes.pass'}),
        ),
        throwsA(
          isA<CannotBuild>().having(
            (e) => e.reason,
            'reason',
            contains('locked'),
          ),
        ),
      );
    });

    test('a bundle with fewer than four forms cannot be built', () {
      final small = vocare.formOrder
          .map((k) => bundleOf(vocare, k))
          .toSet()
          .firstWhere(
            (b) =>
                vocare.formOrder.where((k) => bundleOf(vocare, k) == b).length <
                4,
          );
      expect(
        () => build(vocare, small),
        throwsA(
          isA<CannotBuild>().having(
            (e) => e.reason,
            'reason',
            contains('distinguishable'),
          ),
        ),
      );
    });

    test('forms with the same German text cannot be told apart', () {
      expect(
        () => build(
          vocare,
          _bundle,
          ctx: const ExerciseContext(
            unlocked: {_bundle},
            pool: [],
            german: _SameGerman(),
          ),
        ),
        throwsA(isA<CannotBuild>()),
      );
    });

    test('the generator is registered', () {
      expect(
        generatorFor(ExerciseKind.zuordnen, exerciseGenerators),
        isA<MatchGenerator>(),
      );
    });
  });

  group('attribution', () {
    late Exercise exercise;
    late List<(FormOption, FormOption)> right;
    setUp(() {
      exercise = build(vocare, _bundle);
      right = answerOf(exercise).pairs;
    });

    test('all pairs right: Good/Good', () {
      expect(attribute(vocare, exercise, MatchedPairs(right)), (
        word: Rating.good,
        grammar: Rating.good,
      ));
    });

    test('two German texts swapped: the word is known, the grammar not', () {
      final swapped = [
        (right[0].$1, right[1].$2),
        (right[1].$1, right[0].$2),
        right[2],
        right[3],
      ];
      expect(attribute(vocare, exercise, MatchedPairs(swapped)), (
        word: Rating.good,
        grammar: Rating.again,
      ));
    });

    test('a German text of another word blames the word only', () {
      final foreign = FormOption(
        text: 'anderes@${right[0].$1.formKey}',
        formKey: right[0].$1.formKey,
        lexemeId: 'verbs:dicere',
      );
      final wrong = [(right[0].$1, foreign), ...right.skip(1)];
      expect(attribute(vocare, exercise, MatchedPairs(wrong)), (
        word: Rating.again,
        grammar: Rating.good,
      ));
    });
  });

  group('widget', () {
    Future<List<MatchedPairs>> pump(
      WidgetTester tester,
      Exercise exercise, {
      String language = 'de',
      String? title,
    }) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final responses = <MatchedPairs>[];
      await tester.pumpWidget(
        wrapInApp(
          ExerciseMatchWidget(
            word: vocare,
            exercise: exercise,
            title: title,
            onResponse: responses.add,
          ),
          forcedLocale: Locale(language),
        ),
      );
      await tester.pumpAndSettle();
      return responses;
    }

    Future<void> tapNext(WidgetTester tester) async {
      final next = find.byKey(const Key('exercise.next.button'));
      await tester.scrollUntilVisible(
        next,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(next);
    }

    Future<void> pair(WidgetTester tester, int left, int right) async {
      await tester.tap(find.byKey(Key('exercise.match.left.$left')));
      await tester.pump();
      await tester.tap(find.byKey(Key('exercise.match.right.$right')));
      await tester.pump();
    }

    testWidgets('a given title replaces the standard one', (tester) async {
      await pump(tester, build(vocare, _bundle), title: 'Aufgabe 3 von 10');

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Aufgabe 3 von 10'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no title shows the standard title of the locale', (
      tester,
    ) async {
      await pump(tester, build(vocare, _bundle));

      final standard =
          (jsonDecode(
                File('assets/flutter_i18n/de.json').readAsStringSync(),
              )['exercise']['screen']['title']
              as String);
      expect(standard, isNotEmpty);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(standard)),
        findsOneWidget,
      );
    });

    testWidgets('right pairs say right and report the very options', (
      tester,
    ) async {
      final exercise = build(vocare, _bundle);
      final right = answerOf(exercise).pairs;
      final responses = await pump(tester, exercise);

      expect(find.byKey(const Key('exercise.check.button')), findsNothing);
      for (int i = 0; i < 4; i++) {
        await pair(tester, i, i);
      }
      await tester.tap(find.byKey(const Key('exercise.check.button')));
      await tester.pumpAndSettle();

      expect(find.text('Richtig'), findsOneWidget);
      await tapNext(tester);
      await tapNext(tester);
      expect(responses, hasLength(1));
      expect(attribute(vocare, exercise, responses.single), (
        word: Rating.good,
        grammar: Rating.good,
      ));
      for (final (latin, german) in right) {
        expect(
          responses.single.pairs.any(
            (p) => identical(p.$1, latin) && identical(p.$2, german),
          ),
          isTrue,
        );
      }
    });

    testWidgets('swapped pairs say wrong and name the right pairs', (
      tester,
    ) async {
      final exercise = build(vocare, _bundle);
      final right = answerOf(exercise).pairs;
      final responses = await pump(tester, exercise);

      await pair(tester, 0, 1);
      await pair(tester, 1, 0);
      await pair(tester, 2, 2);
      await pair(tester, 3, 3);
      await tester.tap(find.byKey(const Key('exercise.check.button')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('So heißt es: ${right[0].$1.text} = '),
        findsOneWidget,
      );
      final feedback = find.byKey(const Key('exercise.feedback'));
      expect(
        tester.widget<Text>(feedback).style!.color,
        Theme.of(tester.element(feedback)).textTheme.titleMedium!.color,
        reason: 'a wrong answer is named in the neutral text colour',
      );
      await tapNext(tester);
      expect(attribute(vocare, exercise, responses.single), (
        word: Rating.good,
        grammar: Rating.again,
      ));
    });

    Future<void> seenLine(WidgetTester tester, String text) async {
      await tester.scrollUntilVisible(
        find.text(text),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(text), findsOneWidget);
    }

    String labelOf(PracticeItem word, FormKey key) =>
        describeLabels([word.formLabels[word.formOrder.indexOf(key)]]);

    testWidgets('a wrong pairing labels every pair', (tester) async {
      final exercise = build(vocare, _bundle);
      final right = answerOf(exercise).pairs;
      await pump(tester, exercise);
      await pair(tester, 0, 1);
      await pair(tester, 1, 0);
      await pair(tester, 2, 2);
      await pair(tester, 3, 3);
      await tester.tap(find.byKey(const Key('exercise.check.button')));
      await tester.pumpAndSettle();
      for (final (latin, _) in right) {
        await seenLine(
          tester,
          '${latin.text} – ${labelOf(vocare, latin.formKey)}',
        );
      }
    });

    testWidgets('tapping a paired Latin form releases it', (tester) async {
      await pump(tester, build(vocare, _bundle));
      for (int i = 0; i < 4; i++) {
        await pair(tester, i, i);
      }
      expect(find.byKey(const Key('exercise.check.button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('exercise.match.left.0')));
      await tester.pump();
      expect(find.byKey(const Key('exercise.check.button')), findsNothing);
    });

    for (final language in ['de', 'en']) {
      testWidgets('shows $language text and no key', (tester) async {
        await pump(tester, build(vocare, _bundle), language: language);
        final keys = translationKeys(language);
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '');
        expect(texts, isNotEmpty);
        expect(texts.where(keys.contains), isEmpty);
      });
    }
  });

  test('de and en have the same exercise.match keys', () {
    Set<String> matchKeys(String l) => translationKeys(
      l,
    ).where((k) => k.startsWith('exercise.match.')).toSet();
    expect(matchKeys('de'), isNotEmpty);
    expect(matchKeys('de'), matchKeys('en'));
  });
}
