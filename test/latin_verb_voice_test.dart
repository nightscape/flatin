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

  Map<String, String> formsOf(String id) {
    final item = verbs['verbs:$id']!;
    return {
      for (var k = 0; k < item.formOrder.length; k++)
        item.formOrder[k]: item.forms[k],
    };
  }

  final personalPassive = RegExp(
    r'^(ind|konj|imp)\.\w+\.pass\.(1\.|2\.|3\.pl)',
  );
  final intransitive = [
    'venire',
    'convenire',
    'pervenire',
    'advenire',
    'apparere',
    'ambulare',
    'appropinquare',
    'cessare',
    'dormire',
    'properare',
    'pugnare',
    'regnare',
    'sedere',
    'servire',
    'tacere',
    'laborare',
    'navigare',
    'parere',
    'dubitare',
    'stare',
    'studere',
    'latere',
    'valere',
    'iacere',
    'dolere',
    'instare',
    'errare',
    'ardere',
    'carere',
    'cadere',
    'vivere',
    'parcere',
    'resistere',
    'accedere',
    'discedere',
    'consistere',
    'crescere',
    'surgere',
    'descendere',
    'fugere',
    'effugere',
    'ruere',
    'contendere',
    'evadere',
    'incedere',
    'tendere',
    'stupere',
  ];

  test('an intransitive verb has no personal passive', () {
    for (final id in intransitive) {
      final bad = formsOf(id).keys.where(personalPassive.hasMatch);
      expect(bad, isEmpty, reason: id);
    }
  });

  test('an intransitive verb keeps the impersonal passive', () {
    final venire = formsOf('venire');
    expect(venire['ind.praes.pass.3.sg'], 'venītur');
    expect(venire['ind.impf.pass.3.sg'], 'veniēbātur');
    expect(venire['ind.fut.pass.3.sg'], 'veniētur');
    expect(venire['konj.praes.pass.3.sg'], 'veniātur');
    expect(venire['inf.praes.pass'], 'venīrī');
    expect(formsOf('dormire')['ind.praes.pass.3.sg'], 'dormītur');
    expect(formsOf('sedere')['ind.praes.pass.3.sg'], 'sedētur');
    expect(formsOf('ambulare')['ind.praes.pass.3.sg'], 'ambulātur');
  });

  test('a transitive verb keeps the personal passive', () {
    expect(formsOf('audire')['ind.praes.pass.3.pl'], 'audiuntur');
    expect(formsOf('invenire')['ind.perf.pass.1.sg'], 'inventus sum');
  });

  const supines = {
    'convocare': 'convocātum',
    'narrare': 'nārrātum',
    'desperare': 'dēspērātum',
    'turbare': 'turbātum',
    'perturbare': 'perturbātum',
    'cogitare': 'cōgitātum',
    'vexare': 'vexātum',
    'ignorare': 'īgnōrātum',
    'violare': 'violātum',
    'putare': 'putātum',
    'mutare': 'mūtātum',
    'excitare': 'excitātum',
    'sollicitare': 'sollicitātum',
    'finire': 'fīnītum',
    'custodire': 'cūstōdītum',
    'monere': 'monitum',
    'terrere': 'territum',
    'perterrere': 'perterritum',
    'debere': 'dēbitum',
    'praebere': 'praebitum',
    'sustinere': 'sustentum',
    'nescire': 'nescītum',
    'errare': 'errātum',
    'stare': 'statum',
  };

  test('a verb with a supine has the supine and the perfect passive', () {
    for (final e in supines.entries) {
      final forms = formsOf(e.key);
      expect(forms['sup.akk'], e.value, reason: e.key);
      expect(forms['part.perf.pass.sg.nom.m'], isNotNull, reason: e.key);
      expect(forms['part.fut.akt.sg.nom.m'], isNotNull, reason: e.key);
    }
  });

  test('convocare perfect passive', () {
    final forms = formsOf('convocare');
    expect(forms['part.perf.pass.sg.nom.m'], 'convocātus');
    expect(forms['ind.perf.pass.1.sg'], 'convocātus sum');
    expect(forms['inf.perf.pass'], 'convocātum esse');
  });

  test('a verb without a supine has none', () {
    for (final id in ['stupere', 'timere', 'studere', 'latere', 'arcere']) {
      final forms = formsOf(id);
      expect(forms.containsKey('sup.akk'), isFalse, reason: id);
      expect(forms.containsKey('part.perf.pass.sg.nom.m'), isFalse);
    }
  });
}
