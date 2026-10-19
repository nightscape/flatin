import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/screens/language_screen.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:latin_practice/screens/settings_screen.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/i18n_keys.dart';
import 'support/locale_harness.dart';

final _keyShape = RegExp(r'^[a-z][A-Za-z]*(\.[A-Za-z]+)+$');

Iterable<String> _renderedTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '');

void main() {
  testWidgets('every screen renders translated text under the offered locale', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final keys = translationKeys('de');
    final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final noun = nouns.firstWhere((item) => item.lemma == 'rosa');
    final verb = verbs.first;
    tester.view.physicalSize = const Size(1200, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpAppOnDevice(tester, const Locale('en', 'US'));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final screens = <String, Widget>{
      'home': const SizedBox.shrink(),
      'practice noun': PracticeScreen(item: noun),
      'practice verb': PracticeScreen(item: verb),
      'classification': WordClassificationScreen(item: noun, formKey: 'nom.sg'),
      'settings': const SettingsScreen(),
      'language': const LanguageScreen(),
    };

    for (final entry in screens.entries) {
      if (entry.key != 'home') {
        navigator.push(MaterialPageRoute<void>(builder: (_) => entry.value));
        await settle(tester);
      }
      final texts = _renderedTexts(tester).toList();
      expect(texts, isNotEmpty, reason: entry.key);
      for (final text in texts) {
        expect(
          keys.contains(text) || _keyShape.hasMatch(text),
          isFalse,
          reason: '${entry.key} shows the key "$text"',
        );
      }
      if (entry.key != 'home') navigator.pop();
      await settle(tester);
    }
  });
}
