import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';
import 'package:latin_practice/services/reward_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/explanation_harness.dart' show pickOption;
import 'support/word_classification_harness.dart';

Future<int> coins(WidgetTester tester) async =>
    (await tester.runAsync(RewardStorage.load))!.points;

/// Lets the reward save and stops while the coin burst is still on screen.
Future<void> _midBurst(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late PracticeItem dominus;
  late PracticeItem amare;

  setUpAll(() async {
    dominus = (await loadPracticeItems(
      'lib/data/latin_nouns.yaml',
    )).firstWhere((i) => i.lemma == 'dominus');
    amare = (await loadPracticeItems(
      'lib/data/latin_verbs.yaml',
    )).firstWhere((i) => i.lemma == 'amāre');
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('practice screen', () {
    /// Checks [answers] (form key to answer) for [item], by default dominus;
    /// every other field stays empty.
    Future<void> checkPractice(
      WidgetTester tester,
      Map<String, String> answers, {
      PracticeItem? item,
    }) async {
      item ??= dominus;
      tester.view.physicalSize = const Size(1200, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapInApp(PracticeScreen(item: item), forcedLocale: const Locale('de')),
      );
      await letItLoad(tester);
      for (final MapEntry(:key, :value) in answers.entries) {
        final field = find.byType(TextField).at(item.formOrder.indexOf(key));
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }
      await tester.tap(find.byKey(const Key('practice.check.button')));
      await _midBurst(tester);
    }

    testWidgets('k right form fields earn 3k coins', (tester) async {
      await checkPractice(tester, {
        'gen.sg': 'dominī',
        'dat.sg': 'dominō',
        'dat.pl': 'dominīs',
      });
      expect(await coins(tester), 9);
      expect(find.text('🪙 +9'), findsOneWidget);
    });

    testWidgets('the noun field that the heading shows pays nothing', (
      tester,
    ) async {
      await checkPractice(tester, {'nom.sg': 'dominus', 'gen.sg': 'dominī'});
      expect(await coins(tester), 3);
    });

    testWidgets('the verb field that the heading shows pays nothing', (
      tester,
    ) async {
      await checkPractice(tester, {
        'inf.praes.akt': 'amare',
        'ind.praes.akt.3.sg': 'amat',
      }, item: amare);
      expect(await coins(tester), 3);
    });

    testWidgets(
      'a verb field whose answer a principal part shows pays nothing',
      (tester) async {
        await checkPractice(tester, {
          'sup.akk': 'amātum',
          'ind.praes.akt.3.sg': 'amat',
        }, item: amare);
        expect(await coins(tester), 3);
      },
    );

    testWidgets('a participle pays unless all its answers are shown', (
      tester,
    ) async {
      await checkPractice(tester, {
        'part.perf.pass.sg.nom.n': 'amātum',
        'part.perf.pass.sg.nom.m': 'amātus',
        'inf.perf.pass': 'amātum esse',
      }, item: amare);
      expect(await coins(tester), 6);
    });

    test('a field with one answer not shown pays', () async {
      final crudelis = (await loadPracticeItems(
        'lib/data/latin_nouns.yaml',
      )).firstWhere((i) => i.lemma == 'crūdēlis');
      // crūdēlīs equals the lemma without macrons; crūdēlēs is not shown.
      expect(
        crudelis.acceptedForms[crudelis.formOrder.indexOf('akk.pl.m.pos')],
        ['crūdēlēs', 'crūdēlīs'],
      );
      expect(paysCoins(crudelis, 'akk.pl.m.pos'), isTrue);
      expect(paysCoins(crudelis, 'nom.sg.m.pos'), isFalse);
    });

    testWidgets('wrong and empty fields earn nothing', (tester) async {
      await checkPractice(tester, {'gen.sg': 'dominī', 'dat.sg': 'dominī'});
      expect(await coins(tester), 3);
    });

    testWidgets('a checked answer cannot be checked again', (tester) async {
      await checkPractice(tester, {'gen.sg': 'zzz'});
      expect(await coins(tester), 0);
      expect(find.byKey(const Key('practice.check.button')), findsNothing);
    });
  });

  group('word classification', () {
    /// Shows the form [shownKey] of dominus and checks [picks].
    Future<void> classify(
      WidgetTester tester,
      String shownKey,
      List<(String kasus, String numerus)> picks,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapInApp(
          WordClassificationScreen(item: dominus, formKey: shownKey),
          forcedLocale: const Locale('de'),
        ),
      );
      await letItLoad(tester);
      for (final (i, (kasus, numerus)) in picks.indexed) {
        if (i > 0) {
          await tester.tap(find.byIcon(Icons.add));
          await tester.pumpAndSettle();
        }
        await pickOption(tester, 2 * i, kasus);
        await pickOption(tester, 2 * i + 1, numerus);
      }
      await tester.tap(
        find.byKey(const Key('wordClassification.check.button')),
      );
      await _midBurst(tester);
    }

    testWidgets('each right combination earns 3 per dropdown', (tester) async {
      await classify(tester, 'gen.sg', [
        ('Genitiv', 'Singular'),
        ('Nominativ', 'Plural'),
      ]);
      expect(await coins(tester), 12);
      expect(find.text('🪙 +12'), findsOneWidget);
    });

    testWidgets('a partly wrong combination pays its right dropdowns', (
      tester,
    ) async {
      await classify(tester, 'gen.sg', [('Genitiv', 'Plural')]);
      expect(await coins(tester), 3);
    });

    testWidgets('the best matching analysis decides for an ambiguous form', (
      tester,
    ) async {
      // dominīs is Dativ and Ablativ Plural; Ablativ agrees only with the second.
      await classify(tester, 'dat.pl', [('Ablativ', 'Singular')]);
      expect(await coins(tester), 3);
    });

    testWidgets('an analysis pays only its best matching combination', (
      tester,
    ) async {
      // dominō is Dativ and Ablativ Singular; Dativ Plural only fits the Dativ.
      await classify(tester, 'dat.sg', [
        ('Dativ', 'Singular'),
        ('Dativ', 'Plural'),
      ]);
      expect(await coins(tester), 6);
    });

    testWidgets('a repeated combination pays once', (tester) async {
      await classify(tester, 'gen.sg', [
        ('Genitiv', 'Singular'),
        ('Genitiv', 'Singular'),
      ]);
      expect(await coins(tester), 6);
    });

    testWidgets('a wrong answer earns nothing and cannot be checked again', (
      tester,
    ) async {
      await classify(tester, 'dat.sg', [('Akkusativ', 'Plural')]);
      expect(await coins(tester), 0);
      expect(
        find.byKey(const Key('wordClassification.check.button')),
        findsNothing,
      );
    });
  });
}
