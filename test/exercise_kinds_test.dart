import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_cube.dart';
import 'package:latin_practice/data/exercise_interpreter.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/exercise_spec.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

import 'support/exercise_fakes.dart';
import 'support/exercise_invariants.dart';

/// German texts `g@<key>`; [uncovered] keys have none, and every key accepts
/// [alsoAccepts] besides its own text.
class _ScriptedGerman implements GermanForms {
  const _ScriptedGerman({this.uncovered = const {}, this.alsoAccepts});

  final Set<FormKey> uncovered;
  final FormKey? alsoAccepts;

  @override
  bool covers(PracticeItem item, FormKey key) => !uncovered.contains(key);

  @override
  String render(PracticeItem item, FormKey key) => 'g@$key';

  @override
  List<String> accepted(PracticeItem item, FormKey key) => [
    render(item, key),
    if (alsoAccepts != null) render(item, alsoAccepts!),
  ];
}

SpecGenerator _spec(ExerciseKind kind) =>
    exerciseGenerators.singleWhere((g) => g.kind == kind);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PracticeItem vocare;
  late PracticeItem incendere;
  late PracticeItem legere;
  late PracticeItem puella;
  late PracticeItem rosa;
  late PracticeItem tartarus;
  late PracticeItem manus;
  late PracticeItem roma;
  late GermanForms german;
  late GermanForms nounGerman;
  setUpAll(() async {
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
    incendere = verbs.singleWhere((i) => i.id == 'verbs:incendere');
    legere = verbs.singleWhere((i) => i.id == 'verbs:legere');
    final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
    puella = nouns.singleWhere((i) => i.lemma.startsWith('puella'));
    rosa = nouns.singleWhere((i) => i.id == 'nouns:rosa');
    tartarus = nouns.singleWhere((i) => i.id == 'nouns:tartarus');
    manus = nouns.singleWhere((i) => i.id == 'nouns:manus');
    roma = nouns.singleWhere((i) => i.id == 'nouns:roma');
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

    test('frames the four options of roma dat.sg with distinct German', () {
      final context = ctx(roma, {roma.type}, forms: nounGerman);
      final e = build(
        ExerciseKind.latDeWahl,
        roma,
        roma.type,
        seed: Iterable<int>.generate(100).firstWhere(
          (seed) =>
              (build(
                        ExerciseKind.latDeWahl,
                        roma,
                        roma.type,
                        seed: seed,
                        forms: nounGerman,
                      ).answer
                      as ChoiceAnswer)
                  .right
                  .formKey ==
              'dat.sg',
        ),
        forms: nounGerman,
      );
      final options = (e.answer as ChoiceAnswer).options;
      expect(options.map((o) => o.text).toSet(), hasLength(4));
      expect(
        violations(
          e,
          _spec(ExerciseKind.latDeWahl).spec,
          roma,
          roma.type,
          context,
        ),
        isEmpty,
      );
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
      final context = ctx(tartarus, bundles, forms: nounGerman);
      final cube = Cube(context);
      final wrongCells = <Cell>{};
      for (final bundle in bundles) {
        for (var seed = 0; seed < 5; seed++) {
          final e = _spec(
            ExerciseKind.deLatWahl,
          ).build(tartarus, bundle, context, Random(seed));
          expect(
            violations(
              e,
              _spec(ExerciseKind.deLatWahl).spec,
              tartarus,
              bundle,
              context,
            ),
            isEmpty,
          );
          final answer = e.answer as ChoiceAnswer;
          wrongCells.addAll([
            for (final o in answer.options)
              if (o != answer.right) cube.cell(tartarus, o.formKey),
          ]);
        }
      }
      expect(
        wrongCells.where((c) => !cube.view(View.german).covers(c)),
        isNotEmpty,
      );
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

    group('deLatWahl objects to a wrong option that', () {
      const bundle = 'ind.praes.akt';
      Set<String> objectionsToSwap(
        bool Function(Cube, FormCell, FormCell) pick,
      ) {
        final c = ctx(vocare, {bundle});
        final cube = Cube(c);
        final e = build(ExerciseKind.deLatWahl, vocare, bundle);
        final answer = e.answer as ChoiceAnswer;
        final target = cube.cell(vocare, answer.right.formKey);
        final stray = cube
            .cellsOf(vocare)
            .firstWhere((x) => pick(cube, target, x));
        final swapped = answer.options.indexWhere(
          (o) => o != answer.right && o.builtWrongBy == null,
        );
        final options = [...answer.options];
        options[swapped] = optionOf(stray, View.latin, cube);
        final changed = Exercise(
          wordCardId: e.wordCardId,
          grammarCardId: e.grammarCardId,
          kind: e.kind,
          questionKey: e.questionKey,
          questionParams: e.questionParams,
          answer: ChoiceAnswer(options, answer.right),
        );
        return _spec(
          ExerciseKind.deLatWahl,
        ).objections(changed, vocare, bundle, c).toSet();
      }

      test('is two axes away', () {
        expect(
          objectionsToSwap(
            (cube, t, x) => distance(t, x) == 2 && cube.unlocked(x),
          ),
          contains(contains('no option source cell')),
        );
      });

      test('belongs to a locked bundle', () {
        expect(
          objectionsToSwap(
            (cube, t, x) => distance(t, x) == 1 && !cube.unlocked(x),
          ),
          contains(contains('no option source cell')),
        );
      });
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

    test('never shows a start that is the answer but for macrons', () {
      // Praes. akt. 3.sg legit and Perf. akt. 3.sg lēgit.
      final everywhere = {
        for (final k in legere.formOrder) bundleOf(legere, k),
      };
      for (var seed = 0; seed < 200; seed++) {
        final e = _spec(ExerciseKind.umformen).build(
          legere,
          'ind.perf.akt',
          ExerciseContext(unlocked: everywhere, pool: [legere], german: german),
          Random(seed),
        );
        expect(
          (e.answer as TypedAnswer).accepted.map(norm),
          isNot(contains(norm(e.questionParams['start']!))),
          reason: '${e.questionParams}',
        );
      }
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

  group('A9 fehlerFinden from its spec', () {
    const perfPass = 'ind.perf.pass';

    Iterable<Exercise> built(PracticeItem word, GrammarBundle bundle) =>
        Iterable.generate(
          60,
          (seed) => build(ExerciseKind.fehlerFinden, word, bundle, seed: seed),
        );

    test('shows a two-word form with one wrong word and expects the form', () {
      for (final e in built(vocare, perfPass)) {
        final answer = e.answer as TypedAnswer;
        final index = vocare.formOrder.indexOf(answer.expected.formKey);
        final right = answer.expected.text.split(' ');
        final wrong = e.questionParams['wrong']!.split(' ');
        expect(
          [for (var i = 0; i < 2; i++) right[i] != wrong[i]].where((d) => d),
          hasLength(1),
        );
        expect(
          e.questionParams['label'],
          describeLabels([vocare.formLabels[index]]),
        );
        expect(e.questionParams['word'], vocare.lemma);
        expect(answer.accepted, vocare.acceptedForms[index]);
      }
      expectValid(ExerciseKind.fehlerFinden, vocare, perfPass);
    });

    test('spoils both the participle and the auxiliary', () {
      final spoiledFirst = {
        for (final e in built(vocare, perfPass))
          (e.answer as TypedAnswer).expected.text.split(' ').first ==
              e.questionParams['wrong']!.split(' ').first,
      };
      expect(spoiledFirst, {true, false});
    });

    test('builds a wrong ending of another type for a one-word form', () {
      final e = build(ExerciseKind.fehlerFinden, rosa, rosa.type);
      final wrong = e.questionParams['wrong']!;
      expect(
        rosa.formOrder.any(
          (k) => rosa.accepts(rosa.formOrder.indexOf(k), wrong),
        ),
        isFalse,
      );
      expect(wrong, startsWith('ros'));
      expectValid(ExerciseKind.fehlerFinden, rosa, rosa.type);
    });

    test('never offers a swap that is a form of the word', () {
      const bundle = 'ind.fut.pass';
      final oneValid = syntheticVerb({
        'ind.fut.pass.sg': ['amātus est', 'amātī est'],
        'ind.fut.pass.pl': ['amātī sunt'],
      });
      for (var seed = 0; seed < 30; seed++) {
        expect(
          build(
            ExerciseKind.fehlerFinden,
            oneValid,
            bundle,
            seed: seed,
          ).questionParams['wrong'],
          'amātus sunt',
        );
      }
      final allValid = syntheticVerb({
        'ind.fut.pass.sg': ['amātus est', 'amātī est'],
        'ind.fut.pass.pl': ['amātī sunt', 'amātus sunt'],
      });
      expect(
        () => build(ExerciseKind.fehlerFinden, allValid, bundle),
        throwsA(isA<CannotBuild>()),
      );
    });

    test('admits its exercise whatever the spoiled param is called', () {
      final spec = _spec(ExerciseKind.fehlerFinden).spec;
      final renamed = SpecGenerator(
        KindSpec(
          kind: spec.kind,
          questionKey: spec.questionKey,
          select: spec.select,
          params: {
            for (final MapEntry(:key, :value) in spec.params.entries)
              key == 'wrong' ? 'spoiled' : key: value,
          },
          answer: spec.answer,
        ),
      );
      final c = ctx(vocare, {perfPass});
      final e = renamed.build(vocare, perfPass, c, Random(0));
      expect(e.questionParams, contains('spoiled'));
      expect(renamed.objections(e, vocare, perfPass, c), isEmpty);
    });
  });

  group('bestimmen from its spec', () {
    test('shows a form and offers four labels, the right one named alone', () {
      final bundle = rosa.type;
      for (var seed = 0; seed < 20; seed++) {
        final e = build(ExerciseKind.bestimmen, rosa, bundle, seed: seed);
        final answer = e.answer as ChoiceAnswer;
        final index = rosa.formOrder.indexOf(answer.right.formKey);
        expect(answer.options, hasLength(4));
        expect(answer.right.text, describeLabels([rosa.formLabels[index]]));
        expect(e.questionParams['form'], rosa.forms[index]);
      }
      expectValid(ExerciseKind.bestimmen, rosa, bundle);
    });

    test('never offers a label that the shown spelling also has', () {
      final answers = [
        for (var seed = 0; seed < 100; seed++)
          build(ExerciseKind.bestimmen, puella, puella.type, seed: seed),
      ].where((e) => e.questionParams['form'] == 'puellae');
      expect(answers, isNotEmpty);
      for (final e in answers) {
        final keys = {
          for (final o in (e.answer as ChoiceAnswer).options) o.formKey,
        };
        expect(
          keys.intersection({'nom.pl', 'vok.pl', 'gen.sg', 'dat.sg'}),
          hasLength(1),
          reason: '$keys',
        );
      }
    });
  });

  group('A5 zuordnen from its spec', () {
    const bundle = 'ind.praes.akt';

    test('pairs four Latin forms with the German text of the same cell', () {
      final e = build(ExerciseKind.zuordnen, vocare, bundle);
      expect(e.questionParams.keys, {'word'});
      final pairs = (e.answer as MatchingAnswer).pairs;
      expect(pairs, hasLength(4));
      expect(pairs.every((p) => p.$1.formKey == p.$2.formKey), isTrue);
      expectValid(ExerciseKind.zuordnen, vocare, bundle);
    });

    test('samples the covered cells of a bundle with uncovered keys', () {
      final keys = vocare.formOrder
          .where((k) => bundleOf(vocare, k) == bundle)
          .toList();
      final forms = _ScriptedGerman(uncovered: {keys.first, keys[1]});
      final e = build(ExerciseKind.zuordnen, vocare, bundle, forms: forms);
      final used = (e.answer as MatchingAnswer).pairs.map((p) => p.$1.formKey);
      expect(used, unorderedEquals(keys.skip(2)));
    });

    test('never pairs a cell whose German text another cell accepts', () {
      final shared = puella.formOrder.firstWhere(
        (k) => bundleOf(puella, k) == puella.type,
      );
      final forms = _ScriptedGerman(alsoAccepts: shared);
      final used = <FormKey>{};
      for (var seed = 0; seed < 20; seed++) {
        try {
          final e = build(
            ExerciseKind.zuordnen,
            puella,
            puella.type,
            seed: seed,
            forms: forms,
          );
          used.addAll(
            (e.answer as MatchingAnswer).pairs.map((p) => p.$1.formKey),
          );
        } on CannotBuild {
          continue;
        }
      }
      expect(used, isNotEmpty);
      expect(used, isNot(contains(shared)));
    });

    test('admits its own exercise and not one with swapped German texts', () {
      final e = build(ExerciseKind.zuordnen, vocare, bundle);
      final c = ctx(vocare, {bundle});
      final generator = _spec(ExerciseKind.zuordnen);
      expect(generator.objections(e, vocare, bundle, c), isEmpty);
      final pairs = (e.answer as MatchingAnswer).pairs;
      final swapped = Exercise(
        wordCardId: e.wordCardId,
        grammarCardId: e.grammarCardId,
        kind: e.kind,
        questionKey: e.questionKey,
        questionParams: e.questionParams,
        answer: MatchingAnswer([
          (pairs[0].$1, pairs[1].$2),
          (pairs[1].$1, pairs[0].$2),
          ...pairs.skip(2),
        ]),
      );
      expect(generator.objections(swapped, vocare, bundle, c), isNotEmpty);
    });

    test('objects to a pair whose German text another pair accepts', () {
      final first = vocare.formOrder.firstWhere(
        (k) => bundleOf(vocare, k) == bundle,
      );
      final e =
          Iterable.generate(
            50,
            (seed) => build(
              ExerciseKind.zuordnen,
              vocare,
              bundle,
              seed: seed,
              forms: const _ScriptedGerman(),
            ),
          ).firstWhere(
            (e) => (e.answer as MatchingAnswer).pairs.any(
              (p) => p.$1.formKey == first,
            ),
          );
      final accepting = ctx(vocare, {
        bundle,
      }, forms: _ScriptedGerman(alsoAccepts: first));
      expect(
        _spec(ExerciseKind.zuordnen).objections(e, vocare, bundle, accepting),
        contains(contains('clashes')),
      );
    });

    test('may pair Latin forms that differ only by macrons when macron twins '
        'are allowed', () {
      final allowing = ExerciseContext(
        unlocked: {puella.type},
        pool: [puella],
        german: nounGerman,
        avoidMacronTwins: false,
      );
      final twins =
          [
            for (var seed = 0; seed < 20; seed++)
              _spec(
                ExerciseKind.zuordnen,
              ).build(puella, puella.type, allowing, Random(seed)),
          ].where(
            (e) =>
                (e.answer as MatchingAnswer).pairs
                    .map((p) => norm(p.$1.text))
                    .toSet()
                    .length <
                4,
          );
      expect(twins, isNotEmpty);
      for (final e in twins) {
        expect(
          violations(
            e,
            _spec(ExerciseKind.zuordnen).spec,
            puella,
            puella.type,
            allowing,
          ),
          isEmpty,
        );
      }
    });

    test('objects to a twin pairing only while macron twins are avoided', () {
      ExerciseContext context({required bool avoid}) => ExerciseContext(
        unlocked: {puella.type},
        pool: [puella],
        german: nounGerman,
        avoidMacronTwins: avoid,
      );
      final generator = _spec(ExerciseKind.zuordnen);
      final twins =
          [
            for (var seed = 0; seed < 20; seed++)
              generator.build(
                puella,
                puella.type,
                context(avoid: false),
                Random(seed),
              ),
          ].where(
            (e) =>
                (e.answer as MatchingAnswer).pairs
                    .map((p) => norm(p.$1.text))
                    .toSet()
                    .length <
                4,
          );
      expect(twins, isNotEmpty);
      for (final e in twins) {
        expect(
          generator.objections(e, puella, puella.type, context(avoid: false)),
          isEmpty,
        );
        expect(
          generator.objections(e, puella, puella.type, context(avoid: true)),
          isNotEmpty,
        );
      }
    });

    test('never pairs two Latin forms that differ only by macrons', () {
      for (var seed = 0; seed < 20; seed++) {
        final e = _spec(ExerciseKind.zuordnen).build(
          puella,
          puella.type,
          ctx(puella, {puella.type}, forms: nounGerman),
          Random(seed),
        );
        final latin = (e.answer as MatchingAnswer).pairs.map((p) => p.$1.text);
        expect(latin.map(norm).toSet(), hasLength(4), reason: '$latin');
      }
    });

    test('cannot build without German forms', () {
      expect(
        () => build(
          ExerciseKind.zuordnen,
          vocare,
          bundle,
          forms: const NoForms(),
        ),
        throwsA(isA<CannotBuild>()),
      );
    });
  });

  group('A10 formenKette from its spec', () {
    Exercise chain(
      PracticeItem word,
      GrammarBundle bundle,
      int seed, {
      bool avoidMacronTwins = true,
    }) {
      final everywhere = {for (final k in word.formOrder) bundleOf(word, k)};
      return _spec(ExerciseKind.formenKette).build(
        word,
        bundle,
        ExerciseContext(
          unlocked: everywhere,
          pool: [word],
          german: german,
          avoidMacronTwins: avoidMacronTwins,
        ),
        Random(seed),
      );
    }

    test('may show a start that is the answer but for macrons when macron '
        'twins are allowed', () {
      final twins =
          [
            for (var seed = 0; seed < 400; seed++)
              chain(legere, 'ind.fut2.akt', seed, avoidMacronTwins: false),
          ].where(
            (e) => (e.answer as TypedAnswer).accepted
                .map(norm)
                .contains(norm(e.questionParams['start']!)),
          );
      expect(twins, isNotEmpty);
    });

    test('objects to a twin start only while macron twins are avoided', () {
      final everywhere = {
        for (final k in legere.formOrder) bundleOf(legere, k),
      };
      ExerciseContext context({required bool avoid}) => ExerciseContext(
        unlocked: everywhere,
        pool: [legere],
        german: german,
        avoidMacronTwins: avoid,
      );
      final generator = _spec(ExerciseKind.formenKette);
      final twins =
          [
            for (var seed = 0; seed < 400; seed++)
              chain(legere, 'ind.fut2.akt', seed, avoidMacronTwins: false),
          ].where(
            (e) => (e.answer as TypedAnswer).accepted
                .map(norm)
                .contains(norm(e.questionParams['start']!)),
          );
      expect(twins, isNotEmpty);
      for (final e in twins) {
        expect(
          generator.objections(
            e,
            legere,
            'ind.fut2.akt',
            context(avoid: false),
          ),
          isEmpty,
        );
        expect(
          generator.objections(e, legere, 'ind.fut2.akt', context(avoid: true)),
          isNotEmpty,
        );
      }
    });

    test('changes two or three axes of a shown form', () {
      final lengths = <int>{};
      for (var seed = 0; seed < 20; seed++) {
        final e = chain(vocare, 'ind.praes.pass', seed);
        expect(e.questionKey, 'exercise.transform.chainQuestion');
        lengths.add('→'.allMatches(e.questionParams['changes']!).length + 1);
      }
      expect(lengths, {2, 3});
    });

    test('never shows a start that is the answer but for macrons', () {
      // Pass. 2.sg legeris and Fut. II akt. 2.sg lēgeris.
      for (var seed = 0; seed < 400; seed++) {
        final e = chain(legere, 'ind.fut2.akt', seed);
        expect(
          (e.answer as TypedAnswer).accepted.map(norm),
          isNot(contains(norm(e.questionParams['start']!))),
          reason: '${e.questionParams}',
        );
      }
    });

    test('never shows the answer as the start', () {
      // Pass. 2.sg and Fut. II akt. 2.sg are both incenderis.
      for (var seed = 0; seed < 400; seed++) {
        final e = chain(incendere, 'ind.fut2.akt', seed);
        expect(
          e.questionParams['start'],
          isNot((e.answer as TypedAnswer).expected.text),
          reason: '${e.questionParams}',
        );
      }
    });
  });
}
