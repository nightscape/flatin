import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/exercise_interpreter.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/screens/exercise_sort_widget.dart';

import 'support/exercise_fakes.dart';
import 'support/grammar_exercise_harness.dart';
import 'support/word_classification_harness.dart';

const _perfect = ['ind.perf.akt', 'ind.plusq.akt', 'ind.fut2.akt'];
const _impfFut = ['ind.impf.akt', 'ind.fut.akt'];

// Finger travel is a physical size, so the bound is absolute, not a screen fraction.
const _maxDragDp = 280.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<PracticeItem> verbs;
  late PracticeItem vocare;
  setUpAll(() async {
    verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
  });

  SpecGenerator g(ExerciseKind kind) =>
      exerciseGenerators.singleWhere((g) => g.kind == kind);

  Exercise build(
    ExerciseKind kind,
    GrammarBundle bundle, {
    required List<String> unlocked,
    List<PracticeItem>? pool,
    int seed = 0,
  }) => g(kind).build(
    vocare,
    bundle,
    fakeExerciseContext(unlocked: unlocked.toSet(), pool: pool ?? [vocare]),
    Random(seed),
  );

  SortingAnswer answerOf(Exercise e) => e.answer as SortingAnswer;

  group('building', () {
    test('ankreuzen: the asked bundle is the first group', () {
      final e = build(
        ExerciseKind.ankreuzen,
        'ind.fut.akt',
        unlocked: _impfFut,
      );
      final answer = answerOf(e);
      expect(answer.tick, isTrue);
      expect(answer.groups, hasLength(2));
      expect(e.questionParams['group'], answer.groups.first);
      expect(answer.groups.first, contains('Futur'));
      for (final (o, group) in answer.forms) {
        expect(o.formKey.startsWith('ind.fut.akt'), group == 0);
      }
    });

    test('sortieren: one group per tense of the set, in set order', () {
      final e = build(
        ExerciseKind.sortieren,
        'ind.plusq.akt',
        unlocked: _perfect,
      );
      final answer = answerOf(e);
      expect(answer.tick, isFalse);
      expect(answer.groups, hasLength(3));
      expect(answer.forms.length, inInclusiveRange(9, 12));
      for (final (o, group) in answer.forms) {
        expect(o.formKey, startsWith(_perfect[group]));
      }
    });

    test('a locked bundle of the set builds nothing', () {
      expect(
        () => build(
          ExerciseKind.sortieren,
          'ind.perf.akt',
          unlocked: ['ind.perf.akt', 'ind.plusq.akt'],
        ),
        throwsA(isA<CannotBuild>()),
      );
    });

    test('a bundle outside every set builds nothing', () {
      expect(
        () => build(
          ExerciseKind.ankreuzen,
          'ind.praes.akt',
          unlocked: ['ind.praes.akt'],
        ),
        throwsA(isA<CannotBuild>()),
      );
    });

    test('forms come from up to four words of the pool, the asked one too', () {
      final pool = verbs.take(20).toList()..add(vocare);
      for (var seed = 0; seed < 10; seed++) {
        final e = build(
          ExerciseKind.sortieren,
          'ind.perf.akt',
          unlocked: _perfect,
          pool: pool,
          seed: seed,
        );
        final words = {for (final (o, _) in answerOf(e).forms) o.lexemeId};
        expect(words, contains(vocare.id));
        expect(words.length, inInclusiveRange(1, 4));
        final ctx = fakeExerciseContext(unlocked: _perfect.toSet(), pool: pool);
        expect(
          g(ExerciseKind.sortieren).objections(e, vocare, 'ind.perf.akt', ctx),
          isEmpty,
        );
      }
    });
  });

  group('attribution', () {
    test('all in their groups: Good/Good', () {
      final e = build(
        ExerciseKind.sortieren,
        'ind.perf.akt',
        unlocked: _perfect,
      );
      expect(attribute(vocare, e, rightSorting(answerOf(e))), (
        word: Rating.good,
        grammar: Rating.good,
      ));
    });

    test('one form in another group: the grammar is not known', () {
      final e = build(
        ExerciseKind.sortieren,
        'ind.perf.akt',
        unlocked: _perfect,
      );
      expect(attribute(vocare, e, wrongSorting(answerOf(e))), (
        word: Rating.good,
        grammar: Rating.again,
      ));
    });
  });

  group('widget', () {
    Future<List<SortedForms>> pump(
      WidgetTester tester,
      Exercise e, {
      PracticeItem? word,
      String language = 'de',
      Size size = const Size(390, 800),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final responses = <SortedForms>[];
      await tester.pumpWidget(
        wrapInApp(
          ExerciseSortWidget(
            word: word ?? vocare,
            exercise: e,
            onResponse: responses.add,
          ),
          forcedLocale: Locale(language),
        ),
      );
      await tester.pumpAndSettle();
      return responses;
    }

    Future<void> tap(WidgetTester tester, String key) async {
      final target = find.byKey(Key(key));
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    testWidgets('ticking exactly the asked forms is right', (tester) async {
      final e = build(
        ExerciseKind.ankreuzen,
        'ind.impf.akt',
        unlocked: _impfFut,
      );
      final responses = await pump(tester, e);
      expect(
        find.text('Kreuze alle Formen im ${answerOf(e).groups.first} an'),
        findsOneWidget,
      );
      for (final (i, (_, group)) in answerOf(e).forms.indexed) {
        if (group == 0) await tap(tester, 'exercise.sort.form.$i');
      }
      await tap(tester, 'exercise.check.button');
      expect(find.text('Richtig'), findsOneWidget);
      await tap(tester, 'exercise.next.button');
      expect(attribute(vocare, e, responses.single), (
        word: Rating.good,
        grammar: Rating.good,
      ));
    });

    testWidgets('a missed tick is wrong and named', (tester) async {
      final e = build(
        ExerciseKind.ankreuzen,
        'ind.impf.akt',
        unlocked: _impfFut,
      );
      final responses = await pump(tester, e);
      await tap(tester, 'exercise.check.button');
      final missed = answerOf(e).forms.firstWhere((f) => f.$2 == 0).$1.text;
      expect(find.textContaining('So heißt es: $missed'), findsOneWidget);
      await tap(tester, 'exercise.next.button');
      expect(attribute(vocare, e, responses.single).grammar, Rating.again);
    });

    Future<void> dragToGroup(WidgetTester tester, int form, int group) async {
      final from = tester.getCenter(
        find.byKey(Key('exercise.sort.form.$form')),
      );
      final to = tester.getCenter(
        find.byKey(Key('exercise.sort.group.$group')),
      );
      await tester.dragFrom(from, to - from);
      await tester.pumpAndSettle();
    }

    Finder formIn(int form, int group) => find.descendant(
      of: find.byKey(Key('exercise.sort.group.$group')),
      matching: find.byKey(Key('exercise.sort.form.$form')),
    );

    Exercise sortExercise() =>
        build(ExerciseKind.sortieren, 'ind.fut2.akt', unlocked: _perfect);

    testWidgets('dragging a form onto a box places it, another box moves it', (
      tester,
    ) async {
      final e = sortExercise();
      await pump(tester, e);
      final group = answerOf(e).forms.first.$2;
      final other = (group + 1) % 3;
      await dragToGroup(tester, 0, group);
      expect(formIn(0, group), findsOneWidget);
      await dragToGroup(tester, 0, other);
      expect(formIn(0, group), findsNothing);
      expect(formIn(0, other), findsOneWidget);
    });

    testWidgets('a form dropped outside every box returns to the pool', (
      tester,
    ) async {
      final e = sortExercise();
      await pump(tester, e);
      await dragToGroup(tester, 0, 0);
      expect(formIn(0, 0), findsOneWidget);
      final from = tester.getCenter(
        find.byKey(const Key('exercise.sort.form.0')),
      );
      await tester.dragFrom(from, const Offset(0, -150));
      await tester.pumpAndSettle();
      for (var g = 0; g < 3; g++) {
        expect(formIn(0, g), findsNothing);
      }
      expect(find.byKey(const Key('exercise.sort.form.0')), findsOneWidget);
    });

    testWidgets('sorting checks once every form has a group', (tester) async {
      final e = sortExercise();
      final forms = answerOf(e).forms;
      final responses = await pump(tester, e);
      for (final (i, (_, group)) in forms.indexed) {
        expect(find.byKey(const Key('exercise.check.button')), findsNothing);
        await dragToGroup(tester, i, group);
      }
      await tap(tester, 'exercise.check.button');
      expect(find.text('Richtig'), findsOneWidget);
      await tap(tester, 'exercise.next.button');
      expect(responses.single.groupOf, {for (final (o, g) in forms) o: g});
    });

    testWidgets('a wrong sorting is named after the check', (tester) async {
      final e = sortExercise();
      final forms = answerOf(e).forms;
      final responses = await pump(tester, e);
      for (final (i, (_, group)) in forms.indexed) {
        await dragToGroup(tester, i, i == 0 ? (group + 1) % 3 : group);
      }
      await tap(tester, 'exercise.check.button');
      expect(
        find.textContaining('So heißt es: ${forms.first.$1.text}'),
        findsOneWidget,
      );
      await tap(tester, 'exercise.next.button');
      expect(attribute(vocare, e, responses.single).grammar, Rating.again);
    });

    testWidgets('360x640 with 12 forms: all on screen, boxes close', (
      tester,
    ) async {
      Exercise twelve() {
        for (var seed = 0; seed < 50; seed++) {
          final e = build(
            ExerciseKind.sortieren,
            'ind.perf.akt',
            unlocked: _perfect,
            pool: verbs.take(20).toList()..add(vocare),
            seed: seed,
          );
          if (answerOf(e).forms.length == 12) return e;
        }
        throw StateError('no exercise with 12 forms');
      }

      final e = twelve();
      await pump(tester, e, size: const Size(360, 640));
      final screen = Offset.zero & const Size(360, 640);
      final boxes = [
        for (var g = 0; g < 3; g++)
          tester.getRect(find.byKey(Key('exercise.sort.group.$g'))),
      ];
      var farthest = 0.0;
      for (var i = 0; i < 12; i++) {
        final rect = tester.getRect(find.byKey(Key('exercise.sort.form.$i')));
        expect(
          screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
          isTrue,
        );
        final nearest = boxes
            .map((b) => (b.center - rect.center).distance)
            .reduce(min);
        farthest = max(farthest, nearest);
      }
      for (final b in boxes) {
        expect(
          screen.contains(b.topLeft) && screen.contains(b.bottomRight),
          isTrue,
        );
      }
      expect(
        farthest,
        lessThanOrEqualTo(_maxDragDp),
        reason: 'farthest form-to-box drag $farthest dp, bound $_maxDragDp dp',
      );
    });

    testWidgets('forms and boxes have semantics labels', (tester) async {
      final handle = tester.ensureSemantics();
      final e = sortExercise();
      await pump(tester, e);
      for (final (i, (option, _)) in answerOf(e).forms.indexed) {
        expect(
          tester.getSemantics(find.byKey(Key('exercise.sort.form.$i'))).label,
          option.text,
        );
      }
      for (final (g, name) in answerOf(e).groups.indexed) {
        expect(
          tester.getSemantics(find.byKey(Key('exercise.sort.group.$g'))).label,
          contains(name),
        );
      }
      handle.dispose();
    });

    for (final language in ['de', 'en']) {
      testWidgets('group names are in the UI language ($language)', (
        tester,
      ) async {
        final items = await loadPracticeItems(
          'lib/data/latin_verbs.yaml',
          language: language,
        );
        final word = items.singleWhere((i) => i.id == 'verbs:vocare');
        for (final (kind, bundle, unlocked) in [
          (ExerciseKind.ankreuzen, 'ind.fut.akt', _impfFut),
          (ExerciseKind.sortieren, 'ind.perf.akt', _perfect),
        ]) {
          final e = g(kind).build(
            word,
            bundle,
            fakeExerciseContext(unlocked: unlocked.toSet(), pool: [word]),
            Random(0),
          );
          await pump(tester, e, word: word, language: language);
          final text = [
            for (final t in tester.widgetList<Text>(find.byType(Text)))
              t.data ?? '',
          ].join(' ');
          const german = ['Indikativ', 'Futur I', 'Perfekt', 'Aktiv'];
          for (final name in answerOf(
            e,
          ).groups.take(answerOf(e).tick ? 1 : 3)) {
            expect(text, contains(name));
          }
          expect(
            german.any(text.contains),
            language == 'de',
            reason: '$kind in $language',
          );
        }
      });
    }
  });
}
