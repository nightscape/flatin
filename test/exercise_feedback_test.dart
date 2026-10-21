import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/diagnosis.dart';
import 'package:latin_practice/data/exercise_feedback.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PracticeItem vocare;
  late PracticeItem noun;
  setUpAll(() async {
    vocare = (await loadPracticeItems(
      'lib/data/latin_verbs.yaml',
    )).singleWhere((i) => i.id == 'verbs:vocare');
    noun = (await loadPracticeItems(
      'lib/data/latin_nouns.yaml',
    )).singleWhere((i) => i.id == 'nouns:dominus');
  });

  FormOption option(
    PracticeItem word,
    FormKey key, {
    Diagnosis? builtWrongBy,
  }) => FormOption(
    text: word.forms[word.formOrder.indexOf(key)],
    formKey: key,
    lexemeId: word.id,
    builtWrongBy: builtWrongBy,
  );

  ChoiceAnswer choice(PracticeItem word, List<FormKey> others, FormKey right) {
    final r = option(word, right);
    return ChoiceAnswer([...others.map((k) => option(word, k)), r], r);
  }

  Exercise exercise(ExerciseKind kind, ExerciseAnswer answer) => Exercise(
    wordCardId: 'verbs:vocare',
    grammarCardId: GrammarCardId('verbs', 'ind.praes.akt'),
    kind: kind,
    questionKey: 'exercise.screen.sampleQuestion',
    answer: answer,
  );

  List<String> keysOf(List<dynamic> lines) => [for (final l in lines) l.key];

  group('oddAxes', () {
    final impf = [
      'ind.impf.akt.1.sg',
      'ind.impf.akt.2.sg',
      'ind.impf.akt.3.sg',
    ];
    final examples = <(String, List<FormKey>, FormKey, List<String>)>[
      ('tempus', impf, 'ind.praes.akt.2.sg', ['tempus']),
      (
        'modus',
        ['konj.praes.akt.1.sg', 'konj.praes.akt.2.sg', 'konj.praes.akt.3.sg'],
        'ind.praes.akt.3.sg',
        ['modus'],
      ),
      ('two axes', impf, 'ind.praes.pass.2.sg', ['tempus', 'genus_verbi']),
    ];
    for (final (name, others, right, expected) in examples) {
      test(name, () {
        expect(oddAxes(vocare, choice(vocare, others, right)), expected);
      });
    }

    test('throws when the others share no axis the right option lacks', () {
      final answer = choice(vocare, [
        'ind.praes.akt.1.sg',
        'ind.impf.akt.2.sg',
        'ind.fut.akt.1.pl',
      ], 'ind.perf.akt.3.sg');
      expect(() => oddAxes(vocare, answer), throwsStateError);
    });

    test('a noun names its numerus', () {
      final answer = choice(noun, ['nom.sg', 'gen.sg', 'dat.sg'], 'akk.pl');
      expect(oddAxes(noun, answer), ['numerus']);
    });
  });

  group('feedbackLines', () {
    final others = [
      'ind.impf.akt.1.sg',
      'ind.impf.akt.2.sg',
      'ind.impf.akt.3.sg',
    ];
    const right = 'ind.praes.akt.2.sg';

    test('a wrong pick marks one right and one chosen option', () {
      final answer = choice(vocare, others, right);
      final lines = feedbackLines(
        vocare,
        exercise(ExerciseKind.irrlaeufer, answer),
        ChosenOption(answer.options.first),
      );
      expect(keysOf(lines), [
        'exercise.feedback.optionChosen',
        'exercise.feedback.option',
        'exercise.feedback.option',
        'exercise.feedback.optionRight',
        'exercise.feedback.oddAxes',
      ]);
      expect(lines.first.params, {
        'form': answer.options.first.text,
        'label': 'Imperfekt: 1. Person Singular',
      });
      expect(lines.last.params, {'values': 'Imperfekt'});
    });

    test('the right pick is marked right and chosen once', () {
      final answer = choice(vocare, others, right);
      final lines = feedbackLines(
        vocare,
        exercise(ExerciseKind.irrlaeufer, answer),
        ChosenOption(answer.right),
      );
      expect(
        keysOf(lines).where((k) => k == 'exercise.feedback.optionRightChosen'),
        hasLength(1),
      );
      expect(keysOf(lines).where((k) => k.endsWith('optionChosen')), isEmpty);
    });

    test('a built-wrong option is labelled with its type phrase', () {
      final r = option(vocare, 'ind.praes.akt.1.sg');
      final wrong = FormOption(
        text: 'vocēo',
        formKey: r.formKey,
        lexemeId: vocare.id,
        builtWrongBy: const EndingOfOtherType(['E-Konjugation']),
      );
      final lines = feedbackLines(
        vocare,
        exercise(ExerciseKind.deLatWahl, ChoiceAnswer([r, wrong], r)),
        ChosenOption(wrong),
      );
      expect(lines.last.params['label'], 'Endung der E-Konjugation');
    });

    test('an option of another word fails the assertion', () {
      final r = option(vocare, 'ind.praes.akt.1.sg');
      final foreign = FormOption(
        text: 'x',
        formKey: r.formKey,
        lexemeId: 'verbs:other',
      );
      expect(
        () => feedbackLines(
          vocare,
          exercise(ExerciseKind.latDeWahl, ChoiceAnswer([r, foreign], r)),
          ChosenOption(r),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    group('typed', () {
      FormOption expected() => option(vocare, 'ind.praes.akt.1.sg');
      List<String> run(String text) => keysOf(
        feedbackLines(
          vocare,
          exercise(
            ExerciseKind.formBilden,
            TypedAnswer(expected(), vocare.acceptedForms[0]),
          ),
          TypedText(text),
        ),
      );

      test('right gives the target line only', () {
        expect(run(expected().text), ['exercise.feedback.optionRight']);
      });

      test('wrong adds the diagnosis', () {
        expect(run('vocās'), [
          'exercise.feedback.optionRight',
          'explain.diag.otherForm',
        ]);
      });

      test('empty gives the target line only', () {
        expect(run('  '), ['exercise.feedback.optionRight']);
      });
    });

    test('matching gives one plain line per pair', () {
      final pairs = [
        for (final k in ['ind.praes.akt.1.sg', 'ind.praes.akt.2.sg'])
          (option(vocare, k), option(vocare, k)),
      ];
      final lines = feedbackLines(
        vocare,
        exercise(ExerciseKind.zuordnen, MatchingAnswer(pairs)),
        MatchedPairs(pairs),
      );
      expect(keysOf(lines), [
        'exercise.feedback.option',
        'exercise.feedback.option',
      ]);
    });
  });
}
