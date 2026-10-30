import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/exercise_feedback.dart';
import 'package:latin_practice/data/exercise_interpreter.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/exercise_spec.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/screens/exercise_match_widget.dart';

import 'support/exercise_fakes.dart';
import 'support/word_classification_harness.dart';

final _zuordnen =
    generatorFor(ExerciseKind.zuordnen, exerciseGenerators) as SpecGenerator;

KindSpec get _spec => _zuordnen.agreement!;
SpecGenerator get _generator => SpecGenerator(_spec);

/// The case, number and gender readings of [text] as a form of [word], read
/// from the data alone.
Set<(String, String, String)> _readings(PracticeItem word, String text) => {
  for (var i = 0; i < word.formOrder.length; i++)
    if (word.acceptedForms[i].contains(text))
      if (word.formLabels[i].features case {
        'kasus': final k,
        'numerus': final n,
      })
        for (final g in switch (word.formLabels[i].features['genus']) {
          final g? => [g],
          null => word.genus,
        })
          (k, n, g),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<PracticeItem> nouns;
  late List<PracticeItem> enNouns;
  late PracticeItem hic, rosa, templum, dominus;
  setUpAll(() async {
    nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
    enNouns = await loadPracticeItems(
      'lib/data/latin_nouns.yaml',
      language: 'en',
    );
    PracticeItem item(String id) => nouns.singleWhere((i) => i.id == id);
    hic = item('nouns:hic');
    rosa = item('nouns:rosa');
    templum = item('nouns:templum');
    dominus = item('nouns:dominus');
  });

  /// A context over [pool] in which [hic] practises only [hicKeys].
  ExerciseContext ctx(List<PracticeItem> pool, Set<FormKey> hicKeys) =>
      ExerciseContext(
        unlocked: {for (final w in pool) w.type},
        pool: pool,
        german: fakeExerciseContext().german,
        formPracticed: (word, label) =>
            word.id != hic.id || hicKeys.contains(label.key),
      );

  /// The texts of each pair of [e].
  List<(String, String)> textsOf(Exercise e) => [
    for (final (l, r) in (e.answer as MatchingAnswer).pairs) (l.text, r.text),
  ];

  /// The round of [hic] with [hicKeys] practised over [pool]; it is valid and
  /// its right pairs rate Good.
  Exercise round(List<PracticeItem> pool, Set<FormKey> hicKeys) {
    final c = ctx(pool, hicKeys);
    final e = _generator.build(hic, hic.type, c, Random(0));
    expect(_generator.objections(e, hic, hic.type, c), isEmpty);
    expect(
      attribute(hic, e, MatchedPairs((e.answer as MatchingAnswer).pairs)),
      (word: Rating.good, grammar: Rating.good),
    );
    return e;
  }

  group('agreement goes by spelling', () {
    test('haec pairs with templa in one round and with rosa in another', () {
      expect(
        textsOf(
          round(
            [hic, templum],
            {'nom.pl.n', 'nom.sg.n', 'gen.sg.n', 'gen.pl.n'},
          ),
        ),
        unorderedEquals([
          ('haec', 'templa'),
          ('hoc', 'templum'),
          ('huius', 'templī'),
          ('hōrum', 'templōrum'),
        ]),
      );
      expect(
        textsOf(
          round([hic, rosa], {'nom.sg.f', 'akk.sg.f', 'akk.pl.f', 'gen.pl.f'}),
        ),
        unorderedEquals([
          ('haec', 'rosa'),
          ('hanc', 'rosam'),
          ('hās', 'rosās'),
          ('hārum', 'rosārum'),
        ]),
      );
    });

    test('hae pairs with rosae, whose first reading is the genitive', () {
      expect(rosa.forms[rosa.formOrder.indexOf('gen.sg')], 'rosae');
      final e = round(
        [hic, rosa],
        {'nom.pl.f', 'akk.sg.f', 'akk.pl.f', 'abl.sg.f'},
      );
      expect(
        textsOf(e),
        unorderedEquals([
          ('hae', 'rosae'),
          ('hanc', 'rosam'),
          ('hās', 'rosās'),
          ('hāc', 'rosā'),
        ]),
      );
    });

    test('a pair wrong in case, number or gender rates the grammar Again', () {
      final e = round(
        [hic, rosa, dominus],
        {'akk.sg.f', 'akk.sg.m', 'akk.pl.f', 'abl.sg.f'},
      );
      final pairs = (e.answer as MatchingAnswer).pairs;
      expect(
        textsOf(e),
        unorderedEquals([
          ('hanc', 'rosam'),
          ('hunc', 'dominum'),
          ('hās', 'rosās'),
          ('hāc', 'rosā'),
        ]),
      );
      final hanc = pairs.singleWhere((p) => p.$1.text == 'hanc');
      for (final (wrong, axis) in [
        ('rosā', 'case'),
        ('rosās', 'number'),
        ('dominum', 'gender'),
      ]) {
        final other = pairs.singleWhere((p) => p.$2.text == wrong);
        final given = MatchedPairs([
          for (final p in pairs)
            identical(p, hanc)
                ? (p.$1, other.$2)
                : identical(p, other)
                ? (p.$1, hanc.$2)
                : p,
        ]);
        expect(attribute(hic, e, given), (
          word: Rating.good,
          grammar: Rating.again,
        ), reason: axis);
        expect(
          feedbackLines(hic, e, given).map((l) => l.key),
          containsAll([
            'exercise.feedback.agreesNot',
            'exercise.feedback.agrees',
          ]),
          reason: axis,
        );
      }
    });
  });

  test('zuordnen asks a pronoun both ways and a noun its own way only', () {
    final pool = [hic, ...nouns.where((w) => w.genus.isNotEmpty)];
    final c = ExerciseContext(
      unlocked: {for (final w in pool) w.type},
      pool: pool,
      german: fakeExerciseContext().german,
    );
    final keys = <String>{};
    for (var seed = 0; seed < 40; seed++) {
      try {
        keys.add(_zuordnen.build(hic, hic.type, c, Random(seed)).questionKey);
      } on CannotBuild {
        keys.add('none');
      }
    }
    expect(keys, contains(_spec.questionKey));
    for (var seed = 0; seed < 10; seed++) {
      expect(
        _zuordnen.build(rosa, rosa.type, c, Random(seed)).questionKey,
        isNot(_spec.questionKey),
      );
    }
  });

  test('every agreeing type has a word', () {
    final types = {for (final w in nouns) w.type};
    expect((_spec.answer as Match).agreeing.difference(types), isEmpty);
  });

  // Generators: every agreeing word, against all nouns and against each noun
  // alone; every form practised, or a random half of the forms. The oracle
  // reads the readings from the data, not from the interpreter.
  test('every agreeing word builds a round with each noun or says why', () {
    final agreeing = [
      for (final w in nouns)
        if ((_spec.answer as Match).agreeing.contains(w.type)) w,
    ];
    final partners = [
      for (final w in nouns)
        if (w.genus.isNotEmpty &&
            w.derivation.grammar.classByType[w.type] == 'deklination')
          w,
    ];
    final byId = {for (final w in nouns) w.id: w};
    var built = 0, declined = 0;
    for (final word in agreeing) {
      for (final (i, pool) in [
        partners,
        ...partners.map((n) => [n]),
      ].indexed) {
        final rng = Random(i);
        final practised = {
          for (final w in [word, ...pool])
            for (final key in w.formOrder)
              if (i.isEven || rng.nextBool()) '${w.id}@$key',
        };
        final c = ExerciseContext(
          unlocked: {word.type, for (final w in pool) w.type},
          pool: [word, ...pool],
          german: fakeExerciseContext().german,
          formPracticed: (w, label) =>
              practised.contains('${w.id}@${label.key}'),
        );
        final Exercise e;
        try {
          e = _generator.build(word, word.type, c, Random(i));
        } on CannotBuild catch (error) {
          expect(error.reason, isNotEmpty);
          declined++;
          continue;
        }
        built++;
        expect(_generator.objections(e, word, word.type, c), isEmpty);
        final pairs = (e.answer as MatchingAnswer).pairs;
        for (final (a, (l, _)) in pairs.indexed) {
          expect(l.lexemeId, word.id);
          for (final (b, (_, r)) in pairs.indexed) {
            final noun = byId[r.lexemeId]!;
            expect(partners, contains(noun));
            expect(
              _readings(
                word,
                l.text,
              ).intersection(_readings(noun, r.text)).isNotEmpty,
              a == b,
              reason: '${word.id}: ${l.text} with ${r.text} in ${textsOf(e)}',
            );
          }
        }
      }
    }
    // ignore: avoid_print
    print('agreement rounds: $built built, $declined declined');
    expect(built, greaterThan(agreeing.length));
  });

  testWidgets('match, undo and check a round at 360x640', (tester) async {
    PracticeItem item(String id) => enNouns.singleWhere((i) => i.id == id);
    final enHic = item(hic.id);
    final e = _generator.build(
      enHic,
      hic.type,
      ctx(
        [enHic, item(rosa.id)],
        {'nom.pl.f', 'akk.sg.f', 'akk.pl.f', 'abl.sg.f'},
      ),
      Random(0),
    );
    final pairs = (e.answer as MatchingAnswer).pairs;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final responses = <MatchedPairs>[];
    await tester.pumpWidget(
      wrapInApp(
        ExerciseMatchWidget(
          word: enHic,
          exercise: e,
          onResponse: responses.add,
        ),
        forcedLocale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tapKey(String key) async {
      final button = find.byKey(Key(key));
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
    }

    Future<void> scrollTo(Finder finder) => tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.text('Match the forms that agree in case, number and gender'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Tap a form on the left first, then the noun form that agrees with it.',
      ),
      findsOneWidget,
    );
    await tapKey('exercise.match.left.0');
    await tapKey('exercise.match.right.1');
    expect(find.textContaining('1 · '), findsNWidgets(2));
    await tapKey('exercise.match.left.0');
    expect(find.textContaining('1 · '), findsNothing);
    for (var i = 0; i < pairs.length; i++) {
      await tapKey('exercise.match.left.$i');
      await tapKey('exercise.match.right.$i');
    }
    await tapKey('exercise.check.button');
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);
    final line = find.text('hae rosae – feminine: Nominative Plural');
    await scrollTo(line);
    expect(line, findsOneWidget);
    final next = find.byKey(const Key('exercise.next.button'));
    await scrollTo(next);
    await tester.tap(next);
    final (hae, rosae) = pairs.singleWhere((p) => p.$1.text == 'hae');
    expect(
      responses.single.pairs.any(
        (p) => identical(p.$1, hae) && identical(p.$2, rosae),
      ),
      isTrue,
    );
    expect(attribute(enHic, e, responses.single), (
      word: Rating.good,
      grammar: Rating.good,
    ));
  });
}
