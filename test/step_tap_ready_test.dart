import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:latin_practice/screens/practice_screen.dart';

import 'step_definitions/app_steps.dart';
import 'support/word_classification_harness.dart';

/// The home entry stays disabled until its providers have loaded. A step that
/// taps it before then taps nothing, and the step after it reports an empty
/// practice screen — the failure a loaded machine produces. `I tap on`
/// therefore waits for the entry to become tappable.
void main() {
  testWidgets('tapping an entry whose data is still loading opens the screen', (
    tester,
  ) async {
    await seedEverythingDue(const {});
    final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');

    await tester.pumpWidget(
      wrapInApp(
        const HomeScreen(),
        overrides: [
          practicableItemsByTypeProvider.overrideWith((ref) async {
            await Future<void>.delayed(const Duration(milliseconds: 500));
            return {'nouns': nouns, 'verbs': <PracticeItem>[]};
          }),
        ],
      ),
    );
    // The steps before the tap settle the home screen, so the entry is on
    // screen — with its data still on the way.
    await tester.pump(const Duration(milliseconds: 100));
    await AppSteps().iTapOn(tester, 'home.nouns.button');

    expect(find.byType(PracticeScreen), findsOneWidget);
  });
}
