import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/settings_conversion.dart'
    show settingsVersion, settingsVersionField;
import 'package:latin_practice/models/practice_item.dart';

import 'support/stored_settings.dart';

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
        settingsVersionField: settingsVersion,
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
}
