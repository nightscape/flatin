import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/settings_conversion.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/hand_items.dart';
import 'support/word_classification_harness.dart';

final item = handItem(
  dataFileId: 'verbs',
  lemma: 'amāre',
  axes: fullVerbAxes,
  forms: {
    'ind.praes.akt.3.sg': ['amat'],
    'ind.praes.pass.3.sg': ['amātur'],
    'ind.perf.akt.3.sg': ['amāvit'],
  },
);

/// The settings as they are stored once the Passive is switched off.
String storedWithoutPassive() => jsonEncode({
      settingsVersionField: settingsVersion,
      'disabledForms': <String, List<String>>{},
      'disabledFeatures': {
        'verbs': {
          'genus': ['pass'],
        },
      },
      'disabledTypes': <String, List<String>>{},
      'inputStrategyIds': <String, String>{},
      'deselectedWords': <String>[],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('switching the Passive off switches off every passive form', () {
    final settings = Settings().toggleFeature('verbs', 'genus', 'pass');

    expect(
      settings.enabledFormsOf('verbs', item.formLabels),
      {'ind.praes.akt.3.sg', 'ind.perf.akt.3.sg'},
    );
  });

  test('a form stays off while either its key or a feature is off', () {
    var settings = Settings().toggleForm('verbs', 'ind.perf.akt.3.sg');
    settings = settings.toggleFeature('verbs', 'genus', 'pass');

    expect(
      settings.enabledFormsOf('verbs', item.formLabels),
      {'ind.praes.akt.3.sg'},
    );
    expect(
      settings.enableAllForms('verbs').enabledFormsOf('verbs', item.formLabels),
      item.formOrder.toSet(),
    );
  });

  test('the classification stops asking an axis with one value left', () {
    final settings = Settings().toggleFeature('verbs', 'genus', 'pass');
    final enabled =
        settings.enabledFormsOf('verbs', item.formLabels);
    final selectors = selectorsFor(item.filterForms(enabled).labels);

    expect(selectors.sections, isNot(contains('genus')));
    expect(selectors.fixed['genus'], 'akt');
  });

  test('a stored disabled feature survives a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    await first.read(settingsProvider.future);
    await first
        .read(settingsProvider.notifier)
        .toggleFeature('verbs', 'genus', 'pass');
    first.dispose();

    final second = ProviderContainer();
    final loaded = await second.read(settingsProvider.future);
    expect(loaded.isFeatureEnabled('verbs', 'genus', 'pass'), isFalse);
    // Only switched-off values are stored, so a value the YAML gains later
    // is practised.
    expect(loaded.isFeatureEnabled('verbs', 'genus', 'med'), isTrue);
    expect(loaded.isFeatureEnabled('verbs', 'modus', 'konj'), isTrue);
    second.dispose();
  });

  testWidgets('the practice screen drops the passive rows', (tester) async {
    SharedPreferences.setMockInitialValues({
      'practice_settings': storedWithoutPassive(),
    });
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapInApp(
      PracticeScreen(item: item),
      forcedLocale: const Locale('de'),
    ));
    await letItLoad(tester);

    expect(find.text('Präsens: 3. Person Singular'), findsOneWidget);
    expect(find.text('Perfekt: 3. Person Singular'), findsOneWidget);
    expect(find.text('Präsens Passiv: 3. Person Singular'), findsNothing);
  });
}
