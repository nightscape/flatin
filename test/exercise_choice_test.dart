import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_choice.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/exercise_fakes.dart';

/// A [Random] whose every `nextDouble` is [value]; `nextInt` is 0.
class _Fixed implements Random {
  const _Fixed(this.value);
  final double value;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

/// A generator of [kind] that always builds, or always throws [CannotBuild].
class _Stub implements ExerciseGenerator {
  const _Stub(this.kind, {required this.fits});

  @override
  final ExerciseKind kind;
  final bool fits;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    if (!fits) throw CannotBuild('$kind never fits');
    return Exercise(
      wordCardId: word.id,
      grammarCardId: GrammarCardId(word.dataFileId, bundle),
      kind: kind,
      questionKey: 'exercise.screen.sampleQuestion',
      answer: TypedAnswer(
        FormOption(
          text: word.forms.first,
          formKey: word.formOrder.first,
          lexemeId: word.id,
        ),
        word.acceptedForms.first,
      ),
    );
  }
}

void main() {
  group('classFor', () {
    test('below 2 days of stability every draw recognises', () {
      expect(classFor(0, const _Fixed(0)), KindClass.recognition);
      expect(classFor(1.999, const _Fixed(0)), KindClass.recognition);
    });

    test('from 2 days on, half the draws build', () {
      expect(classFor(2, const _Fixed(0.499)), KindClass.building);
      expect(classFor(2, const _Fixed(0.5)), KindClass.recognition);
      expect(classFor(6.999, const _Fixed(0.499)), KindClass.building);
      expect(classFor(6.999, const _Fixed(0.5)), KindClass.recognition);
    });

    test('from 7 days on every draw builds', () {
      expect(classFor(7, const _Fixed(0.999)), KindClass.building);
      expect(classFor(365, const _Fixed(0.999)), KindClass.building);
    });
  });

  test('every kind has a class, and the design table sorts them', () {
    expect(
      {
        for (final k in ExerciseKind.values)
          if (classOf(k) == KindClass.recognition) k,
      },
      {
        ExerciseKind.bestimmen,
        ExerciseKind.latDeWahl,
        ExerciseKind.deLatWahl,
        ExerciseKind.irrlaeufer,
        ExerciseKind.zuordnen,
        ExerciseKind.ankreuzen,
        ExerciseKind.sortieren,
      },
    );
  });

  group('buildExercise', () {
    late PracticeItem vocare;
    late GrammarBundle bundle;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      vocare = (await loadPracticeItems(
        'lib/data/latin_verbs.yaml',
      )).singleWhere((i) => i.id == 'verbs:vocare');
      bundle = bundleOf(vocare, 'ind.praes.akt.3.sg');
    });

    Exercise build(double stability, List<ExerciseGenerator> registry) =>
        buildExercise(
          vocare,
          bundle,
          fakeExerciseContext(unlocked: {bundle}, pool: [vocare]),
          stability,
          Random(1),
          registry: registry,
        );

    test('a kind that cannot build is skipped for another of its class', () {
      for (var seed = 0; seed < 20; seed++) {
        expect(
          buildExercise(
            vocare,
            bundle,
            fakeExerciseContext(unlocked: {bundle}, pool: [vocare]),
            0,
            Random(seed),
            registry: const [
              _Stub(ExerciseKind.irrlaeufer, fits: false),
              _Stub(ExerciseKind.zuordnen, fits: true),
              _Stub(ExerciseKind.formBilden, fits: true),
            ],
          ).kind,
          ExerciseKind.zuordnen,
        );
      }
    });

    test('when no kind of the class fits, the other class builds', () {
      expect(
        build(0, const [
          _Stub(ExerciseKind.irrlaeufer, fits: false),
          _Stub(ExerciseKind.formBilden, fits: true),
        ]).kind,
        ExerciseKind.formBilden,
      );
      expect(
        build(10, const [
          _Stub(ExerciseKind.zuordnen, fits: true),
          _Stub(ExerciseKind.umformen, fits: false),
        ]).kind,
        ExerciseKind.zuordnen,
      );
    });

    test('when no kind fits, the assertion names the word and the bundle', () {
      expect(
        () => build(0, const [
          _Stub(ExerciseKind.irrlaeufer, fits: false),
          _Stub(ExerciseKind.umformen, fits: false),
        ]),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            allOf(contains('verbs:vocare'), contains(bundle)),
          ),
        ),
      );
    });
  });

  group('buildExercise avoid', () {
    late PracticeItem vocare;
    late GrammarBundle bundle;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      vocare = (await loadPracticeItems(
        'lib/data/latin_verbs.yaml',
      )).singleWhere((i) => i.id == 'verbs:vocare');
      bundle = bundleOf(vocare, 'ind.praes.akt.3.sg');
    });

    ExerciseKind build(Set<ExerciseKind> avoid, List<_Stub> registry) =>
        buildExercise(
          vocare,
          bundle,
          fakeExerciseContext(unlocked: {bundle}, pool: [vocare]),
          0,
          Random(1),
          registry: registry,
          avoid: avoid,
        ).kind;

    test('an avoided kind is tried after every other kind', () {
      const registry = [
        _Stub(ExerciseKind.zuordnen, fits: true),
        _Stub(ExerciseKind.formBilden, fits: true),
      ];
      expect(build({}, registry), ExerciseKind.zuordnen);
      expect(build({ExerciseKind.zuordnen}, registry), ExerciseKind.formBilden);
    });

    test('an avoided kind still builds when no other kind fits', () {
      expect(
        build(
          {ExerciseKind.zuordnen},
          const [
            _Stub(ExerciseKind.zuordnen, fits: true),
            _Stub(ExerciseKind.formBilden, fits: false),
          ],
        ),
        ExerciseKind.zuordnen,
      );
    });
  });
}
