import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/esel_steps.dart';
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

  Iterable<PracticeItem> impersonal() => verbs.values.where(
    (i) =>
        i.type != 'Unregelmäßig' &&
        i.formOrder.contains('ind.praes.pass.3.sg') &&
        !i.formOrder.contains('ind.praes.pass.3.pl'),
  );

  test('the perfect passive of an impersonal verb is neuter', () {
    const expected = {
      'venire': 'ventum',
      'dormire': 'dormītum',
      'sedere': 'sessum',
    };
    for (final e in expected.entries) {
      final ppp = e.value;
      expect(formsOf(e.key), containsPair('ind.perf.pass.3.sg', '$ppp est'));
      expect(formsOf(e.key), containsPair('ind.plusq.pass.3.sg', '$ppp erat'));
      expect(formsOf(e.key), containsPair('ind.fut2.pass.3.sg', '$ppp erit'));
      expect(formsOf(e.key), containsPair('konj.perf.pass.3.sg', '$ppp sit'));
      expect(
        formsOf(e.key),
        containsPair('konj.plusq.pass.3.sg', '$ppp esset'),
      );
      expect(formsOf(e.key), containsPair('inf.perf.pass', '$ppp esse'));
    }
  });

  test('a transitive verb keeps the masculine perfect passive', () {
    final forms = formsOf('invenire');
    expect(forms['ind.perf.pass.3.sg'], 'inventus est');
    expect(forms['part.perf.pass.sg.nom.m'], 'inventus');
  });

  test('the perfect participle of an impersonal verb is internal', () {
    expect(impersonal(), hasLength(47));
    for (final item in impersonal()) {
      expect(
        item.formOrder.where((k) => k.startsWith('part.perf.pass')),
        isEmpty,
        reason: item.id,
      );
    }
    final venire = verbs['verbs:venire']!.derivation.internal;
    expect(venire['part.perf.pass.sg.nom.n']?.variants, ['ventum']);
  });

  test('every form of an impersonal verb has its ESEL steps', () {
    for (final item in impersonal()) {
      for (final key in item.formOrder) {
        expect(eselSteps(item, key), isNotEmpty, reason: '${item.id} $key');
      }
    }
  });
}
