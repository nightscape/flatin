import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';

final _supineKey = RegExp(
  r'^(ind|konj)\.(perf|plusq|fut2)\.pass\.|^inf\.perf\.pass$|^inf\.fut\.pass$|'
  r'^part\.perf\.pass\.|^sup\.',
);
final _futureActiveKey = RegExp(r'^part\.fut\.akt\.|^inf\.fut\.akt$');

const _noEntry = 'no private reference entry';
const _printsSupine = 'entry prints a supine';

const _typeDefaultPppAccepted = <String, String>{
  'verbs:amare': _noEntry,
  'verbs:habere': _printsSupine,
  'verbs:audire': _printsSupine,
  'verbs:intrare': _noEntry,
  'verbs:apparere': _noEntry,
  'verbs:aedificare': _noEntry,
  'verbs:ambulare': _noEntry,
  'verbs:apportare': _noEntry,
  'verbs:appropinquare': _noEntry,
  'verbs:cessare': _noEntry,
  'verbs:clamare': _noEntry,
  'verbs:cenare': _noEntry,
  'verbs:curare': _noEntry,
  'verbs:dormire': _noEntry,
  'verbs:delectare': _noEntry,
  'verbs:desiderare': _noEntry,
  'verbs:explicare': _noEntry,
  'verbs:exspectare': _noEntry,
  'verbs:fugare': _noEntry,
  'verbs:imperare': _noEntry,
  'verbs:laborare': _noEntry,
  'verbs:necare': _noEntry,
  'verbs:parare': _noEntry,
  'verbs:placere': _noEntry,
  'verbs:portare': _noEntry,
  'verbs:probare': _noEntry,
  'verbs:prohibere': _noEntry,
  'verbs:properare': _noEntry,
  'verbs:parere': _noEntry,
  'verbs:pugnare': _noEntry,
  'verbs:rogare': _noEntry,
  'verbs:regnare': _noEntry,
  'verbs:sacrificare': _noEntry,
  'verbs:salutare': _noEntry,
  'verbs:scire': _noEntry,
  'verbs:servare': _noEntry,
  'verbs:servire': _noEntry,
  'verbs:spectare': _noEntry,
  'verbs:stupere': _noEntry,
  'verbs:superare': _noEntry,
  'verbs:tacere': _noEntry,
  'verbs:temptare': _noEntry,
  'verbs:vocare': _printsSupine,
  'verbs:visitare': _noEntry,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a verb without a supine part has no supine-based form unless exempt',
    () async {
      final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final inspected = <String>[];
      final exemptSeen = <String>[];
      final fabricated = <String>[];
      for (final item in items) {
        final labels = item.principalParts.map((p) => p.$1).toSet();
        if (labels.contains('Supinum')) continue;
        if (_typeDefaultPppAccepted.containsKey(item.id)) {
          exemptSeen.add(item.id);
          continue;
        }
        inspected.add(item.id);
        final hasFuturePart = labels.contains('Partizip Futur');
        for (final key in item.formOrder) {
          if (_supineKey.hasMatch(key) ||
              (!hasFuturePart && _futureActiveKey.hasMatch(key))) {
            fabricated.add('${item.id} $key');
          }
        }
      }
      expect(exemptSeen, unorderedEquals(_typeDefaultPppAccepted.keys));
      expect(_typeDefaultPppAccepted.length, 44);
      expect(inspected.length, 21);
      expect(fabricated, isEmpty);
    },
  );
}
