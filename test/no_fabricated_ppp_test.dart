import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';

final _supineKey = RegExp(
  r'^(ind|konj)\.(perf|plusq|fut2)\.pass\.|^inf\.perf\.pass$|^inf\.fut\.pass$|'
  r'^part\.perf\.pass\.|^sup\.',
);
final _futureActiveKey = RegExp(r'^part\.fut\.akt\.|^inf\.fut\.akt$');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a verb without a supine part has no supine-based form',
    () async {
      final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final inspected = <String>[];
      final fabricated = <String>[];
      for (final item in items) {
        final labels = item.principalParts.map((p) => p.$1).toSet();
        if (labels.contains('Supinum')) continue;
        inspected.add(item.id);
        final hasFuturePart = labels.contains('Partizip Futur');
        for (final key in item.formOrder) {
          if (_supineKey.hasMatch(key) ||
              (!hasFuturePart && _futureActiveKey.hasMatch(key))) {
            fabricated.add('${item.id} $key');
          }
        }
      }
      expect(inspected.length, 22);
      expect(fabricated, isEmpty);
    },
  );
}
