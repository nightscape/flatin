import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/screens/practice_screen.dart';

/// Prints how many practice fields pay coins and how many show their answer
/// on the screen, over every Latin word.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('count the paying and the shown fields', () async {
    final items = [
      ...await loadPracticeItems('lib/data/latin_nouns.yaml'),
      ...await loadPracticeItems('lib/data/latin_verbs.yaml'),
    ];
    final pays = [
      for (final item in items)
        for (final key in item.formOrder) paysCoins(item, key),
    ];
    final shown = pays.where((p) => !p).length;
    // ignore: avoid_print
    print(
      'words: ${items.length}, fields: ${pays.length}, '
      'paying: ${pays.length - shown}, shown (pay 0): $shown',
    );
    expect(shown, greaterThanOrEqualTo(items.length));
  });
}
