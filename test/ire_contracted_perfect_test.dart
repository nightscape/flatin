// The pluperfect subjunctive and the perfect infinitive of ire and its
// compounds are shown contracted (īss-/īsse); the uncontracted spelling stays
// accepted.
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';

const _endings = {
  'konj.plusq.akt.1.sg': 'ssem',
  'konj.plusq.akt.2.sg': 'ssēs',
  'konj.plusq.akt.3.sg': 'sset',
  'konj.plusq.akt.1.pl': 'ssēmus',
  'konj.plusq.akt.2.pl': 'ssētis',
  'konj.plusq.akt.3.pl': 'ssent',
  'inf.perf.akt': 'sse',
};

void main() {
  late List<PracticeItem> ireType;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    ireType = [
      for (final item in verbs)
        if (item.principalParts.any((p) => p.$2.endsWith('euntis'))) item,
    ];
  });

  String prefixOf(PracticeItem item) => item.principalParts
      .firstWhere((p) => p.$2.endsWith('euntis'))
      .$2
      .replaceFirst(RegExp(r'euntis$'), '');

  test('ire and its compounds are covered', () {
    expect(
      ireType.map((i) => i.id),
      unorderedEquals([
        'verbs:ire',
        'verbs:abire',
        'verbs:inire',
        'verbs:exire',
        'verbs:redire',
        'verbs:subire',
        'verbs:perire',
        'verbs:adire',
      ]),
    );
  });

  int indexOfKey(PracticeItem item, String key) {
    final index = item.formOrder.indexOf(key);
    expect(index, greaterThanOrEqualTo(0), reason: '${item.id} lacks $key');
    return index;
  }

  test('ire and every compound accept the same perfect-system variants', () {
    final ire = ireType.firstWhere((i) => i.id == 'verbs:ire');
    const perfectTempora = {'perf', 'plusq', 'fut2'};
    final perfectKeys = ire.formOrder.where((k) {
      final parts = k.split('.');
      return perfectTempora.contains(parts[1]) && parts[2] == 'akt';
    });
    expect(perfectKeys, hasLength(31));
    for (final compound in ireType.where((i) => i != ire)) {
      final prefix = prefixOf(compound);
      for (final key in perfectKeys) {
        final ireIndex = indexOfKey(ire, key);
        final compoundIndex = indexOfKey(compound, key);
        for (final variant in ire.acceptedForms[ireIndex]) {
          expect(
            compound.accepts(compoundIndex, '$prefix$variant'),
            isTrue,
            reason: '${compound.id} $key $prefix$variant',
          );
        }
        for (final variant in compound.acceptedForms[compoundIndex]) {
          expect(variant, startsWith(prefix), reason: '${compound.id} $key');
          final bare = variant.substring(prefix.length);
          expect(
            ire.accepts(ireIndex, bare),
            isTrue,
            reason: '${ire.id} $key $bare (from ${compound.id})',
          );
        }
      }
    }
  });

  test('the contracted spelling is shown', () {
    final shown = <String, String>{};
    final expected = <String, String>{};
    for (final item in ireType) {
      final prefix = prefixOf(item);
      for (final entry in _endings.entries) {
        final index = indexOfKey(item, entry.key);
        shown['${item.id} ${entry.key}'] = item.forms[index];
        expected['${item.id} ${entry.key}'] = '$prefixī${entry.value}';
      }
    }
    expect(shown, expected);
  });

  test('the uncontracted spelling stays accepted', () {
    for (final item in ireType) {
      final prefix = prefixOf(item);
      for (final entry in _endings.entries) {
        final index = indexOfKey(item, entry.key);
        expect(
          item.accepts(index, '${prefix}ii${entry.value}'),
          isTrue,
          reason: '${item.id} ${entry.key}',
        );
      }
    }
  });

  test('ire keeps the īv-perfect spelling accepted', () {
    final ire = ireType.firstWhere((i) => i.id == 'verbs:ire');
    for (final entry in _endings.entries) {
      final index = indexOfKey(ire, entry.key);
      expect(
        ire.accepts(index, 'īvi${entry.value}'),
        isTrue,
        reason: entry.key,
      );
    }
  });
}
