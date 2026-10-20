import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart' show dataLanguages;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final language in dataLanguages) {
    test('every word has a "$language" gloss', () async {
      final items = await loadAllPracticeItems(language: language);
      expect(items, isNotEmpty);
      for (final item in items) {
        expect(item.translation.trim(), isNotEmpty, reason: item.id);
      }
    });
  }
}
