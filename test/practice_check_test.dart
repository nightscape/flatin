import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/providers/practice_providers.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/hand_items.dart';
import 'support/word_classification_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final item = handItem(
    dataFileId: 'verbs',
    lemma: 'amāre',
    axes: fullVerbAxes,
    forms: {
      'ind.perf.akt.3.sg': ['amāvit'],
      'ind.perf.akt.3.pl': ['amāvērunt', 'amāvēre'],
    },
  );

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  /// Grades [answers] against the two forms above.
  PracticeState check(List<String> answers) {
    container.read(practiceProvider(item).notifier).checkAnswers(
          answers,
          item.formOrder,
          selectedTranslation: item.translation,
          correctTranslation: item.translation,
        );
    return container.read(practiceProvider(item));
  }

  test('a spelling without quantity marks is right', () {
    final state = check(['amavit', '']);
    expect(state.validationResults[0], isTrue);
  });

  test('a second accepted spelling is right', () {
    final state = check(['', 'amāvēre']);
    expect(state.validationResults[1], isTrue);
  });

  test('another word is wrong', () {
    final state = check(['amavet', '']);
    expect(state.validationResults[0], isFalse);
  });

  test('an empty field is neither right nor wrong', () {
    final state = check(['', '']);
    expect(state.validationResults, [null, null]);
  });

  testWidgets('the screen shows the quantity marks of a right answer',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(wrapInApp(
      PracticeScreen(item: item),
      forcedLocale: const Locale('de'),
    ));
    await letItLoad(tester);

    await tester.enterText(find.byType(TextField).at(0), 'amavit');
    await tester.enterText(find.byType(TextField).at(1), 'amāvērunt');
    await tester.tap(find.byKey(const Key('practice.check.button')));
    await tester.pump();

    expect(find.byKey(const Key('macrons.ind.perf.akt.3.sg')), findsOneWidget);
    expect(find.byKey(const Key('macrons.ind.perf.akt.3.pl')), findsNothing);
    expect(find.text('Richtig. Mit Längenzeichen: amāvit'), findsOneWidget);
  });
}
