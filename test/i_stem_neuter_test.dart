import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the i-stem neuter plural has one spelling for nom, akk and vok',
    () async {
      final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
      final items = nouns.where(
        (i) => i.type == 'Konsonantische-Deklination-i-n',
      );
      expect(items, isNotEmpty);
      for (final item in items) {
        String form(String key) => item.forms[item.formOrder.indexOf(key)];
        expect(form('nom.pl'), endsWith('ia'), reason: item.id);
        expect(form('akk.pl'), form('nom.pl'), reason: item.id);
        expect(form('vok.pl'), form('nom.pl'), reason: item.id);
      }
    },
  );
}
