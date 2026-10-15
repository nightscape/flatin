import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';

import 'support/word_classification_harness.dart';

/// Rates one item, which is all the review flow of the real screens does
/// before it reports a storage failure.
class _RateButton extends ConsumerWidget {
  const _RateButton(this.item);

  final PracticeItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () =>
              reviewCardReportingErrors(context, ref, item, Rating.good),
          child: const Text('rate'),
        ),
      ),
    );
  }
}

void main() {
  // No SharedPreferences mock is installed, so the save inside reviewCard
  // fails the way an unwritable store would.
  testWidgets('a failing save is reported to the learner', (tester) async {
    final item = (await loadPracticeItems('lib/data/latin_nouns.yaml')).first;
    final itemId = PracticeItemCard.generateItemId(item);

    await tester.pumpWidget(wrapInApp(
      _RateButton(item),
      overrides: [
        fsrsCardsProvider.overrideWith(
          (ref) async => {itemId: PracticeItemCard.createNew(item)},
        ),
      ],
    ));
    await letItLoad(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('rate'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await letItLoad(tester);

    expect(find.textContaining('Progress not saved'), findsOneWidget);
  });
}
