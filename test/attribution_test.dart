import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/diagnosis.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';

const _bundle = 'ind.praes.akt';
const _key = 'ind.praes.akt.1.sg';

FormOption _option(PracticeItem item, FormKey key, {Diagnosis? wrongBy}) =>
    FormOption(
      text: '${item.lemma}@$key',
      formKey: key,
      lexemeId: item.id,
      builtWrongBy: wrongBy,
    );

Exercise _exercise(PracticeItem item, ExerciseAnswer answer) => Exercise(
  wordCardId: item.id,
  grammarCardId: GrammarCardId(item.dataFileId, _bundle),
  kind: ExerciseKind.formBilden,
  questionKey: 'q',
  answer: answer,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PracticeItem vocare;
  late PracticeItem dicere;
  setUpAll(() async {
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
    dicere = verbs.singleWhere((i) => i.id == 'verbs:dicere');
  });

  Attribution typed(PracticeItem item, FormKey key, String text) {
    final shown = item.forms[item.formOrder.indexOf(key)];
    final answer = TypedAnswer(
      FormOption(text: shown, formKey: key, lexemeId: item.id),
      [shown],
    );
    return attribute(item, _exercise(item, answer), TypedText(text));
  }

  group('typed answers follow the diagnosis table', () {
    test('correct: Good/Good', () {
      expect(typed(vocare, _key, 'vocō'), (
        word: Rating.good,
        grammar: Rating.good,
      ));
    });

    test('a spelling without quantity marks is correct', () {
      expect(typed(vocare, _key, 'voco').grammar, Rating.good);
    });

    test('OtherFormOfWord: word Good, grammar Again', () {
      expect(typed(vocare, _key, 'vocāmus'), (
        word: Rating.good,
        grammar: Rating.again,
      ));
    });

    test('EndingOfOtherType: word Good, grammar Again', () {
      expect(diagnose(vocare, _key, 'vocaō'), isA<EndingOfOtherType>());
      expect(typed(vocare, _key, 'vocaō'), (
        word: Rating.good,
        grammar: Rating.again,
      ));
    });

    test('WrongStem: word Again, grammar Good', () {
      expect(typed(vocare, _key, 'amō'), (
        word: Rating.again,
        grammar: Rating.good,
      ));
    });

    test('RegularInsteadOfIrregular: word Again, grammar Good', () {
      expect(typed(dicere, 'imp.praes.akt.2.sg', 'dice'), (
        word: Rating.again,
        grammar: Rating.good,
      ));
    });

    test('NoMatch: Again/Again', () {
      expect(typed(vocare, _key, 'xyz'), (
        word: Rating.again,
        grammar: Rating.again,
      ));
    });
  });

  group('choices follow the option the learner picked', () {
    FormOption right() => _option(vocare, _key);

    Attribution choose(FormOption chosen) {
      final correct = right();
      final options = [correct, if (!identical(chosen, correct)) chosen];
      return attribute(
        vocare,
        _exercise(vocare, ChoiceAnswer(options, correct)),
        ChosenOption(chosen),
      );
    }

    test('the right option: Good/Good', () {
      final correct = right();
      expect(
        attribute(
          vocare,
          _exercise(vocare, ChoiceAnswer([correct], correct)),
          ChosenOption(correct),
        ),
        (word: Rating.good, grammar: Rating.good),
      );
    });

    test('another feature of the word: word Good, grammar Again', () {
      expect(choose(_option(vocare, 'ind.praes.akt.1.pl')), (
        word: Rating.good,
        grammar: Rating.again,
      ));
    });

    test('another lexeme: word Again, grammar null', () {
      final other = FormOption(
        text: 'dare@$_key',
        formKey: _key,
        lexemeId: 'verbs:dare',
      );
      expect(choose(other), (word: Rating.again, grammar: null));
    });

    test('an option built wrong follows its diagnosis', () {
      final wrongStem = FormOption(
        text: 'amō',
        formKey: _key,
        lexemeId: vocare.id,
        builtWrongBy: const WrongStem('am', 'praes'),
      );
      expect(choose(wrongStem), (word: Rating.again, grammar: Rating.good));
    });
  });

  group('matching', () {
    late FormOption a, b, aDe, bDe;
    late Exercise exercise;
    setUp(() {
      a = _option(vocare, _key);
      b = _option(vocare, 'ind.praes.akt.1.pl');
      aDe = _option(vocare, _key);
      bDe = _option(vocare, 'ind.praes.akt.1.pl');
      exercise = _exercise(vocare, MatchingAnswer([(a, aDe), (b, bDe)]));
    });

    test('all pairs right: Good/Good', () {
      expect(attribute(vocare, exercise, MatchedPairs([(a, aDe), (b, bDe)])), (
        word: Rating.good,
        grammar: Rating.good,
      ));
    });

    test('crossed pairs: grammar Again', () {
      expect(attribute(vocare, exercise, MatchedPairs([(a, bDe), (b, aDe)])), (
        word: Rating.good,
        grammar: Rating.again,
      ));
    });
  });

  test('a response of the wrong shape is a programming error', () {
    final correct = _option(vocare, _key);
    expect(
      () => attribute(
        vocare,
        _exercise(vocare, ChoiceAnswer([correct], correct)),
        const TypedText('vocō'),
      ),
      throwsArgumentError,
    );
  });

  group('attributeParadigm', () {
    const good = (word: Rating.good, grammar: Rating.good);
    const grammarWrong = (word: Rating.good, grammar: Rating.again);
    const wordWrong = (word: Rating.again, grammar: Rating.good);

    test('each bundle gets the worst rating of its rows', () {
      final result = attributeParadigm([
        (bundle: 'a', rating: good),
        (bundle: 'a', rating: grammarWrong),
        (bundle: 'b', rating: good),
      ]);
      expect(result.grammar, {'a': Rating.again, 'b': Rating.good});
      expect(result.word, Rating.good);
    });

    test('the word gets the worst rating of the rows that blame it', () {
      final result = attributeParadigm([
        (bundle: 'a', rating: good),
        (bundle: 'b', rating: wordWrong),
        (bundle: 'b', rating: grammarWrong),
      ]);
      expect(result.word, Rating.again);
      expect(result.grammar, {'a': Rating.good, 'b': Rating.again});
    });

    test('a bundle whose rows say nothing about grammar is absent', () {
      final result = attributeParadigm([
        (bundle: 'a', rating: (word: Rating.again, grammar: null)),
      ]);
      expect(result.grammar, isEmpty);
      expect(result.word, Rating.again);
    });
  });

  group('isRight', () {
    test('only Good/Good is right', () {
      expect(isRight((word: Rating.good, grammar: Rating.good)), isTrue);
      expect(isRight((word: Rating.good, grammar: Rating.again)), isFalse);
      expect(isRight((word: Rating.again, grammar: Rating.good)), isFalse);
      expect(isRight((word: Rating.good, grammar: null)), isFalse);
    });

    test('agrees with attribute on a typed answer', () {
      expect(isRight(typed(vocare, _key, 'vocō')), isTrue);
      expect(isRight(typed(vocare, _key, 'vocāmus')), isFalse);
    });
  });
}
