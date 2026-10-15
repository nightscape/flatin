import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:latin_practice/screens/practice_screen.dart';

import 'support/word_classification_harness.dart';

// A second widget test in this file never starts, so the home entries are
// covered in home_screen_filter_test.dart.
void main() {
  testWidgets('the drawer entries honour the type selection', (tester) async {
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    final verbs = await getFormMetadata('lib/data/latin_verbs.yaml');
    final enabledType = nouns.availableTypes.first;
    await seedNothingDue({
      'nouns': nouns.availableTypes.skip(1).toSet(),
      'verbs': verbs.availableTypes.toSet(),
    });

    await tester.pumpWidget(wrapInApp(const HomeScreen()));
    await letItLoad(tester);

    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await letItLoad(tester);

    expect(
      tester.widget<ListTile>(find.byKey(const Key('drawer.verbs'))).enabled,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('drawer.nouns')));
    await letItLoad(tester);

    final opened = tester.widget<PracticeScreen>(find.byType(PracticeScreen));
    expect(opened.item.type, enabledType);
  });
}
