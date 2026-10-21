import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/exercise_translate.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/screens/exercise_screen.dart';

import 'support/i18n_keys.dart';
import 'support/word_classification_harness.dart';

const _latDe = LatDeChoiceGenerator();
const _deLat = DeLatChoiceGenerator();
const _deLatType = DeLatTypeGenerator();
const _bundle = 'ind.praes.akt';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<PracticeItem> verbs;
  late PracticeItem vocare;
  late PracticeItem noun;
  late GrammarGermanForms german;
  setUpAll(() async {
    verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
    noun = (await loadPracticeItems('lib/data/latin_nouns.yaml')).first;
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

  ExerciseContext realCtx(Set<GrammarBundle> unlocked) =>
      ExerciseContext(unlocked: unlocked, pool: [vocare], german: german);

  Exercise build(
    ExerciseGenerator generator,
    PracticeItem item,
    GrammarBundle bundle, {
    Set<GrammarBundle>? unlocked,
    int seed = 0,
    ExerciseContext? ctx,
  }) => generator.build(
    item,
    bundle,
    ctx ?? realCtx(unlocked ?? {bundle}),
    Random(seed),
  );

  Matcher cannotBuild([String? reason]) => throwsA(
    isA<CannotBuild>().having(
      (e) => e.reason,
      'reason',
      reason == null ? isNotEmpty : contains(reason),
    ),
  );

  String latinOf(PracticeItem item, FormKey key) =>
      item.forms[item.formOrder.indexOf(key)];

  group('D1: A2 Latin to German', () {
    test('builds the German texts of forms that differ in one feature', () {
      final e = build(_latDe, vocare, _bundle, seed: 4);
      final answer = e.answer as ChoiceAnswer;
      final right = answer.right;
      expect(e.kind, ExerciseKind.latDeWahl);
      expect(e.wordCardId, vocare.id);
      expect(e.grammarCardId, GrammarCardId('verbs', _bundle));
      expect(e.questionKey, 'exercise.translate.latDe.question');
      expect(e.questionParams, {
        'form': latinOf(vocare, right.formKey),
        'word': vocare.lemma,
      });
      expect(answer.options, hasLength(4));
      for (final o in answer.options) {
        expect(o.text, german.render(vocare, o.formKey));
        expect(o.lexemeId, vocare.id);
        expect(o.builtWrongBy, isNull);
        expect(bundleOf(vocare, o.formKey), _bundle);
      }
    });

    test('the app registers it for latDeWahl', () {
      expect(
        generatorFor(ExerciseKind.latDeWahl, exerciseGenerators),
        isA<LatDeChoiceGenerator>(),
      );
    });
  });

  group('D1: A3 German to Latin', () {
    test('builds the Latin forms for a German text', () {
      final e = build(_deLat, vocare, _bundle, seed: 4);
      final answer = e.answer as ChoiceAnswer;
      final right = answer.right;
      expect(e.kind, ExerciseKind.deLatWahl);
      expect(e.wordCardId, vocare.id);
      expect(e.grammarCardId, GrammarCardId('verbs', _bundle));
      expect(e.questionKey, 'exercise.translate.deLat.question');
      expect(e.questionParams, {
        'german': german.render(vocare, right.formKey),
        'word': vocare.lemma,
      });
      expect(right.text, latinOf(vocare, right.formKey));
      expect(answer.options, hasLength(4));
      expect(
        answer.options.where((o) => o.builtWrongBy == null).map((o) => o.text),
        everyElement(
          isIn([for (final k in vocare.formOrder) latinOf(vocare, k)]),
        ),
      );
    });

    test('the app registers it for deLatWahl', () {
      expect(
        generatorFor(ExerciseKind.deLatWahl, exerciseGenerators),
        isA<DeLatChoiceGenerator>(),
      );
    });
  });

  group('D1: A7 German to Latin typing', () {
    test('builds a typed answer with the accepted spellings', () {
      final e = build(_deLatType, vocare, _bundle, seed: 4);
      final answer = e.answer as TypedAnswer;
      final key = answer.expected.formKey;
      final index = vocare.formOrder.indexOf(key);
      expect(e.kind, ExerciseKind.deLatTippen);
      expect(e.wordCardId, vocare.id);
      expect(e.grammarCardId, GrammarCardId('verbs', _bundle));
      expect(e.questionKey, 'exercise.translate.deLatType.question');
      expect(e.questionParams, {
        'german': german.render(vocare, key),
        'word': vocare.lemma,
      });
      expect(answer.expected.text, vocare.forms[index]);
      expect(answer.accepted, vocare.acceptedForms[index]);
      expect(answer.expected.builtWrongBy, isNull);
    });

    test('the app registers it for deLatTippen', () {
      expect(
        generatorFor(ExerciseKind.deLatTippen, exerciseGenerators),
        isA<DeLatTypeGenerator>(),
      );
    });

    test('amare impf and perf still build, and A7 accepts both forms', () {
      final amare = verbs.singleWhere((i) => i.id == 'verbs:amare');
      final all = {for (final k in amare.formOrder) bundleOf(amare, k)};
      final impf = latinOf(amare, 'ind.impf.akt.1.sg');
      final perf = latinOf(amare, 'ind.perf.akt.1.sg');
      var asked = false;
      for (int seed = 0; seed < 40; seed++) {
        for (final g in [_latDe, _deLat]) {
          build(g, amare, 'ind.impf.akt', unlocked: all, seed: seed);
          build(g, amare, 'ind.perf.akt', unlocked: all, seed: seed);
        }
        final e = build(
          _deLatType,
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
  });

  group('D1: cannot build', () {
    final generators = {'A2': _latDe, 'A3': _deLat, 'A7': _deLatType};

    for (final MapEntry(key: name, value: generator) in generators.entries) {
      test('$name: a bundle that is not unlocked', () {
        expect(
          () => build(generator, vocare, _bundle, unlocked: {'ind.praes.pass'}),
          cannotBuild('locked'),
        );
      });

      test('$name: no German forms', () {
        expect(
          () => build(
            generator,
            vocare,
            _bundle,
            ctx: ExerciseContext(
              unlocked: {_bundle},
              pool: [vocare],
              german: const FakeGermanForms(coversAll: false),
            ),
          ),
          cannotBuild('no German form'),
        );
      });

      test('$name: a noun', () {
        final bundle = bundleOf(noun, noun.formOrder.first);
        expect(
          () => build(generator, noun, bundle),
          cannotBuild('no German form'),
        );
      });
    }

    test('A2: wrong endings do not count as German distractors', () {
      final amare = verbs.singleWhere((i) => i.id == 'verbs:amare');
      final all = {for (final k in amare.formOrder) bundleOf(amare, k)};
      for (int seed = 0; seed < 5; seed++) {
        expect(
          () =>
              build(_latDe, amare, 'inf.praes.akt', unlocked: all, seed: seed),
          cannotBuild('has only 2 distractors'),
        );
      }
    });

    test('A2: too few German distractors', () {
      expect(
        () => build(_latDe, vocare, 'inf.praes.akt'),
        cannotBuild('distractors'),
      );
    });
  });

  group('D1: the subjunctive frame', () {
    const frames = {
      'konj.praes.pass.3.pl': 'Ich frage, ob sie (Pl.) gerufen werden.',
      'konj.perf.pass.3.pl': 'Ich frage, ob sie (Pl.) gerufen worden sind.',
      'konj.impf.pass.3.pl': 'Ich fragte, ob sie (Pl.) gerufen würden.',
      'konj.plusq.pass.3.pl': 'Ich fragte, ob sie (Pl.) gerufen worden wären.',
    };

    for (final MapEntry(key: key, value: frame) in frames.entries) {
      final tense = key.split('.')[1];
      test('$tense: A3 and A7 show the German text in the frame', () {
        final bundle = bundleOf(vocare, key);
        for (final generator in [_deLat, _deLatType]) {
          final shown = <String>{};
          for (int seed = 0; seed < 60; seed++) {
            shown.add(
              build(
                generator,
                vocare,
                bundle,
                seed: seed,
              ).questionParams['german']!,
            );
          }
          expect(shown, contains(frame), reason: '${generator.kind}');
          expect(shown, everyElement(startsWith('Ich frag')));
        }
      });

      test('$tense: A2 frames every option', () {
        final bundle = bundleOf(vocare, key);
        for (int seed = 0; seed < 20; seed++) {
          final e = build(_latDe, vocare, bundle, seed: seed);
          final texts = (e.answer as ChoiceAnswer).options.map((o) => o.text);
          expect(texts, everyElement(startsWith('Ich frag')));
          expect(texts, everyElement(endsWith('.')));
        }
      });
    }

    test('A2 frames all options or none', () {
      final unlocked = {'ind.praes.pass', 'konj.praes.pass', 'konj.impf.pass'};
      for (int seed = 0; seed < 40; seed++) {
        for (final bundle in unlocked) {
          final e = build(
            _latDe,
            vocare,
            bundle,
            unlocked: unlocked,
            seed: seed,
          );
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
        for (final generator in [_latDe, _deLat, _deLatType]) {
          expect(
            () => build(
              generator,
              vocare,
              'konj.praes.pass',
              unlocked: {'konj.impf.pass', 'konj.plusq.pass'},
            ),
            cannotBuild('locked'),
            reason: '${generator.kind}',
          );
        }
      },
    );
  });

  group('D2: attribution', () {
    const good = (word: Rating.good, grammar: Rating.good);
    const grammarOnly = (word: Rating.good, grammar: Rating.again);

    for (final generator in [_latDe, _deLat]) {
      test('${generator.kind}: right is Good/Good, a wrong form of the word '
          'blames the grammar card', () {
        final e = build(generator, vocare, _bundle, seed: 2);
        final answer = e.answer as ChoiceAnswer;
        expect(attribute(vocare, e, ChosenOption(answer.right)), good);
        for (final o in answer.options.where((o) => o.builtWrongBy == null)) {
          if (identical(o, answer.right)) continue;
          expect(attribute(vocare, e, ChosenOption(o)), grammarOnly);
        }
      });
    }

    test('A3: a wrong ending of another type blames the grammar card', () {
      for (int seed = 0; seed < 60; seed++) {
        final e = build(_deLat, vocare, _bundle, seed: seed);
        for (final o in (e.answer as ChoiceAnswer).options.where(
          (o) => o.builtWrongBy != null,
        )) {
          expect(attribute(vocare, e, ChosenOption(o)), grammarOnly);
          return;
        }
      }
      fail('no seed offered a wrong ending');
    });

    test('A7: right, another form of the word, and a miss', () {
      final e = build(_deLatType, vocare, _bundle, seed: 2);
      final expected = (e.answer as TypedAnswer).expected;
      final other = vocare.forms.firstWhere(
        (f) => norm(f) != norm(expected.text),
      );
      expect(attribute(vocare, e, TypedText(expected.text)), good);
      expect(attribute(vocare, e, TypedText(other)), grammarOnly);
      expect(attribute(vocare, e, const TypedText('xyzzy')), (
        word: Rating.again,
        grammar: Rating.again,
      ));
    });
  });

  group('D3: the generic screen', () {
    testWidgets('A2 shows the Latin form and its German options', (
      tester,
    ) async {
      final e = build(_latDe, vocare, 'konj.impf.pass', seed: 1);
      final answer = e.answer as ChoiceAnswer;
      final responses = <ExerciseResponse>[];
      await tester.pumpWidget(
        wrapInApp(
          ExerciseScreen(exercise: e, onResponse: responses.add),
          forcedLocale: const Locale('de'),
        ),
      );
      await tester.pumpAndSettle();
      final prompt = tester.widget<Text>(
        find.byKey(const Key('exercise.question')),
      );
      expect(prompt.data, contains(e.questionParams['form']!));
      for (final o in answer.options) {
        expect(find.text(o.text), findsOneWidget);
      }
      await tester.tap(find.text(answer.right.text));
      await tester.pumpAndSettle();
      expect(find.text('Richtig'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exercise.next.button')));
      expect((responses.single as ChosenOption).chosen, answer.right);
    });

    testWidgets('A3 shows the framed German text and Latin options', (
      tester,
    ) async {
      final e = build(_deLat, vocare, 'konj.impf.pass', seed: 1);
      final answer = e.answer as ChoiceAnswer;
      await tester.pumpWidget(
        wrapInApp(
          ExerciseScreen(exercise: e, onResponse: (_) {}),
          forcedLocale: const Locale('de'),
        ),
      );
      await tester.pumpAndSettle();
      final prompt = tester.widget<Text>(
        find.byKey(const Key('exercise.question')),
      );
      expect(prompt.data, contains('Ich fragte, ob'));
      final wrong = answer.options.firstWhere(
        (o) => !identical(o, answer.right),
      );
      await tester.tap(find.text(wrong.text));
      await tester.pumpAndSettle();
      expect(find.textContaining('Falsch'), findsOneWidget);
    });

    testWidgets('A7 takes the typed Latin form', (tester) async {
      final e = build(_deLatType, vocare, _bundle, seed: 1);
      final expected = (e.answer as TypedAnswer).expected.text;
      final responses = <ExerciseResponse>[];
      await tester.pumpWidget(
        wrapInApp(
          ExerciseScreen(exercise: e, onResponse: responses.add),
          forcedLocale: const Locale('de'),
        ),
      );
      await tester.pumpAndSettle();
      final prompt = tester.widget<Text>(
        find.byKey(const Key('exercise.question')),
      );
      expect(prompt.data, contains(e.questionParams['german']!));
      await tester.enterText(find.byKey(const Key('exercise.input')), expected);
      await tester.tap(find.byKey(const Key('exercise.check.button')));
      await tester.pumpAndSettle();
      expect(find.text('Richtig'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exercise.next.button')));
      expect((responses.single as TypedText).text, expected);
    });

    testWidgets('A7 shows every right form after a wrong answer', (
      tester,
    ) async {
      final amare = verbs.singleWhere((i) => i.id == 'verbs:amare');
      final all = {for (final k in amare.formOrder) bundleOf(amare, k)};
      final e = [
        for (var seed = 0; seed < 40; seed++)
          build(_deLatType, amare, 'ind.impf.akt', unlocked: all, seed: seed),
      ].firstWhere((e) => e.questionParams['german'] == 'ich liebte');
      await tester.pumpWidget(
        wrapInApp(
          ExerciseScreen(exercise: e, onResponse: (_) {}),
          forcedLocale: const Locale('de'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('exercise.input')), 'xyz');
      await tester.tap(find.byKey(const Key('exercise.check.button')));
      await tester.pumpAndSettle();
      final feedback = tester
          .widget<Text>(find.byKey(const Key('exercise.feedback')))
          .data!;
      expect(feedback, contains(latinOf(amare, 'ind.impf.akt.1.sg')));
      expect(feedback, contains(latinOf(amare, 'ind.perf.akt.1.sg')));
    });
  });

  test('D4: both languages hold the translate keys', () {
    const keys = {
      'exercise.translate.latDe.question',
      'exercise.translate.deLat.question',
      'exercise.translate.deLatType.question',
    };
    for (final code in ['de', 'en']) {
      final all = translationKeys(code);
      expect(all, containsAll(keys));
      expect(
        all.where((k) => k.startsWith('exercise.translate.')).toSet(),
        keys,
      );
    }
  });

  test(
    'D5 law: no option set has two right answers, A7 accepts exactly the matching forms',
    () {
      expect(realCtx({}).german, isA<GrammarGermanForms>());
      final items = verbs.where((v) => german.germanVerbOf.containsKey(v.id));
      final refused = <ExerciseKind, int>{};
      final built = <ExerciseKind>{};
      final bad = <String>[];
      var unbuildable = 0;
      for (final word in items) {
        final bundles = {for (final k in word.formOrder) bundleOf(word, k)};
        final ctx = realCtx(bundles);
        var builtAny = false;
        for (final bundle in bundles) {
          for (final generator in [_latDe, _deLat, _deLatType]) {
            for (var seed = 0; seed < 1; seed++) {
              final Exercise e;
              try {
                e = generator.build(word, bundle, ctx, Random(seed));
              } on CannotBuild {
                refused.update(generator.kind, (n) => n + 1, ifAbsent: () => 1);
                continue;
              }
              builtAny = true;
              built.add(generator.kind);
              final answer = e.answer;
              if (answer is ChoiceAnswer) {
                final right = answer.right;
                final prompt = generator.kind == ExerciseKind.latDeWahl
                    ? null
                    : e.questionParams['german']!;
                for (final o in answer.options) {
                  if (identical(o, right) || o.builtWrongBy != null) continue;
                  final clash = prompt == null
                      ? acceptedShown(
                              word,
                              o.formKey,
                              ctx,
                            ).contains(right.text) ||
                            acceptedShown(
                              word,
                              right.formKey,
                              ctx,
                            ).contains(o.text)
                      : acceptedShown(word, o.formKey, ctx).contains(prompt);
                  if (clash) {
                    bad.add(
                      '${word.id} ${generator.kind} ${right.formKey} ~ ${o.formKey}',
                    );
                  }
                }
              } else {
                answer as TypedAnswer;
                final shown = e.questionParams['german']!;
                final expected = {
                  for (final key in word.formOrder)
                    if (ctx.german.covers(word, key) &&
                        acceptedShown(word, key, ctx).contains(shown))
                      ...word.acceptedForms[word.formOrder.indexOf(key)],
                };
                if (answer.accepted.toSet().difference(expected).isNotEmpty ||
                    expected.difference(answer.accepted.toSet()).isNotEmpty) {
                  bad.add('${word.id} A7 $shown accepts ${answer.accepted}');
                }
              }
            }
          }
        }
        if (!builtAny) unbuildable++;
      }
      File('target/r3/refused-per-kind.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync('$refused\nverbs without any kind: $unbuildable\n');
      expect(bad, isEmpty);
      expect(unbuildable, 0);
      expect(built, {
        ExerciseKind.latDeWahl,
        ExerciseKind.deLatWahl,
        ExerciseKind.deLatTippen,
      });
    },
  );
}
