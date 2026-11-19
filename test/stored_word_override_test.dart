import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/settings_conversion.dart'
    show settingsVersionField;
import 'package:latin_practice/models/practice_item.dart';

import 'support/stored_settings.dart';

/// The settings version of the base the stored maps come from.
const baseSettingsVersion = 5;

/// The items whose card id keeps a text in brackets, with the word key that
/// a stored override of the item used: its lemma with that text.
Future<List<(PracticeItem, String)>> storedKeysOfBracketIds() async => [
  for (final item in await loadAllPracticeItems())
    if (RegExp(r' (\(.*\))$').firstMatch(item.id) case final m?)
      (item, '${item.lemma} ${m.group(1)}'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a word the learner switched off stays off when its lemma '
      'loses the text in brackets', (tester) async {
    final cases = (await tester.runAsync(storedKeysOfBracketIds))!;
    expect(cases, isNotEmpty);
    for (final (item, storedKey) in cases) {
      await openSettingsWith(tester, {
        settingsVersionField: baseSettingsVersion,
        'deselectedWords': [storedKey],
      }, page: 'words');
      await tester.enterText(find.byKey(const Key('words.search')), item.lemma);
      await tester.pumpAndSettle();
      expect(
        isChecked(tester, find.byKey(Key('word.${item.wordKey}'))),
        isFalse,
        reason: '${item.id}: stored as "$storedKey"',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a word the learner forced on stays on when its lemma '
      'loses the text in brackets', (tester) async {
    final cases = (await tester.runAsync(() => storedKeysOfBracketIds()))!;
    expect(cases, isNotEmpty);
    for (final (item, storedKey) in cases) {
      await openSettingsWith(tester, {
        settingsVersionField: baseSettingsVersion,
        'courseWords': {'from': 1, 'to': 1},
        'forcedOnWords': [storedKey],
      }, page: 'words');
      await tester.enterText(find.byKey(const Key('words.search')), item.lemma);
      await tester.pumpAndSettle();
      expect(
        isChecked(tester, find.byKey(Key('word.${item.wordKey}'))),
        isTrue,
        reason: '${item.id}: stored as "$storedKey"',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });
}
