import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';
import 'package:latin_practice/widgets/esel_panel.dart';

import 'support/word_classification_harness.dart';
import 'support/explanation_harness.dart' show pickOption;

Future<PracticeItem> _item(String asset, String lemma) async =>
    (await loadPracticeItems(asset)).firstWhere((i) => i.lemma == lemma);

Future<void> _pumpChecked(
  WidgetTester tester,
  PracticeItem item,
  String formKey,
) async {
  await seedNothingDue({});
  tester.view.physicalSize = const Size(1200, 4800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    wrapInApp(
      WordClassificationScreen(item: item, formKey: formKey),
      forcedLocale: const Locale('de'),
    ),
  );
  await letItLoad(tester);
  await pickOption(tester, 0, 'Genitiv');
  await pickOption(tester, 1, 'Plural');
  await tester.tap(find.byKey(const Key('wordClassification.check.button')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'dominī: the one panel is headed by all its labels joined by " / "',
    (tester) async {
      final item = await _item('lib/data/latin_nouns.yaml', 'dominus');
      await _pumpChecked(tester, item, 'nom.pl');

      final titles = tester
          .widgetList<EselStaticSteps>(find.byType(EselStaticSteps))
          .map((w) => w.title)
          .toList();

      expect(titles, hasLength(1));
      expect(
        titles.single,
        isNot(contains(',')),
        reason: 'labels of one group must be joined with " / ", not ", "',
      );
      expect(
        titles.single,
        'Nominativ Plural / Genitiv Singular / Vokativ Plural',
      );
    },
  );
}
