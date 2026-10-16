// dare has a short a in its present stem: damus, not dāmus.
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';

void main() {
  test('dare keeps the short a of its present stem', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dare = (await loadPracticeItems('lib/data/latin_verbs.yaml'))
        .singleWhere((i) => i.id == 'verbs:dare');
    String form(String key) => dare.forms[dare.formOrder.indexOf(key)];

    expect({
      for (final key in [
        'ind.praes.akt.1.pl',
        'ind.praes.akt.2.sg',
        'ind.praes.akt.2.pl',
        'ind.praes.akt.3.sg',
        'ind.praes.akt.3.pl',
        'ind.praes.pass.1.pl',
        'ind.impf.akt.1.sg',
        'konj.praes.akt.1.sg',
        'konj.praes.akt.3.sg',
        'inf.praes.akt',
        'imp.praes.akt.2.sg',
      ])
        key: form(key),
    }, {
      'ind.praes.akt.1.pl': 'damus',
      'ind.praes.akt.2.sg': 'das',
      'ind.praes.akt.2.pl': 'datis',
      'ind.praes.akt.3.sg': 'dat',
      'ind.praes.akt.3.pl': 'dant',
      'ind.praes.pass.1.pl': 'damur',
      'ind.impf.akt.1.sg': 'dabam',
      'konj.praes.akt.1.sg': 'dem',
      'konj.praes.akt.3.sg': 'det',
      'inf.praes.akt': 'dare',
      'imp.praes.akt.2.sg': 'da',
    });
  });
}
