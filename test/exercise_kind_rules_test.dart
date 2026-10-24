import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/diagnosis.dart';
import 'package:latin_practice/data/exercise_choice.dart';
import 'package:latin_practice/data/exercise_interpreter.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/exercise_spec.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

import 'support/exercise_fakes.dart';
import 'support/exercise_invariants.dart';
import 'support/hand_items.dart';
import 'support/i18n_keys.dart';

class _GermanByKey implements GermanForms {
  const _GermanByKey(this.byKey, {this.covered});

  final Map<FormKey, String> byKey;
  final Set<FormKey>? covered;

  @override
  bool covers(PracticeItem item, FormKey key) =>
      covered == null || covered!.contains(key);

  @override
  String render(PracticeItem item, FormKey key) => byKey[key] ?? key;

  @override
  List<String> accepted(PracticeItem item, FormKey key) => [render(item, key)];
}

class _CountingRandom implements Random {
  _CountingRandom(this._inner);

  final Random _inner;
  int calls = 0;

  @override
  int nextInt(int max) {
    calls++;
    return _inner.nextInt(max);
  }

  @override
  bool nextBool() => _inner.nextBool();

  @override
  double nextDouble() => _inner.nextDouble();
}

SpecGenerator _g(ExerciseKind kind) =>
    exerciseGenerators.singleWhere((g) => g.kind == kind);

Set<GrammarBundle> _bundles(PracticeItem item) => {
  for (final key in item.formOrder) bundleOf(item, key),
};

Matcher _cannotBuild([String? reason]) => throwsA(
  isA<CannotBuild>().having(
    (e) => e.reason,
    'reason',
    reason == null ? anything : contains(reason),
  ),
);

const _target = 'ind.perf.akt.2.pl';

PracticeItem _hand(Map<FormKey, List<String>> forms) => handItem(
  dataFileId: 'verbs',
  lemma: 'vocare',
  axes: fullVerbAxes,
  forms: {
    _target: ['vocavistis', 'vocastis'],
    ...forms,
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PracticeItem vocare;
  late PracticeItem audire;
  late PracticeItem amare;
  late PracticeItem puella;
  late List<PracticeItem> nouns;
  late GermanForms german;

  setUpAll(() async {
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
    audire = verbs.singleWhere((i) => i.id == 'verbs:audire');
    amare = verbs.singleWhere((i) => i.id == 'verbs:amare');
    nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
    puella = nouns.singleWhere((i) => i.lemma.startsWith('puella'));
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    german = await container.read(germanFormsProvider.future);
    container.dispose();
  });

  ExerciseContext ctx(
    PracticeItem word, {
    Set<GrammarBundle>? unlocked,
    GermanForms? forms,
  }) => ExerciseContext(
    unlocked: unlocked ?? _bundles(word),
    pool: [word],
    german: forms ?? german,
  );

  Exercise build(
    ExerciseKind kind,
    PracticeItem word,
    GrammarBundle bundle, {
    int seed = 0,
    Set<GrammarBundle>? unlocked,
    GermanForms? forms,
  }) => _g(kind).build(
    word,
    bundle,
    ctx(word, unlocked: unlocked ?? {bundle}, forms: forms),
    Random(seed),
  );

  Iterable<Exercise> built(
    ExerciseKind kind,
    PracticeItem word,
    GrammarBundle bundle, {
    int seeds = 30,
    Set<GrammarBundle>? unlocked,
    GermanForms? forms,
  }) sync* {
    for (var seed = 0; seed < seeds; seed++) {
      try {
        yield build(
          kind,
          word,
          bundle,
          seed: seed,
          unlocked: unlocked,
          forms: forms,
        );
      } on CannotBuild {
        continue;
      }
    }
  }

  group('registry', () {
    test('holds one generator per kind of the specs', () {
      final kinds = [for (final g in exerciseGenerators) g.kind];
      expect(kinds, [for (final s in kindSpecs) s.kind]);
      expect(kinds.toSet(), hasLength(kinds.length));
      expect(
        kinds.toSet(),
        ExerciseKind.values.toSet()..remove(ExerciseKind.paradigma),
      );
    });

    test('every kind holds its question key in both languages', () {
      for (final code in ['de', 'en']) {
        final keys = translationKeys(code);
        for (final spec in kindSpecs) {
          expect(keys, contains(spec.questionKey), reason: '$code $spec');
        }
      }
    });
  });

  group('what every kind builds', () {
    final shapes = [
      (
        ExerciseKind.latDeWahl,
        'verbs:vocare',
        'ind.praes.akt',
        'exercise.translate.latDe.question',
        {'form', 'word'},
      ),
      (
        ExerciseKind.deLatWahl,
        'verbs:vocare',
        'ind.praes.akt',
        'exercise.translate.deLat.question',
        {'german', 'word'},
      ),
      (
        ExerciseKind.deLatTippen,
        'verbs:vocare',
        'ind.praes.akt',
        'exercise.translate.deLatType.question',
        {'german', 'word'},
      ),
      (
        ExerciseKind.formBilden,
        'verbs:audire',
        'konj.impf.pass',
        'exercise.build.question',
        {'label', 'word'},
      ),
      (
        ExerciseKind.formBilden,
        'nouns:puella',
        '',
        'exercise.build.question',
        {'label', 'word'},
      ),
      (
        ExerciseKind.irrlaeufer,
        'verbs:vocare',
        'ind.praes.akt',
        'exercise.oddone.question',
        <String>{},
      ),
      (
        ExerciseKind.umformen,
        'verbs:audire',
        'ind.praes.pass',
        'exercise.transform.question',
        {'start', 'word', 'changes'},
      ),
      (
        ExerciseKind.formenKette,
        'verbs:audire',
        'ind.praes.pass',
        'exercise.transform.chainQuestion',
        {'start', 'word', 'changes'},
      ),
      (
        ExerciseKind.fehlerFinden,
        'verbs:vocare',
        'ind.perf.pass',
        'exercise.finderror.question',
        {'label', 'word', 'wrong'},
      ),
      (
        ExerciseKind.bestimmen,
        'nouns:puella',
        '',
        'exercise.bestimmen.question',
        {'form', 'word'},
      ),
      (
        ExerciseKind.zuordnen,
        'verbs:vocare',
        'ind.praes.akt',
        'exercise.match.question',
        {'word'},
      ),
    ];

    for (final (kind, id, bundleName, key, params) in shapes) {
      test('$kind: both cards, the question and its params', () {
        final word = [vocare, audire, puella].singleWhere((w) => w.id == id);
        final bundle = bundleName.isEmpty ? puella.type : bundleName;
        final e = build(kind, word, bundle, unlocked: _bundles(word));
        expect(e.kind, kind);
        expect(e.wordCardId, word.id);
        expect(e.grammarCardId, GrammarCardId(word.dataFileId, bundle));
        expect(e.questionKey, key);
        expect(e.questionParams.keys, params);
        expect(e.questionParams['word'] ?? word.lemma, word.lemma);
        switch (e.answer) {
          case ChoiceAnswer(:final options):
            expect(options, hasLength(4));
            expect(options.map((o) => o.lexemeId).toSet(), {word.id});
          case MatchingAnswer(:final pairs):
            expect(pairs, hasLength(4));
          case TypedAnswer(:final expected, :final accepted):
            expect(expected.lexemeId, word.id);
            expect(accepted, contains(expected.text));
        }
      });
    }

    test('a typed answer accepts the variants of its form', () {
      final vocareVariants = vocare.acceptedForms.indexed.firstWhere(
        (e) => e.$2.length > 1,
      );
      final key = vocare.formOrder[vocareVariants.$1];
      final bundle = bundleOf(vocare, key);
      final answers = [
        for (final e in built(ExerciseKind.formBilden, vocare, bundle))
          e.answer as TypedAnswer,
      ];
      final answer = answers.firstWhere((a) => a.expected.formKey == key);
      expect(answer.accepted, vocare.acceptedForms[vocareVariants.$1]);
    });
  });

  group('cannot build', () {
    for (final spec in kindSpecs) {
      test('${spec.kind}: a bundle that is not unlocked', () {
        expect(
          () => build(
            spec.kind,
            vocare,
            'ind.praes.akt',
            unlocked: {'ind.praes.pass'},
          ),
          _cannotBuild('locked'),
        );
      });

      test('${spec.kind}: a bundle the word has no form in', () {
        expect(
          () => build(spec.kind, vocare, puella.type),
          throwsA(isA<CannotBuild>()),
        );
      });
    }

    for (final kind in [ExerciseKind.umformen, ExerciseKind.formenKette]) {
      test('$kind: no neighbour of the form is unlocked', () {
        expect(
          () => build(kind, audire, 'inf.praes.akt'),
          throwsA(isA<CannotBuild>()),
        );
      });
    }

    for (final kind in [
      ExerciseKind.latDeWahl,
      ExerciseKind.deLatWahl,
      ExerciseKind.deLatTippen,
    ]) {
      test('$kind: no German forms', () {
        expect(
          () => build(
            kind,
            vocare,
            'ind.praes.akt',
            forms: const FakeGermanForms(coversAll: false),
          ),
          throwsA(isA<CannotBuild>()),
        );
      });
    }
  });

  group('irrlaeufer', () {
    test('four forms of the word, one of them the lone one', () {
      final spec = _g(ExerciseKind.irrlaeufer).spec;
      for (final e in built(
        ExerciseKind.irrlaeufer,
        vocare,
        'ind.praes.akt',
        unlocked: _bundles(vocare),
      )) {
        expect(
          violations(
            e,
            spec,
            vocare,
            'ind.praes.akt',
            ctx(vocare, unlocked: _bundles(vocare)),
          ),
          isEmpty,
        );
        final answer = e.answer as ChoiceAnswer;
        expect(answer.options, hasLength(4));
        for (final o in answer.options) {
          expect(o.text, vocare.forms[vocare.formOrder.indexOf(o.formKey)]);
        }
      }
    });

    test('the three others lie in the asked bundle', () {
      for (final e in built(
        ExerciseKind.irrlaeufer,
        vocare,
        'ind.praes.akt',
        unlocked: _bundles(vocare),
      )) {
        final inBundle = (e.answer as ChoiceAnswer).options
            .where((o) => bundleOf(vocare, o.formKey) == 'ind.praes.akt')
            .length;
        expect(inBundle, anyOf(3, 4));
      }
    });

    test('the odd form comes only from an unlocked bundle', () {
      for (final e in built(ExerciseKind.irrlaeufer, vocare, 'ind.praes.akt')) {
        for (final o in (e.answer as ChoiceAnswer).options) {
          expect(bundleOf(vocare, o.formKey), 'ind.praes.akt');
        }
      }
    });

    test('with the neighbour bundles unlocked, the odd form can leave', () {
      final left = {
        for (final e in built(
          ExerciseKind.irrlaeufer,
          vocare,
          'ind.praes.akt',
          seeds: 60,
          unlocked: _bundles(vocare),
        ))
          bundleOf(vocare, (e.answer as ChoiceAnswer).right.formKey),
      };
      expect(left.length, greaterThan(1));
    });

    test('an adjective bundle draws few quartets and still builds', () {
      final durus = nouns.reduce(
        (a, b) => a.formOrder.length >= b.formOrder.length ? a : b,
      );
      final bundle = bundleOf(durus, durus.formOrder.first);
      final rng = _CountingRandom(Random(1));
      final answer =
          _g(ExerciseKind.irrlaeufer)
                  .build(
                    durus,
                    bundle,
                    ctx(durus, unlocked: _bundles(durus)),
                    rng,
                  )
                  .answer
              as ChoiceAnswer;
      final maxDraws =
          (_g(ExerciseKind.irrlaeufer).spec.select as OddOneOut).maxDraws;
      expect(answer.options, hasLength(4));
      expect(rng.calls, lessThan(maxDraws * 5));
    });

    group('cannot build', () {
      PracticeItem item(Map<FormKey, List<String>> forms) => handItem(
        dataFileId: 'verbs',
        lemma: 'vocare',
        axes: fullVerbAxes,
        forms: forms,
      );

      void expectNone(PracticeItem word) {
        for (var seed = 0; seed < 5; seed++) {
          expect(
            () => _g(ExerciseKind.irrlaeufer).build(
              word,
              bundleOf(word, word.formOrder.first),
              fakeExerciseContext(unlocked: _bundles(word)),
              Random(seed),
            ),
            _cannotBuild(),
          );
        }
      }

      test('a bundle with fewer than three forms', () {
        expect(
          () => build(ExerciseKind.irrlaeufer, vocare, 'inf.praes.akt'),
          _cannotBuild(),
        );
      });

      test(
        'majority forms that read the same leave no unambiguous odd form',
        () {
          expectNone(
            item({
              'ind.praes.akt.1.sg': ['voco'],
              'ind.praes.akt.2.sg': ['voco'],
              'ind.praes.akt.3.sg': ['voco'],
              'ind.praes.akt.1.pl': ['vocamus'],
            }),
          );
        },
      );

      test('an odd form that reads like a majority form is not offered', () {
        expectNone(
          item({
            'ind.praes.akt.1.sg': ['a'],
            'ind.praes.akt.2.sg': ['b'],
            'ind.praes.akt.3.sg': ['c'],
            'ind.praes.akt.1.pl': ['a', 'x'],
          }),
        );
      });

      test('an odd form two features away is not a neighbour', () {
        expectNone(
          item({
            'ind.praes.akt.1.sg': ['a'],
            'ind.praes.akt.2.sg': ['b'],
            'ind.praes.akt.3.sg': ['c'],
            'ind.fut.akt.1.pl': ['d'],
          }),
        );
      });

      test('a second lone form on another feature makes the quartet unfit', () {
        expectNone(
          item({
            'ind.praes.akt.1.sg': ['a'],
            'ind.praes.akt.2.sg': ['b'],
            'ind.praes.akt.2.pl': ['c'],
            'ind.fut.akt.1.sg': ['d'],
          }),
        );
      });

      test('it draws exactly the bound of quartets before it gives up', () {
        final word = item({
          'ind.praes.akt.1.sg': ['voco'],
          'ind.praes.akt.2.pl': ['vocatis'],
          'ind.praes.akt.3.sg': ['vocat'],
        });
        final rng = _CountingRandom(Random(0));
        final maxDraws =
            (_g(ExerciseKind.irrlaeufer).spec.select as OddOneOut).maxDraws;
        expect(
          () => _g(ExerciseKind.irrlaeufer).build(
            word,
            bundleOf(word, word.formOrder.first),
            fakeExerciseContext(unlocked: _bundles(word)),
            rng,
          ),
          _cannotBuild(),
        );
        expect(rng.calls, 2 * maxDraws);
      });
    });
  });

  group('umformen and formenKette', () {
    test('umformen changes exactly one axis', () {
      final unlocked = {'ind.praes.pass', 'ind.praes.akt'};
      for (final e in built(
        ExerciseKind.umformen,
        audire,
        'ind.praes.pass',
        unlocked: unlocked,
      )) {
        final expected = (e.answer as TypedAnswer).expected;
        final b = audire
            .formLabels[audire.formOrder.indexOf(expected.formKey)]
            .features;
        final starts = audire.formOrder.where(
          (k) =>
              audire.forms[audire.formOrder.indexOf(k)] ==
              e.questionParams['start'],
        );
        expect(
          starts.any((start) {
            final a =
                audire.formLabels[audire.formOrder.indexOf(start)].features;
            final differing = {
              ...a.keys,
              ...b.keys,
            }.where((axis) => a[axis] != b[axis]);
            return differing.length == 1;
          }),
          isTrue,
          reason: '${e.questionParams} into ${expected.formKey}',
        );
      }
    });

    test('umformen never starts from a form spelled like the answer', () {
      for (final word in nouns.take(40)) {
        final bundle = word.type;
        for (final e in built(
          ExerciseKind.umformen,
          word,
          bundle,
          seeds: 5,
          forms: const FakeGermanForms(),
        )) {
          expect(
            (e.answer as TypedAnswer).accepted.map(norm),
            isNot(contains(norm(e.questionParams['start']!))),
            reason: '${word.id} ${e.questionParams}',
          );
        }
      }
    });

    test('umformen on a noun changes the number', () {
      final e = build(ExerciseKind.umformen, puella, puella.type);
      final start = puella.formOrder.firstWhere(
        (k) =>
            puella.forms[puella.formOrder.indexOf(k)] ==
            e.questionParams['start'],
      );
      final features =
          puella.formLabels[puella.formOrder.indexOf(start)].features;
      final target = puella
          .formLabels[puella.formOrder.indexOf(
            (e.answer as TypedAnswer).expected.formKey,
          )]
          .features;
      expect(features['numerus'], isNot(target['numerus']));
    });

    test('a chain joins distinct steps and lands in the asked bundle', () {
      final lengths = <int>{};
      for (final e in built(
        ExerciseKind.formenKette,
        audire,
        'ind.praes.pass',
        unlocked: _bundles(audire),
      )) {
        final steps = e.questionParams['changes']!.split(' → ');
        lengths.add(steps.length);
        expect(steps.toSet(), hasLength(steps.length));
        expect(
          bundleOf(audire, (e.answer as TypedAnswer).expected.formKey),
          'ind.praes.pass',
        );
      }
      expect(lengths, {2, 3});
    });

    group('the chain over a synthetic verb', () {
      final cube = syntheticVerb({
        for (final tempus in ['praes', 'fut'])
          for (final genus in ['akt', 'pass'])
            for (final numerus in ['sg', 'pl'])
              'ind.$tempus.$genus.$numerus': [
                '$tempus$genus$numerus',
                '$tempus$genus$numerus-v',
              ],
      });
      const changeable = ['tempus', 'genus_verbi', 'numerus'];

      Iterable<List<String>> orders(List<String> axes) sync* {
        if (axes.length <= 1) {
          yield axes;
          return;
        }
        for (final axis in axes) {
          for (final rest in orders([...axes]..remove(axis))) {
            yield [axis, ...rest];
          }
        }
      }

      Map<String, String> features(FormKey key) =>
          cube.formLabels[cube.formOrder.indexOf(key)].features;

      test('shows the first spelling of the start and one label per step', () {
        final axes = cube.formLabels.first.axes;
        for (var seed = 0; seed < 40; seed++) {
          final e = _g(ExerciseKind.formenKette).build(
            cube,
            'ind.praes.akt',
            fakeExerciseContext(unlocked: _bundles(cube)),
            Random(seed),
          );
          final start = cube.formOrder.singleWhere(
            (k) =>
                cube.forms[cube.formOrder.indexOf(k)] ==
                e.questionParams['start'],
          );
          final target = features((e.answer as TypedAnswer).expected.formKey);
          final differing = [
            for (final axis in changeable)
              if (features(start)[axis] != target[axis]) axis,
          ];
          final readings = {
            for (final order in orders(differing))
              () {
                final reached = {...features(start)};
                return order
                    .map((axis) {
                      reached[axis] = target[axis]!;
                      return axes.displayOf(axis, reached);
                    })
                    .join(' → ');
              }(),
          };
          expect(readings, contains(e.questionParams['changes']));
          expect(
            e.questionParams['changes']!.split(' → '),
            hasLength(differing.length),
          );
        }
      });

      test('the typed answer accepts every variant of the target', () {
        final e = _g(ExerciseKind.formenKette).build(
          cube,
          'ind.praes.akt',
          fakeExerciseContext(unlocked: _bundles(cube)),
          Random(0),
        );
        final answer = e.answer as TypedAnswer;
        expect(
          answer.accepted,
          cube.acceptedForms[cube.formOrder.indexOf(answer.expected.formKey)],
        );
      });

      test('a start that is spelled like the target cannot be built', () {
        final square = syntheticVerb({
          'ind.akt.sg': ['a'],
          'ind.akt.pl': ['b'],
          'ind.pass.sg': ['b'],
          'ind.pass.pl': ['a'],
        });
        for (var seed = 0; seed < 20; seed++) {
          expect(
            () => _g(ExerciseKind.formenKette).build(
              square,
              'ind.akt',
              fakeExerciseContext(unlocked: _bundles(square)),
              Random(seed),
            ),
            _cannotBuild(),
          );
        }
      });
    });
  });

  group('zuordnen', () {
    test('pairs the German texts of the German verb data', () {
      const expected = {
        'ind.praes.akt.1.sg': 'ich rufe',
        'ind.praes.akt.1.pl': 'wir rufen',
        'ind.praes.akt.2.sg': 'du rufst',
        'ind.praes.akt.2.pl': 'ihr ruft',
        'ind.praes.akt.3.sg': 'er/sie/es ruft',
        'ind.praes.akt.3.pl': 'sie (Pl.) rufen',
      };
      final pairs =
          (build(ExerciseKind.zuordnen, vocare, 'ind.praes.akt').answer
                  as MatchingAnswer)
              .pairs;
      for (final (latin, germanOption) in pairs) {
        expect(germanOption.text, expected[latin.formKey]);
        expect(
          latin.text,
          vocare.forms[vocare.formOrder.indexOf(latin.formKey)],
        );
      }
      expect(pairs.map((p) => p.$2.text).toSet(), hasLength(4));
    });

    test('a noun bundle builds as well', () {
      final pairs =
          (build(ExerciseKind.zuordnen, puella, puella.type).answer
                  as MatchingAnswer)
              .pairs;
      expect(pairs, hasLength(4));
    });

    test('a bundle with fewer than four forms cannot be built', () {
      final small = _bundles(vocare).firstWhere(
        (b) =>
            vocare.formOrder.where((k) => bundleOf(vocare, k) == b).length < 4,
      );
      expect(() => build(ExerciseKind.zuordnen, vocare, small), _cannotBuild());
    });

    test('forms with the same German text cannot be told apart', () {
      expect(
        () => build(
          ExerciseKind.zuordnen,
          vocare,
          'ind.praes.akt',
          forms: _SameGerman(),
        ),
        _cannotBuild(),
      );
    });
  });

  group('bestimmen', () {
    String label(PracticeItem w, FormKey k) =>
        w.formLabels[w.formOrder.indexOf(k)].displayName;

    Set<FormKey> readings(PracticeItem w, String shown) => {
      for (var i = 0; i < w.formOrder.length; i++)
        if (w.acceptedForms[i].contains(shown)) w.formOrder[i],
    };

    Exercise bestimmen(PracticeItem word, int seed) {
      final bundle = bundleOf(word, word.formOrder.first);
      return _g(ExerciseKind.bestimmen).build(
        word,
        bundle,
        fakeExerciseContext(unlocked: {bundle}, pool: nouns),
        Random(seed),
      );
    }

    test('no wrong option is a reading of the shown spelling', () {
      var ambiguous = 0;
      for (final word in nouns) {
        for (var seed = 0; seed < 5; seed++) {
          final e = bestimmen(word, seed);
          final answer = e.answer as ChoiceAnswer;
          final keys = readings(word, e.questionParams['form']!);
          if (keys.length > 1) ambiguous++;
          expect(answer.options, hasLength(4));
          for (final o in answer.options.where(
            (o) => !identical(o, answer.right),
          )) {
            expect(keys, isNot(contains(o.formKey)), reason: word.id);
          }
        }
      }
      expect(ambiguous, greaterThan(0));
    });

    test('a unique spelling names exactly one label', () {
      var unique = 0;
      for (final word in nouns) {
        final e = bestimmen(word, 0);
        final shown = readings(word, e.questionParams['form']!);
        if (shown.length != 1) continue;
        unique++;
        expect(
          (e.answer as ChoiceAnswer).right.text,
          label(word, shown.single),
          reason: word.id,
        );
      }
      expect(unique, greaterThan(0));
    });

    test('one seed builds one exercise', () {
      for (final word in nouns.take(10)) {
        final a = bestimmen(word, 7).answer as ChoiceAnswer;
        final b = bestimmen(word, 7).answer as ChoiceAnswer;
        expect(a.options.map((o) => o.text), b.options.map((o) => o.text));
      }
    });

    test(
      'a noun pair at stability 0 builds both odd-one-out and bestimmen',
      () {
        final bundle = bundleOf(puella, puella.formOrder.first);
        final kinds = {
          for (var seed = 0; seed < 60; seed++)
            buildExercise(
              puella,
              bundle,
              fakeExerciseContext(unlocked: {bundle}, pool: nouns),
              0,
              Random(seed),
              registry: exerciseGenerators,
            ).kind,
        };
        expect(
          kinds,
          containsAll([ExerciseKind.irrlaeufer, ExerciseKind.bestimmen]),
        );
      },
    );

    test('the English UI builds bestimmen: it shows no German text', () {
      final bundle = bundleOf(puella, puella.formOrder.first);
      final e = _g(ExerciseKind.bestimmen).build(
        puella,
        bundle,
        ExerciseContext(
          unlocked: {bundle},
          pool: nouns,
          german: const NoForms(),
        ),
        Random(0),
      );
      expect(e.kind, ExerciseKind.bestimmen);
    });
  });

  group('the translation kinds', () {
    const frames = {
      'konj.praes.pass.3.pl': 'Ich frage, ob sie (Pl.) gerufen werden.',
      'konj.perf.pass.3.pl': 'Ich frage, ob sie (Pl.) gerufen worden sind.',
      'konj.impf.pass.3.pl': 'Ich fragte, ob sie (Pl.) gerufen würden.',
      'konj.plusq.pass.3.pl': 'Ich fragte, ob sie (Pl.) gerufen worden wären.',
    };

    for (final MapEntry(key: key, value: frame) in frames.entries) {
      final tense = key.split('.')[1];
      test('$tense: deLatWahl and deLatTippen show the German text in the '
          'frame', () {
        final bundle = bundleOf(vocare, key);
        for (final kind in [ExerciseKind.deLatWahl, ExerciseKind.deLatTippen]) {
          final shown = {
            for (final e in built(kind, vocare, bundle, seeds: 60))
              e.questionParams['german']!,
          };
          expect(shown, contains(frame), reason: '$kind');
          expect(shown, everyElement(startsWith('Ich frag')));
        }
      });

      test('$tense: latDeWahl frames every option', () {
        final bundle = bundleOf(vocare, key);
        for (final e in built(ExerciseKind.latDeWahl, vocare, bundle)) {
          final texts = (e.answer as ChoiceAnswer).options.map((o) => o.text);
          expect(texts, everyElement(startsWith('Ich frag')));
          expect(texts, everyElement(endsWith('.')));
        }
      });
    }

    test('latDeWahl frames all options or none', () {
      final unlocked = {'ind.praes.pass', 'konj.praes.pass', 'konj.impf.pass'};
      for (final bundle in unlocked) {
        for (final e in built(
          ExerciseKind.latDeWahl,
          vocare,
          bundle,
          seeds: 40,
          unlocked: unlocked,
        )) {
          final texts = (e.answer as ChoiceAnswer).options.map((o) => o.text);
          expect(
            texts.map((t) => t.startsWith('Ich frag')).toSet(),
            hasLength(1),
            reason: '$bundle $texts',
          );
        }
      }
    });

    test(
      'the present subjunctive is asked only once its bundle is unlocked',
      () {
        for (final kind in [
          ExerciseKind.latDeWahl,
          ExerciseKind.deLatWahl,
          ExerciseKind.deLatTippen,
        ]) {
          expect(
            () => build(
              kind,
              vocare,
              'konj.praes.pass',
              unlocked: {'konj.impf.pass', 'konj.plusq.pass'},
            ),
            _cannotBuild('locked'),
            reason: '$kind',
          );
        }
      },
    );

    test('amare impf and perf still build, and deLatTippen accepts both '
        'forms', () {
      final all = _bundles(amare);
      final impf = amare.forms[amare.formOrder.indexOf('ind.impf.akt.1.sg')];
      final perf = amare.forms[amare.formOrder.indexOf('ind.perf.akt.1.sg')];
      var asked = false;
      for (var seed = 0; seed < 40; seed++) {
        for (final kind in [ExerciseKind.latDeWahl, ExerciseKind.deLatWahl]) {
          build(kind, amare, 'ind.impf.akt', unlocked: all, seed: seed);
          build(kind, amare, 'ind.perf.akt', unlocked: all, seed: seed);
        }
        final e = build(
          ExerciseKind.deLatTippen,
          amare,
          'ind.impf.akt',
          unlocked: all,
          seed: seed,
        );
        if (e.questionParams['german'] == 'ich liebte') {
          asked = true;
          expect((e.answer as TypedAnswer).accepted, containsAll([impf, perf]));
        }
      }
      expect(asked, isTrue);
    });

    test('wrong endings do not count as German distractors', () {
      final all = _bundles(amare);
      for (var seed = 0; seed < 5; seed++) {
        expect(
          () => build(
            ExerciseKind.latDeWahl,
            amare,
            'inf.praes.akt',
            unlocked: all,
            seed: seed,
          ),
          _cannotBuild(),
        );
      }
    });

    test('too few German distractors cannot be built', () {
      expect(
        () => build(ExerciseKind.latDeWahl, vocare, 'inf.praes.akt'),
        _cannotBuild(),
      );
    });
  });

  group('the options next to the right one', () {
    final neighbours = {
      'ind.praes.akt.2.pl': ['vocatis'],
      'ind.fut.akt.2.pl': ['vocabitis'],
      'ind.perf.akt.3.pl': ['vocaverunt'],
      'ind.perf.akt.2.sg': ['vocavisti'],
    };

    List<ChoiceAnswer> choices(
      PracticeItem item, {
      Set<GrammarBundle>? unlocked,
      GermanForms? forms,
      ExerciseKind kind = ExerciseKind.deLatWahl,
    }) => [
      for (final e in built(
        kind,
        item,
        bundleOf(item, _target),
        unlocked: unlocked ?? _bundles(item),
        forms: forms ?? const FakeGermanForms(),
      ))
        e.answer as ChoiceAnswer,
    ];

    test('a wrong option is a real form one axis away, or the ending of '
        'another type', () {
      const key = 'ind.praes.akt.3.sg';
      final asked = vocare.formLabels[vocare.formOrder.indexOf(key)].features;
      final answers = [
        for (final e in built(
          ExerciseKind.deLatWahl,
          vocare,
          'ind.praes.akt',
          unlocked: _bundles(vocare),
          forms: const FakeGermanForms(),
          seeds: 60,
        ))
          if ((e.answer as ChoiceAnswer).right.formKey == key)
            e.answer as ChoiceAnswer,
      ];
      expect(answers, isNotEmpty);
      for (final answer in answers) {
        for (final o in answer.options) {
          if (identical(o, answer.right) || o.builtWrongBy != null) continue;
          final features =
              vocare.formLabels[vocare.formOrder.indexOf(o.formKey)].features;
          expect(
            {
              ...asked.keys,
              ...features.keys,
            }.where((axis) => asked[axis] != features[axis]),
            hasLength(1),
            reason: '${o.formKey} next to $key',
          );
        }
      }
    });

    test('a form two axes away is no wrong option', () {
      final item = _hand({
        'ind.praes.akt.2.pl': ['vocatis'],
        'ind.fut.pass.2.pl': ['vocabimini'],
      });
      expect(choices(item), isEmpty);
    });

    test('a form of a locked bundle is never offered', () {
      final item = _hand(neighbours);
      final answers = choices(
        item,
        unlocked: {bundleOf(item, _target), 'ind.praes'},
      );
      expect(answers, isNotEmpty);
      for (final a in answers) {
        expect(a.options.map((o) => o.text).toSet(), {
          'vocavistis',
          'vocatis',
          'vocaverunt',
          'vocavisti',
        });
      }
    });

    test('an accepted variant of the right answer is not offered', () {
      final item = _hand({
        'ind.praes.akt.2.pl': ['vocātis'],
        'konj.perf.akt.2.pl': ['vocastis'],
        'ind.fut.akt.2.pl': ['vocabitis'],
        'ind.perf.akt.3.pl': ['vocaverunt'],
        'ind.perf.akt.2.sg': ['vocavisti'],
      });
      for (final e in built(
        ExerciseKind.deLatWahl,
        item,
        bundleOf(item, _target),
        unlocked: _bundles(item),
        forms: const FakeGermanForms(),
        seeds: 60,
      )) {
        final answer = e.answer as ChoiceAnswer;
        if (answer.right.formKey != _target) continue;
        expect(answer.options.map((o) => o.text), isNot(contains('vocastis')));
      }
    });

    test('two options never share a spelling', () {
      final item = _hand({
        'ind.praes.akt.2.pl': ['vocatis'],
        'ind.fut.akt.2.pl': ['vocatis'],
        'ind.perf.akt.2.sg': ['vocavisti'],
      });
      expect(choices(item), isEmpty);
    });

    test('a neighbour with the German text of the right answer is not '
        'offered', () {
      final item = _hand({
        ...neighbours,
        'ind.perf.akt.1.pl': ['vocavimus'],
      });
      final german = _GermanByKey({
        _target: 'ihr habt gerufen',
        'ind.praes.akt.2.pl': 'ihr habt gerufen',
      });
      final answers = [
        for (final e in built(
          ExerciseKind.deLatWahl,
          item,
          bundleOf(item, _target),
          unlocked: _bundles(item),
          forms: german,
          seeds: 60,
        ))
          if (e.questionParams['german'] == 'ihr habt gerufen')
            e.answer as ChoiceAnswer,
      ];
      expect(answers, isNotEmpty);
      for (final a in answers) {
        expect(
          a.options.map((o) => o.formKey),
          isNot(contains('ind.praes.akt.2.pl')),
        );
      }
    });

    test('real forms carry their own key, the others the diagnosis', () {
      const key = 'ind.praes.akt.3.sg';
      var otherType = 0;
      for (final e in built(
        ExerciseKind.deLatWahl,
        amare,
        'ind.praes.akt',
        unlocked: _bundles(amare),
        forms: const FakeGermanForms(),
        seeds: 60,
      )) {
        final answer = e.answer as ChoiceAnswer;
        for (final o in answer.options) {
          expect(o.lexemeId, amare.id);
          final wrongBy = o.builtWrongBy;
          if (wrongBy == null) {
            expect(
              amare.accepts(amare.formOrder.indexOf(o.formKey), o.text),
              isTrue,
            );
          } else {
            otherType++;
            expect(wrongBy, isA<EndingOfOtherType>());
            expect(o.formKey, answer.right.formKey);
          }
        }
      }
      expect(otherType, greaterThan(0), reason: key);
    });

    test('too few neighbours cannot be built', () {
      final item = _hand({
        'ind.praes.akt.2.pl': ['vocatis'],
      });
      expect(choices(item), isEmpty);
    });

    test('a neighbour without German text is never offered', () {
      final item = _hand(neighbours);
      final answers = choices(
        item,
        kind: ExerciseKind.latDeWahl,
        forms: _GermanByKey({
          for (final k in item.formOrder) k: 'g@$k',
        }, covered: item.formOrder.toSet()..remove('ind.fut.akt.2.pl')),
      );
      for (final a in answers) {
        expect(
          a.options.map((o) => o.text),
          isNot(contains('g@ind.fut.akt.2.pl')),
        );
      }
    });

    test('a target without German text cannot be built', () {
      final item = _hand(neighbours);
      final forms = _GermanByKey({
        for (final k in item.formOrder) k: 'g@$k',
      }, covered: item.formOrder.toSet()..remove(_target));
      for (final e in built(
        ExerciseKind.latDeWahl,
        item,
        bundleOf(item, _target),
        unlocked: _bundles(item),
        forms: forms,
      )) {
        expect((e.answer as ChoiceAnswer).right.formKey, isNot(_target));
      }
    });
  });

  group('attribution of the built exercises', () {
    const good = (word: Rating.good, grammar: Rating.good);
    const grammarOnly = (word: Rating.good, grammar: Rating.again);
    const neither = (word: Rating.again, grammar: Rating.again);

    for (final kind in [
      ExerciseKind.formBilden,
      ExerciseKind.deLatTippen,
      ExerciseKind.umformen,
      ExerciseKind.formenKette,
      ExerciseKind.fehlerFinden,
    ]) {
      test('$kind: the shown spelling and every variant are right, another '
          'form blames the grammar, gibberish blames both', () {
        final bundle = kind == ExerciseKind.fehlerFinden
            ? 'ind.perf.pass'
            : 'ind.praes.pass';
        final e = build(kind, audire, bundle, unlocked: _bundles(audire));
        final answer = e.answer as TypedAnswer;
        Attribution reply(String text) => attribute(audire, e, TypedText(text));
        expect(reply(answer.expected.text), good);
        for (final spelling in answer.accepted) {
          expect(reply(spelling), good);
        }
        expect(reply('qqqq'), neither);
        final other = audire.forms.firstWhere(
          (f) => !answer.accepted.map(norm).contains(norm(f)),
        );
        expect(reply(other), grammarOnly);
      });
    }

    for (final kind in [
      ExerciseKind.latDeWahl,
      ExerciseKind.deLatWahl,
      ExerciseKind.irrlaeufer,
      ExerciseKind.bestimmen,
    ]) {
      test('$kind: the right option is right, a wrong real form blames the '
          'grammar', () {
        final word = kind == ExerciseKind.bestimmen ? puella : vocare;
        final bundle = kind == ExerciseKind.bestimmen
            ? puella.type
            : 'ind.praes.akt';
        for (final e in built(kind, word, bundle, unlocked: _bundles(word))) {
          final answer = e.answer as ChoiceAnswer;
          expect(attribute(word, e, ChosenOption(answer.right)), good);
          for (final o in answer.options) {
            if (identical(o, answer.right)) continue;
            expect(
              attribute(word, e, ChosenOption(o)),
              grammarOnly,
              reason: '$kind ${o.formKey}',
            );
          }
        }
      });
    }

    test('deLatWahl: a wrong ending of another type blames the grammar', () {
      final wrongs = [
        for (final e in built(
          ExerciseKind.deLatWahl,
          puella,
          puella.type,
          seeds: 60,
        ))
          for (final o in (e.answer as ChoiceAnswer).options)
            if (o.builtWrongBy != null) (e, o),
      ];
      expect(wrongs, isNotEmpty);
      for (final (e, o) in wrongs) {
        expect(attribute(puella, e, ChosenOption(o)), grammarOnly);
      }
    });
  });
}

class _SameGerman implements GermanForms {
  @override
  bool covers(PracticeItem item, FormKey key) => true;

  @override
  String render(PracticeItem item, FormKey key) => 'immer gleich';

  @override
  List<String> accepted(PracticeItem item, FormKey key) => [render(item, key)];
}
