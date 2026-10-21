import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/hand_items.dart';
import 'support/word_classification_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('full translation keeps every meaning group', () async {
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
    String of(List items, String lemma) =>
        items.firstWhere((i) => i.lemma == lemma).translation;

    expect(of(verbs, 'āmittere'), contains('verlieren'));
    expect(of(verbs, 'capere'), contains('erobern'));
    expect(of(nouns, 'fīnis'), contains('das Ende'));
  });

  testWidgets('a long full translation wraps in the translation choice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final item = handItem(
      dataFileId: 'verbs',
      lemma: 'amāre',
      axes: fullVerbAxes,
      forms: {
        'ind.perf.akt.3.sg': ['amāvit'],
      },
      translation:
          'zu Grabe tragen; hochheben; loben; wegbringen; hinausschaffen; erheben',
    );

    await tester.pumpWidget(
      wrapInApp(PracticeScreen(item: item), forcedLocale: const Locale('de')),
    );
    await letItLoad(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text(item.translation).last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(item.translation), findsOneWidget);
  });
}
