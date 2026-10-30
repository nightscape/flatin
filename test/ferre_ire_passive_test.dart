// ferre has a full passive and a perfect passive; ire has the impersonal
// passive and an internal perfect passive participle.
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';

void main() {
  late Map<String, PracticeItem> verbs;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    verbs = {
      for (final i in await loadPracticeItems('lib/data/latin_verbs.yaml'))
        i.id: i,
    };
  });

  Map<String, String> forms(String id, List<String> keys) {
    final item = verbs['verbs:$id']!;
    return {for (final k in keys) k: item.forms[item.formOrder.indexOf(k)]};
  }

  test('ferre passive', () {
    expect(
      forms('ferre', [
        'ind.praes.pass.1.sg',
        'ind.praes.pass.2.sg',
        'ind.praes.pass.3.sg',
        'ind.praes.pass.1.pl',
        'ind.praes.pass.2.pl',
        'ind.praes.pass.3.pl',
        'ind.impf.pass.1.sg',
        'ind.fut.pass.2.sg',
        'konj.praes.pass.3.sg',
        'konj.impf.pass.1.sg',
        'konj.impf.pass.3.pl',
        'imp.praes.pass.2.sg',
        'imp.praes.pass.2.pl',
        'inf.praes.pass',
      ]),
      {
        'ind.praes.pass.1.sg': 'feror',
        'ind.praes.pass.2.sg': 'ferris',
        'ind.praes.pass.3.sg': 'fertur',
        'ind.praes.pass.1.pl': 'ferimur',
        'ind.praes.pass.2.pl': 'feriminī',
        'ind.praes.pass.3.pl': 'feruntur',
        'ind.impf.pass.1.sg': 'ferēbar',
        'ind.fut.pass.2.sg': 'ferēris',
        'konj.praes.pass.3.sg': 'ferātur',
        'konj.impf.pass.1.sg': 'ferrer',
        'konj.impf.pass.3.pl': 'ferrentur',
        'imp.praes.pass.2.sg': 'ferre',
        'imp.praes.pass.2.pl': 'feriminī',
        'inf.praes.pass': 'ferrī',
      },
    );
  });

  test('ferre perfect passive participle', () {
    expect(
      forms('ferre', [
        'part.perf.pass.sg.nom.m',
        'part.perf.pass.sg.nom.f',
        'part.perf.pass.sg.nom.n',
        'ind.perf.pass.1.sg',
        'inf.perf.pass',
      ]),
      {
        'part.perf.pass.sg.nom.m': 'lātus',
        'part.perf.pass.sg.nom.f': 'lāta',
        'part.perf.pass.sg.nom.n': 'lātum',
        'ind.perf.pass.1.sg': 'lātus sum',
        'inf.perf.pass': 'lātum esse',
      },
    );
  });

  test('ire impersonal passive', () {
    expect(
      forms('ire', [
        'ind.praes.pass.3.sg',
        'ind.impf.pass.3.sg',
        'ind.fut.pass.3.sg',
        'konj.praes.pass.3.sg',
        'konj.impf.pass.3.sg',
        'ind.perf.pass.3.sg',
        'inf.praes.pass',
      ]),
      {
        'ind.praes.pass.3.sg': 'ītur',
        'ind.impf.pass.3.sg': 'ībātur',
        'ind.fut.pass.3.sg': 'ībitur',
        'konj.praes.pass.3.sg': 'eātur',
        'konj.impf.pass.3.sg': 'īrētur',
        'ind.perf.pass.3.sg': 'itum est',
        'inf.praes.pass': 'īrī',
      },
    );
  });

  test('ire perfect passive participle is internal', () {
    final ire = verbs['verbs:ire']!;
    expect(ire.formOrder.where((k) => k.startsWith('part.perf.pass')), isEmpty);
    expect(ire.derivation.internal['part.perf.pass.sg.nom.m']?.variants, [
      'itus',
    ]);
  });
}
