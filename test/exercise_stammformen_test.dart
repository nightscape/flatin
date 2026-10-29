import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' show Rating;
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/exercise_choice.dart';
import 'package:latin_practice/data/exercise_feedback.dart';
import 'package:latin_practice/data/exercise_interpreter.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/exercise_spec.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/exercise_invariants.dart';

final _threshold = buildingChanceFrom.last.stability;

/// Mostly known cards, so that a whole row is known often enough.
final _stabilities = [
  null,
  1.0,
  _threshold - 0.01,
  for (var i = 0; i < 5; i++) ...[_threshold, 30.0],
];

SpecGenerator get _generator =>
    generatorFor(ExerciseKind.stammformen, exerciseGenerators) as SpecGenerator;

const _rowKeys = [
  'inf.praes.akt',
  'ind.praes.akt.1.sg',
  'ind.perf.akt.1.sg',
  'sup.akk',
];

List<String> get _promptsFrom =>
    (_generator.spec.select as PrincipalParts).promptsFrom;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<PracticeItem> verbs;
  PracticeItem verb(String id) => verbs.singleWhere((v) => v.id == 'verbs:$id');

  setUpAll(() async {
    verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
  });

  /// [word]'s word card and the grammar cards of its row at [known]
  /// stability, the cards in [weak] at [weakAt].
  ExerciseContext ctx(
    PracticeItem word, {
    required double? known,
    Set<String> weak = const {},
    double? weakAt,
    List<PracticeItem>? pool,
  }) => ExerciseContext(
    unlocked: {for (final k in word.formOrder) bundleOf(word, k)},
    pool: pool ?? [word],
    german: const FakeGermanForms(),
    stabilityOf: (id) => weak.contains(id) ? weakAt : known,
  );

  Exercise build(
    PracticeItem word,
    ExerciseContext c, {
    GrammarBundle bundle = 'ind.perf.akt',
    int seed = 0,
  }) => _generator.build(word, bundle, c, Random(seed));

  PartsAnswer parts(Exercise e) => e.answer as PartsAnswer;
  List<FormKey> slotKeys(Exercise e) => [
    for (final s in parts(e).slots) s.answer.expected.formKey,
  ];
  List<FormKey> shownKeys(Exercise e) {
    final keys = slotKeys(e);
    for (final g in parts(e).given) {
      keys.insert(g.at, g.form.formKey);
    }
    return keys;
  }

  group('the prompt', () {
    test('below the threshold is the infinitive, never a slot answer', () {
      final e = build(verb('cognoscere'), ctx(verb('cognoscere'), known: null));
      expect(parts(e).prompt.text, 'cōgnōscere');
      expect(e.questionParams, {'form': 'cōgnōscere'});
      expect(slotKeys(e), _rowKeys.skip(1));
      expect(
        [for (final s in parts(e).slots) s.answer.expected.text],
        ['cōgnōscō', 'cōgnōvī', 'cōgnitum'],
      );
    });

    test('from the threshold on is a form of the row past the present, and '
        'the whole row is shown', () {
      final word = verb('cognoscere');
      final prompts = <FormKey>{};
      for (final bundle in {for (final k in _rowKeys) bundleOf(word, k)}) {
        for (var seed = 0; seed < 40; seed++) {
          final e = build(
            word,
            ctx(word, known: _threshold),
            bundle: bundle,
            seed: seed,
          );
          prompts.add(parts(e).prompt.formKey);
          expect(shownKeys(e), _rowKeys);
        }
      }
      expect(prompts, contains('ind.perf.akt.1.sg'));
      expect(prompts, contains('sup.akk'));
      expect(
        prompts.where((k) => k.startsWith('part.perf.pass.')),
        hasLength(greaterThan(3)),
        reason: 'inflected PPP forms are drawn',
      );
      expect(
        prompts.every(
          (k) =>
              k == 'ind.perf.akt.1.sg' ||
              k == 'sup.akk' ||
              k.startsWith('part.perf.pass.'),
        ),
        isTrue,
        reason: '$prompts',
      );
    });

    test('one part card just below the threshold keeps the infinitive', () {
      final word = verb('cognoscere');
      for (final weak in [
        word.id,
        for (final k in _rowKeys) GrammarCardId.of(word, k) as String,
      ]) {
        for (final weakAt in [_threshold - 0.01, null]) {
          for (var seed = 0; seed < 10; seed++) {
            final e = build(
              word,
              ctx(word, known: 100, weak: {weak}, weakAt: weakAt),
              seed: seed,
            );
            expect(
              parts(e).prompt.formKey,
              'inf.praes.akt',
              reason: '$weak at $weakAt',
            );
          }
        }
      }
    });

    test('a spelling another verb of the pool also has is no prompt', () {
      final habere = verb('habere');
      final habitare = verb('habitare');
      final clashing = {
        for (final (i, k) in habere.formOrder.indexed)
          if (habitare.acceptedForms.any(
            (fs) => fs.any((f) => norm(f) == norm(habere.forms[i])),
          ))
            k,
      };
      expect(clashing, contains('part.perf.pass.sg.nom.f'));
      Set<FormKey> prompts(List<PracticeItem> pool) => {
        for (var seed = 0; seed < 200; seed++)
          parts(
            build(habere, ctx(habere, known: 30, pool: pool), seed: seed),
          ).prompt.formKey,
      };
      expect(prompts([habere]).intersection(clashing), isNotEmpty);
      expect(prompts([habere, habitare]).intersection(clashing), isEmpty);
    });

    test('a verb whose row reaches a locked bundle is not drawn', () {
      final word = verb('cognoscere');
      ExerciseContext reached(Set<FormKey> keys) => ExerciseContext(
        unlocked: {for (final k in keys) bundleOf(word, k)},
        pool: [word],
        german: const FakeGermanForms(),
        stabilityOf: (_) => null,
      );
      final present = reached({'inf.praes.akt', 'ind.praes.akt.1.sg'});
      expect(
        () => _generator.build(word, 'ind.praes.akt', present, Random(0)),
        throwsA(
          isA<CannotBuild>().having(
            (x) => x.reason,
            'reason',
            contains(' is locked'),
          ),
        ),
      );
      final row = reached({..._rowKeys});
      expect(
        slotKeys(_generator.build(word, 'ind.praes.akt', row, Random(0))),
        _rowKeys.skip(1),
      );
    });

    test('a deponent row ends at the perfect', () {
      final gaudere = verb('gaudere');
      final e = build(gaudere, ctx(gaudere, known: null));
      expect(parts(e).prompt.text, 'gaudēre');
      expect(
        [for (final s in parts(e).slots) s.answer.expected.text],
        ['gaudeō', 'gāvīsus sum'],
      );
      final known = build(gaudere, ctx(gaudere, known: 30));
      expect(slotKeys(known), _rowKeys.take(3));
    });

    test('a noun has no row', () {
      final c = ExerciseContext(
        unlocked: {'A-Deklination'},
        pool: const [],
        german: const FakeGermanForms(),
      );
      return loadPracticeItems('lib/data/latin_nouns.yaml').then((nouns) {
        final puella = nouns.singleWhere((n) => n.id == 'nouns:puella');
        expect(
          () => _generator.build(puella, puella.type, c, Random(0)),
          throwsA(isA<CannotBuild>()),
        );
      });
    });
  });

  group('the check', () {
    late PracticeItem word;
    late Exercise e;
    setUp(() {
      word = verb('cognoscere');
      e = build(word, ctx(word, known: null));
    });

    Attribution rate(List<String> texts) =>
        attribute(word, e, TypedTexts(texts));
    List<String> right() => [
      for (final s in parts(e).slots) s.answer.expected.text,
    ];

    test('accepts the exact row and the row without macrons', () {
      expect(isRight(rate(right())), isTrue);
      expect(isRight(rate([for (final t in right()) norm(t)])), isTrue);
    });

    test('reads macrons as the typed kinds do', () {
      for (final (i, s) in parts(e).slots.indexed) {
        final text = norm(right()[i]);
        expect(
          isRight(rate([...right()]..[i] = text)),
          isRight(
            attribute(
              word,
              Exercise(
                wordCardId: e.wordCardId,
                grammarCardId: e.grammarCardId,
                kind: ExerciseKind.formBilden,
                questionKey: 'q',
                answer: s.answer,
              ),
              TypedText(text),
            ),
          ),
        );
      }
    });

    test('a wrong or empty slot, each in turn, rates the grammar Again', () {
      for (var i = 0; i < right().length; i++) {
        for (final wrong in ['xyz', '', right()[(i + 1) % right().length]]) {
          expect(rate([...right()]..[i] = wrong), (
            word: Rating.good,
            grammar: Rating.again,
          ), reason: 'slot $i: "$wrong"');
        }
      }
    });

    test('feedback has one line per slot at least', () {
      final lines = feedbackLines(
        word,
        e,
        TypedTexts([...right()]..[1] = 'xyz'),
      );
      expect(lines.length, greaterThanOrEqualTo(right().length));
    });
  });

  test('a part given as the prompt earns its bundle no grammar rating', () {
    for (final id in ['venire', 'amare']) {
      final word = verb(id);
      for (final bundle in ['ind.perf.akt', 'sup']) {
        for (var seed = 0; seed < 40; seed++) {
          final e = build(
            word,
            ctx(word, known: _threshold),
            bundle: bundle,
            seed: seed,
          );
          final asked = {
            for (final s in parts(e).slots)
              bundleOf(word, s.answer.expected.formKey),
          };
          if (asked.contains(bundle)) continue;
          final right = TypedTexts([
            for (final s in parts(e).slots) s.answer.expected.text,
          ]);
          expect(
            attribute(word, e, right).grammar,
            isNull,
            reason: '${word.id}: prompt ${parts(e).prompt.text} in $bundle',
          );
        }
      }
    }
  });

  test('over every verb and bundle the generator builds a valid exercise or '
      'declines, and the stability rule holds', () {
    final rng = Random(320);
    final reasons = <String>{};
    final invalid = <String>[];
    final built = {'infinitive': 0, 'other': 0, 'clash': 0, 'locked': 0};
    final owners = <String, Set<String>>{};
    for (final v in verbs) {
      for (final spellings in v.acceptedForms) {
        for (final s in spellings) {
          (owners[norm(s)] ??= {}).add(v.id);
        }
      }
    }
    Set<String> othersWriting(PracticeItem word, String text) =>
        owners[norm(text)]!.difference({word.id});
    // Few pools, as the spelling index is built once per pool.
    final pools = [
      for (final share in [0.25, 0.5, 0.75, 0.9])
        [
          for (final v in verbs)
            if (rng.nextDouble() < share) v,
        ],
    ];
    // The pool without the other verbs that write a prompt spelling of the
    // word, so that the clash prompts are legal; all verbs when there are none.
    final withoutPartners = {
      for (final word in verbs)
        word: () {
          final partners = {
            for (final (i, k) in word.formOrder.indexed)
              if (_promptsFrom.any(k.startsWith))
                ...othersWriting(word, word.forms[i]),
          };
          return partners.isEmpty
              ? verbs
              : [
                  for (final v in verbs)
                    if (!partners.contains(v.id)) v,
                ];
        }(),
    };
    for (final word in verbs) {
      final bundles = {for (final k in word.formOrder) bundleOf(word, k)};
      // Every bundle outside the row declines alike; one of them stands in.
      final asked = {
        for (final k in _rowKeys)
          if (word.formOrder.contains(k)) bundleOf(word, k),
      };
      final others = bundles.difference(asked).toList();
      // The few verbs with clash prompts get more cases, so that both pools
      // reach their clash cells.
      final repeats = identical(withoutPartners[word], verbs) ? 1 : 100;
      for (final bundle in [
        for (var i = 0; i < repeats; i++) ...[
          ...asked,
          others[rng.nextInt(others.length)],
        ],
      ]) {
        final stabilities = <String, double?>{};
        double? stabilityOf(String id) => stabilities.putIfAbsent(
          id,
          () => _stabilities[rng.nextInt(_stabilities.length)],
        );
        final dropped = {
          for (final k in word.formOrder)
            if ((_rowKeys.contains(k) || _promptsFrom.any(k.startsWith)) &&
                rng.nextInt(5) == 0)
              k,
        };
        final holding = [
          for (final p in pools)
            if (p.contains(word)) p,
        ];
        final pool = switch (rng.nextInt(4)) {
          0 => [word],
          1 when holding.isNotEmpty => holding[rng.nextInt(holding.length)],
          2 => withoutPartners[word]!,
          _ => verbs,
        };
        final c = ExerciseContext(
          unlocked: rng.nextBool()
              ? bundles
              : {
                  bundle,
                  for (final b in bundles)
                    if (rng.nextBool()) b,
                },
          pool: pool,
          german: const FakeGermanForms(),
          formPracticed: (w, l) => !dropped.contains(l.key),
          stabilityOf: stabilityOf,
        );
        final Exercise e;
        try {
          e = _generator.build(word, bundle, c, rng);
        } on CannotBuild catch (x) {
          final reason = x.reason.replaceFirst(RegExp(r'^\S+ in \S+: '), '');
          if (reason.contains(' is locked')) {
            built['locked'] = built['locked']! + 1;
          } else {
            reasons.add(reason);
          }
          continue;
        }
        final prompt = parts(e).prompt.formKey == 'inf.praes.akt'
            ? 'infinitive'
            : 'other';
        built[prompt] = built[prompt]! + 1;
        if (prompt == 'other' &&
            othersWriting(word, parts(e).prompt.text).isNotEmpty) {
          built['clash'] = built['clash']! + 1;
        }
        final why = [
          ...violations(e, _generator.spec, word, bundle, c),
          ..._generator.objections(e, word, bundle, c),
        ];
        if (why.isNotEmpty) invalid.add('${word.id} $bundle: $why');
      }
    }
    expect(invalid, isEmpty);
    expect(built['infinitive'], greaterThan(50), reason: '$built');
    expect(built['other'], greaterThan(10), reason: '$built');
    expect(built['clash'], greaterThan(0), reason: '$built');
    expect(built['locked'], greaterThan(0), reason: '$built');
    expect(reasons, {'no PrincipalParts'});
  });

  test('the spec names a part for every row key', () {
    final select = _generator.spec.select as PrincipalParts;
    expect([for (final p in select.row) p.key], _rowKeys);
  });
}
