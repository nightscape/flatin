import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/screens/grammar_start_screen.dart';
import 'package:latin_practice/screens/language_screen.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:latin_practice/screens/settings_screen.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

import 'support/i18n_keys.dart';
import 'support/locale_harness.dart';

final _keyShape = RegExp(r'^[a-z][A-Za-z]*(\.[A-Za-z]+)+$');
final _word = RegExp(r'[A-Za-zÄÖÜäöüß]+');

Iterable<String> _renderedTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '');

/// The words of the translation file and the data files when they are read
/// in [language].
Set<String> _words(String language) {
  final words = <String>{};
  void walk(Object? node) {
    if (node is Map && node.containsKey(language)) {
      walk(node[language]);
    } else if (node is Map) {
      node.values.forEach(walk);
    } else if (node is List) {
      node.forEach(walk);
    } else {
      words.addAll(_word.allMatches('$node').map((m) => m[0]!.toLowerCase()));
    }
  }

  walk(
    jsonDecode(File('assets/flutter_i18n/$language.json').readAsStringSync()),
  );
  for (final path in [
    'lib/data/latin_nouns.yaml',
    'lib/data/latin_verbs.yaml',
  ]) {
    walk(loadYaml(File(path).readAsStringSync()));
  }
  return words;
}

void main() {
  for (final (device, language) in const [
    (Locale('de', 'DE'), 'de'),
    (Locale('en', 'US'), 'en'),
  ]) {
    testWidgets('every screen renders $language text on a $device device', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final keys = translationKeys(language);
      final germanOnly = language == 'de'
          ? const <String>{}
          : _words('de').difference(_words(language));
      final latin = {
        for (final words in (await loadLessonData(
          bookAssets,
        )).lessonWords.values)
          for (final word in words)
            ..._word.allMatches(word).map((m) => m[0]!.toLowerCase()),
      };
      // Grammar topic names are German course data, not UI text.
      final topicWords = {
        for (final topic in (await loadCurriculum(bookAssets)).courseTopics)
          if (topic.typeName == null)
            ..._word
                .allMatches(topic.formsName!)
                .map((m) => m[0]!.toLowerCase()),
      };
      final nouns = await loadPracticeItems(
        'lib/data/latin_nouns.yaml',
        language: language,
      );
      final verbs = await loadPracticeItems(
        'lib/data/latin_verbs.yaml',
        language: language,
      );
      final noun = nouns.firstWhere((item) => item.lemma == 'rosa');
      final verb = verbs.first;
      tester.view.physicalSize = const Size(1200, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpAppOnDevice(tester, device);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final screens = <String, Widget>{
        'home': const SizedBox.shrink(),
        'practice noun': PracticeScreen(item: noun),
        'practice verb': PracticeScreen(item: verb),
        'classification': WordClassificationScreen(
          item: noun,
          formKey: 'nom.sg',
        ),
        'grammar': const GrammarStartScreen(),
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
          final german = _word
              .allMatches(text)
              .map((m) => m[0]!)
              .where(
                (word) =>
                    germanOnly.contains(word.toLowerCase()) &&
                    !latin.contains(word.toLowerCase()) &&
                    !topicWords.contains(word.toLowerCase()),
              );
          expect(german, isEmpty, reason: '${entry.key} shows German "$text"');
        }
        if (entry.key != 'home') navigator.pop();
        await settle(tester);
      }
    });
  }
}
