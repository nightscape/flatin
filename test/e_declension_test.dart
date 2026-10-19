import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('e-declension genitive and dative singular: reī after a consonant, '
      'diēī after a vowel', () async {
    final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
    final eDeclension = nouns
        .where((i) => i.type.startsWith('E-Deklination'))
        .toList();
    expect(
      eDeclension.map((i) => i.id),
      containsAll(['nouns:res', 'nouns:spes', 'nouns:fides', 'nouns:dies']),
    );
    for (final item in eDeclension) {
      final nom = item.forms[item.formOrder.indexOf('nom.sg')];
      final stem = nom.substring(0, nom.length - 2);
      final ending = 'aeiou'.contains(stem[stem.length - 1]) ? 'ēī' : 'eī';
      for (final key in ['gen.sg', 'dat.sg']) {
        expect(
          item.forms[item.formOrder.indexOf(key)],
          '$stem$ending',
          reason: '${item.id} $key',
        );
      }
    }
  });
}
