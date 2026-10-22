import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_cube.dart';
import 'package:latin_practice/data/exercise_interpreter.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

import 'support/exercise_invariants.dart';

SpecGenerator _spec(ExerciseKind kind) =>
    specGenerators.singleWhere((g) => g.kind == kind);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PracticeItem vocare;
  late PracticeItem puella;
  late PracticeItem rosa;
  late PracticeItem tartarus;
  late PracticeItem manus;
  late GermanForms german;
  late GermanForms nounGerman;
  setUpAll(() async {
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
    final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
    puella = nouns.singleWhere((i) => i.lemma.startsWith('puella'));
    rosa = nouns.singleWhere((i) => i.id == 'nouns:rosa');
    tartarus = nouns.singleWhere((i) => i.id == 'nouns:tartarus');
    manus = nouns.singleWhere((i) => i.id == 'nouns:manus');
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    nounGerman = await container.read(germanFormsProvider.future);
    container.dispose();
    german = GrammarGermanForms(
      File('lib/data/german_verbs.yaml').readAsStringSync(),
      parseGrammarFiles({
        for (final path in [
          'lib/data/latin_nouns.yaml',
          'lib/data/latin_verbs.yaml',
        ])
          path: File(path).readAsStringSync(),
      }).singleWhere((f) => f.dataFileId == 'verbs'),
    );
  });

  ExerciseContext ctx(
    PracticeItem word,
    Set<GrammarBundle> unlocked, {
    GermanForms? forms,
  }) => ExerciseContext(
    unlocked: unlocked,
    pool: [word],
    german: forms ?? german,
  );

  Exercise build(
    ExerciseKind kind,
    PracticeItem word,
    GrammarBundle bundle, {
    int seed = 0,
    GermanForms? forms,
  }) => _spec(
    kind,
  ).build(word, bundle, ctx(word, {bundle}, forms: forms), Random(seed));

  void expectValid(ExerciseKind kind, PracticeItem word, GrammarBundle bundle) {
    for (var seed = 0; seed < 10; seed++) {
      final e = build(kind, word, bundle, seed: seed);
      expect(
        violations(e, _spec(kind).spec, word, bundle, ctx(word, {bundle})),
        isEmpty,
      );
    }
  }

  group('A2 latDeWahl from its spec', () {
    test('shows a Latin form and offers the German texts of neighbours', () {
      final e = build(ExerciseKind.latDeWahl, vocare, 'ind.praes.akt');
      final answer = e.answer as ChoiceAnswer;
      final target = answer.right.formKey;
      expect(e.questionParams, {
        'form': vocare.forms[vocare.formOrder.indexOf(target)],
        'word': vocare.lemma,
      });
      expect(answer.right.text, german.accepted(vocare, target).first);
      expect(answer.options, hasLength(4));
      expectValid(ExerciseKind.latDeWahl, vocare, 'ind.praes.akt');
    });

    test('frames every option of a subjunctive form', () {
      for (var seed = 0; seed < 10; seed++) {
        final e = build(
          ExerciseKind.latDeWahl,
          vocare,
          'konj.impf.akt',
          seed: seed,
        );
        final options = (e.answer as ChoiceAnswer).options;
        expect(options.map((o) => o.text), everyElement(startsWith('Ich ')));
      }
      expectValid(ExerciseKind.latDeWahl, vocare, 'konj.impf.akt');
    });

    test(
      'offers forms that read the same in Latin when their German differs',
      () {
        String latin(FormOption o) =>
            rosa.forms[rosa.formOrder.indexOf(o.formKey)];
        final options =
            Iterable.generate(
                  100,
                  (seed) =>
                      build(
                            ExerciseKind.latDeWahl,
                            rosa,
                            rosa.type,
                            seed: seed,
                            forms: nounGerman,
                          ).answer
                          as ChoiceAnswer,
                )
                .firstWhere(
                  (a) =>
                      a.right.formKey == 'nom.sg' &&
                      a.options.map(latin).toSet().length < 4,
                )
                .options;
        expect(options.map((o) => o.text).toSet(), hasLength(4));
      },
    );

    test('reads the shown form with its macrons: rosa may offer rosā', () {
      final wrongKeys = {
        for (var seed = 0; seed < 100; seed++)
          if (build(
                ExerciseKind.latDeWahl,
                rosa,
                rosa.type,
                seed: seed,
                forms: nounGerman,
              ).answer
              case ChoiceAnswer(:final options, :final right)
              when right.formKey == 'nom.sg')
            for (final o in options)
              if (o != right) o.formKey,
      };
      expect(wrongKeys, contains('abl.sg'));
    });

    test('cannot build without German forms', () {
      expect(
        () => build(
          ExerciseKind.latDeWahl,
          vocare,
          'ind.praes.akt',
          forms: const NoForms(),
        ),
        throwsA(isA<CannotBuild>()),
      );
    });

    test('the same seed gives the same exercise', () {
      String shown(Exercise e) =>
          '${e.questionParams} ${(e.answer as ChoiceAnswer).options.map((o) => o.text)}';
      expect(
        shown(build(ExerciseKind.latDeWahl, vocare, 'ind.perf.akt', seed: 7)),
        shown(build(ExerciseKind.latDeWahl, vocare, 'ind.perf.akt', seed: 7)),
      );
    });
  });

  group('A3 deLatWahl from its spec', () {
    test('shows the German text and offers Latin forms and wrong endings', () {
      final e = build(ExerciseKind.deLatWahl, vocare, 'ind.praes.akt');
      final answer = e.answer as ChoiceAnswer;
      expect(e.questionParams, {
        'german': german.accepted(vocare, answer.right.formKey).first,
        'word': vocare.lemma,
      });
      expect(answer.options, hasLength(4));
      expectValid(ExerciseKind.deLatWahl, vocare, 'ind.praes.akt');
    });

    test('offers the ending of another declension as a wrong option', () {
      final wrong = {
        for (var seed = 0; seed < 100; seed++)
          ...(build(
                    ExerciseKind.deLatWahl,
                    rosa,
                    rosa.type,
                    seed: seed,
                    forms: nounGerman,
                  ).answer
                  as ChoiceAnswer)
              .options
              .where((o) => o.builtWrongBy != null),
      };
      expect(wrong, isNotEmpty);
    });

    test('a cell without German text clashes with nothing', () {
      final cube = Cube(ctx(tartarus, {tartarus.type}, forms: nounGerman));
      final cells = cube.cellsOf(tartarus).toList();
      final uncovered = cells.where((c) => !cube.view(View.german).covers(c));
      expect(uncovered, isNotEmpty);
      for (final c in uncovered) {
        expect(cube.clash(View.german, cells.first, c), isFalse);
      }
    });

    test('takes wrong options from forms the German text does not cover', () {
      final bundles = {
        for (final key in tartarus.formOrder) bundleOf(tartarus, key),
      };
      for (final bundle in bundles) {
        for (var seed = 0; seed < 5; seed++) {
          _spec(ExerciseKind.deLatWahl).build(
            tartarus,
            bundle,
            ctx(tartarus, bundles, forms: nounGerman),
            Random(seed),
          );
        }
      }
    });

    test('cannot build without German forms', () {
      expect(
        () => build(
          ExerciseKind.deLatWahl,
          vocare,
          'ind.praes.akt',
          forms: const NoForms(),
        ),
        throwsA(isA<CannotBuild>()),
      );
    });
  });

  group('A7 deLatTippen from its spec', () {
    test('accepts the forms whose German reads the same, framed or not', () {
      final e = build(ExerciseKind.deLatTippen, vocare, 'ind.praes.akt');
      final answer = e.answer as TypedAnswer;
      expect(e.questionParams['german'], 'du rufst');
      expect(answer.expected.formKey, 'ind.praes.akt.2.sg');
      // The subjunctive reads "Ich frage, ob du rufst", so vocēs is wrong.
      expect(answer.accepted, ['vocās']);
      expectValid(ExerciseKind.deLatTippen, vocare, 'ind.praes.akt');
    });

    test('reads a noun with German forms', () {
      for (var seed = 0; seed < 10; seed++) {
        final e = build(
          ExerciseKind.deLatTippen,
          rosa,
          rosa.type,
          seed: seed,
          forms: nounGerman,
        );
        expect(
          violations(
            e,
            _spec(ExerciseKind.deLatTippen).spec,
            rosa,
            rosa.type,
            ctx(rosa, {rosa.type}, forms: nounGerman),
          ),
          isEmpty,
        );
      }
    });
  });

  group('A6 formBilden from its spec', () {
    test('names one form by its label and expects its Latin text', () {
      final e = build(ExerciseKind.formBilden, vocare, 'ind.praes.akt');
      final answer = e.answer as TypedAnswer;
      final index = vocare.formOrder.indexOf(answer.expected.formKey);
      expect(e.questionParams, {
        'label': describeLabels([vocare.formLabels[index]]),
        'word': vocare.lemma,
      });
      expect(answer.accepted, vocare.acceptedForms[index]);
      expectValid(ExerciseKind.formBilden, vocare, 'ind.praes.akt');
    });
  });

  group('A4 irrlaeufer from its spec', () {
    test('the right option is the only one alone on an axis', () {
      expectValid(ExerciseKind.irrlaeufer, vocare, 'ind.praes.akt');
      expectValid(ExerciseKind.irrlaeufer, puella, puella.type);
    });

    test('offers rosa and rosā side by side', () {
      final texts = [
        for (var seed = 0; seed < 100; seed++)
          (build(ExerciseKind.irrlaeufer, rosa, rosa.type, seed: seed).answer
                  as ChoiceAnswer)
              .options
              .map((o) => o.text)
              .toSet(),
      ];
      expect(texts, contains(containsAll(['rosa', 'rosā'])));
    });

    test('two options with the same text fail the assertion', () {
      FormOption option(FormKey key) =>
          FormOption(text: 'rosae', formKey: key, lexemeId: rosa.id);
      final right = option('gen.sg');
      expect(
        () => ChoiceAnswer([right, option('dat.sg')], right),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('A8 umformen from its spec', () {
    test('changes one axis of a shown form', () {
      final e = build(ExerciseKind.umformen, vocare, 'ind.praes.pass');
      expect(e.questionParams.keys, {'start', 'word', 'changes'});
      expect(e.questionParams['changes'], isNot(contains('→')));
      expectValid(ExerciseKind.umformen, vocare, 'ind.praes.pass');
    });

    test('accepts the form of every reading of an ambiguous start (M3)', () {
      final e =
          Iterable.generate(
            200,
            (seed) =>
                build(ExerciseKind.umformen, puella, puella.type, seed: seed),
          ).firstWhere(
            (e) =>
                e.questionParams['start'] == 'puellae' &&
                e.questionParams['changes'] == 'Plural',
          );
      // Gen. and Dat. Sg. both read puellae.
      expect(
        (e.answer as TypedAnswer).accepted,
        containsAll(['puellārum', 'puellīs']),
      );
    });

    TypedAnswer answerFrom(PracticeItem word, String start, String changes) =>
        Iterable.generate(
                  400,
                  (seed) =>
                      build(ExerciseKind.umformen, word, word.type, seed: seed),
                )
                .firstWhere(
                  (e) =>
                      e.questionParams['start'] == start &&
                      e.questionParams['changes'] == changes,
                )
                .answer
            as TypedAnswer;

    test('reads the shown start with its macrons (M3)', () {
      final rosaPlural = answerFrom(rosa, 'rosa', 'Plural').accepted;
      expect(rosaPlural, contains('rosae'));
      expect(rosaPlural, isNot(contains('rosīs')));
      // Nom. Sg. manus is no reading of manūs, so its plural manūs is wrong.
      expect(
        answerFrom(manus, 'manūs', 'Plural').accepted,
        isNot(contains('manūs')),
      );
    });
  });
}
