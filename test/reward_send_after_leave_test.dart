import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/providers/reward_provider.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/explanation_harness.dart' show pickOption;
import 'support/word_classification_harness.dart';

late Completer<void> _saved;
late Completer<void> _sent;

class _SlowRewards extends Rewards {
  @override
  Future<List<RewardEffect>> send(RewardEvent event) async {
    await _saved.future;
    final effects = await super.send(event);
    _sent.complete();
    return effects;
  }
}

void main() {
  late PracticeItem dominus;

  setUpAll(() async {
    dominus = (await loadPracticeItems(
      'lib/data/latin_nouns.yaml',
    )).firstWhere((i) => i.lemma == 'dominus');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _saved = Completer<void>();
    _sent = Completer<void>();
  });

  /// Opens [screen] over a home that keeps the ledger alive, as HomeScreen does.
  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapInApp(
        Consumer(
          builder: (context, ref, _) {
            ref.watch(rewardsProvider);
            return TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => screen)),
              child: const Text('go'),
            );
          },
        ),
        forcedLocale: const Locale('de'),
        overrides: [rewardsProvider.overrideWith(_SlowRewards.new)],
      ),
    );
    await letItLoad(tester);
    await tester.tap(find.text('go'));
    await letItLoad(tester);
  }

  /// Leaves the screen while the send waits, then lets the send finish.
  Future<int> leaveAndSave(WidgetTester tester, Type screen) async {
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await letItLoad(tester);
    expect(find.byType(screen), findsNothing);
    _saved.complete();
    // The save runs partly on real time, partly on the test clock.
    for (var i = 0; i < 50 && !_sent.isCompleted; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_sent.isCompleted, isTrue);
    final ledger = await tester.runAsync(
      () => ProviderScope.containerOf(
        tester.element(find.text('go')),
      ).read(rewardsProvider.future),
    );
    return ledger!.earnedOf(coins);
  }

  testWidgets('leaving the practice screen while the coins save is safe', (
    tester,
  ) async {
    await open(tester, PracticeScreen(item: dominus));
    final field = find
        .byType(TextField)
        .at(dominus.formOrder.indexOf('gen.sg'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'dominī');
    await tester.tap(find.byKey(const Key('practice.check.button')));
    expect(await leaveAndSave(tester, PracticeScreen), 3);
  });

  testWidgets('leaving the classification screen while the coins save is '
      'safe', (tester) async {
    await open(
      tester,
      WordClassificationScreen(item: dominus, formKey: 'gen.sg'),
    );
    await pickOption(tester, 0, 'Genitiv');
    await pickOption(tester, 1, 'Singular');
    await tester.tap(find.byKey(const Key('wordClassification.check.button')));
    expect(await leaveAndSave(tester, WordClassificationScreen), 6);
  });
}
