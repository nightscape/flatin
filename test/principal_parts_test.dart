import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';

const _keysByPartLabel = {
  'nouns': {
    '': ['nom.sg', 'nom.sg.m'],
    'Genitiv': ['gen.sg'],
    'Nominativ feminin': ['nom.sg.f'],
    'Nominativ neutrum': ['nom.sg.n'],
  },
  'verbs': {
    '': ['ind.praes.akt.1.sg'],
    'Infinitiv': ['inf.praes.akt'],
    'Perfekt': ['ind.perf.akt.1.sg'],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final file in _keysByPartLabel.keys) {
    test(
      '$file: a displayed principal part equals the engine form of its key',
      () async {
        final items = await loadPracticeItems('lib/data/latin_$file.yaml');
        final mismatches = <String>[];
        for (final item in items) {
          for (final (label, value) in item.principalParts) {
            final keys = _keysByPartLabel[file]![label];
            if (keys == null) continue;
            final key = keys.where(item.formOrder.contains).firstOrNull;
            if (key == null) continue;
            final form = item.forms[item.formOrder.indexOf(key)];
            if (form != value) {
              mismatches.add('${item.id} $key: shown "$value", engine "$form"');
            }
          }
        }
        expect(mismatches, isEmpty);
      },
    );
  }
}
