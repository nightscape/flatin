import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/esel_groups.dart';
import 'package:latin_practice/data/esel_steps.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/widgets/esel_panel.dart';

import 'support/word_classification_harness.dart';
import 'support/explanation_harness.dart' show pickOption;
import 'package:latin_practice/screens/word_classification_screen.dart';

String _answers(PracticeItem item, String key) => eselSteps(item, key)
    .map((s) => '${s.kind.name}|${s.answerKey}|${s.answer}')
    .join('\n');

Future<PracticeItem> _item(String asset, String lemma) async =>
    (await loadPracticeItems(asset)).firstWhere((i) => i.lemma == lemma);

/// Checks a wrong pick (Genitiv Plural), which is what opens the explanation.
Future<void> _pumpChecked(
  WidgetTester tester,
  PracticeItem item,
  String formKey,
) async {
  await seedNothingDue({});
  tester.view.physicalSize = const Size(1200, 4800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapInApp(
    WordClassificationScreen(item: item, formKey: formKey),
    forcedLocale: const Locale('de'),
  ));
  await letItLoad(tester);
  await pickOption(tester, 0, 'Genitiv');
  await pickOption(tester, 1, 'Plural');
  await tester.tap(find.byKey(const Key('wordClassification.check.button')));
  await tester.pumpAndSettle();
}

List<String> _titles(WidgetTester tester) => tester
    .widgetList<EselStaticSteps>(find.byType(EselStaticSteps))
    .map((w) => w.title)
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('groups partition the readings of every spelling by equal steps',
      () async {
    var checked = 0;
    for (final asset in [
      'lib/data/latin_nouns.yaml',
      'lib/data/latin_verbs.yaml',
    ]) {
      for (final item in await loadPracticeItems(asset)) {
        final answers = {for (final k in item.formOrder) k: _answers(item, k)};
        final seen = <String>{};
        for (final accepted in item.acceptedForms) {
          for (final spelling in accepted) {
            if (!seen.add(norm(spelling))) continue;
            final keys = [
              for (var i = 0; i < item.formOrder.length; i++)
                if (item.acceptedForms[i].any((f) => norm(f) == norm(spelling)))
                  item.formOrder[i],
            ];
            final groups = groupReadings(item, keys);
            final where = '${item.lemma} "$spelling"';

            expect(groups.expand((g) => g).toList()..sort(), [...keys]..sort(),
                reason: '$where: groups partition the keys');
            for (final g in groups) {
              expect(g.map((k) => answers[k]).toSet(), hasLength(1),
                  reason: '$where: equal steps within $g');
            }
            expect(groups.map((g) => answers[g.first]).toSet(),
                hasLength(groups.length),
                reason: '$where: different steps across groups');
            for (final g in groups) {
              final title = groupTitle(item, g);
              expect(title, isNot(contains(',')), reason: '$where: title');
              expect(title.split(' / '), [
                for (final k in g)
                  describeLabels([item.formLabels[item.formOrder.indexOf(k)]]),
              ], reason: '$where: title parts are the labels in formOrder');
            }
            final firsts =
                groups.map((g) => item.formOrder.indexOf(g.first)).toList();
            expect(firsts, [...firsts]..sort(),
                reason: '$where: groups ordered by first key');
            checked++;
          }
        }
      }
    }
    expect(checked, greaterThan(1000));
  });

  group('classification screen', () {
    testWidgets('templa: one panel headed by all three labels',
        (tester) async {
      final item = await _item('lib/data/latin_nouns.yaml', 'templum');
      await _pumpChecked(tester, item, 'nom.pl');

      expect(_titles(tester), ['Nominativ Plural / Akkusativ Plural / Vokativ Plural']);
      expect(find.byType(EselStaticSteps), findsOneWidget);
    });

    testWidgets('rosa: two different step sequences, two panels',
        (tester) async {
      final item = await _item('lib/data/latin_nouns.yaml', 'rosa');
      await _pumpChecked(tester, item, 'nom.sg');

      expect(_titles(tester),
          ['Nominativ Singular / Vokativ Singular', 'Ablativ Singular']);
      for (final panel in tester
          .widgetList<EselStaticSteps>(find.byType(EselStaticSteps))) {
        expect(panel.steps.length, 4);
      }
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('dominī: labels follow formOrder (kasus before numerus)',
        (tester) async {
      final item = await _item('lib/data/latin_nouns.yaml', 'dominus');
      // latin_nouns.yaml: label.tail [kasus, numerus] makes the order
      // case-major, so nom.pl comes before gen.sg.
      expect(item.formOrder.indexOf('nom.pl'),
          lessThan(item.formOrder.indexOf('gen.sg')));
      await _pumpChecked(tester, item, 'nom.pl');

      expect(_titles(tester),
          ['Nominativ Plural / Genitiv Singular / Vokativ Plural']);
    });

    testWidgets('a static panel shows no question text', (tester) async {
      final item = await _item('lib/data/latin_nouns.yaml', 'rēx');
      await _pumpChecked(tester, item, 'nom.sg');

      expect(find.text('Wörterbuchform'), findsOneWidget);
      expect(find.textContaining('ist die Wörterbuchform'), findsNothing);
    });

    testWidgets('a spelling with one reading: one panel, one label',
        (tester) async {
      final item = await _item('lib/data/latin_nouns.yaml', 'dominus');
      await _pumpChecked(tester, item, 'akk.sg');

      expect(_titles(tester), ['Akkusativ Singular']);
    });
  });
}
