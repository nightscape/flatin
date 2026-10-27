import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the present participle active has -e as its only ablative singular',
    () async {
      final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
      for (final genus in ['m', 'f', 'n']) {
        final index = vocare.formOrder.indexOf('part.praes.akt.sg.abl.$genus');
        expect(vocare.acceptedForms[index], ['vocante'], reason: genus);
        expect(vocare.accepts(index, 'vocantī'), isFalse, reason: genus);
      }
    },
  );
}
