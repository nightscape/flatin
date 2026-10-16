import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/data/practice_data.dart';

import 'support/trace_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('habet: seam rule and the ending of another type in one line', () async {
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final item = verbs.firstWhere((i) => i.lemma == 'habēre');
    final lines = explainWrongAnswer(item, 'ind.praes.akt.3.sg', 'habat');
    final line = lines.firstWhere((l) => l.key.startsWith('explain.sandhi'));
    expect(line.key, 'explain.sandhiOtherType');
    expect(line.params, {
      'label': 'Präsens: 3. Person Singular',
      'before': 'habē + t',
      'after': 'habet',
      'rule': 'Vokal vor -t am Wortende wird kurz',
      'endingType': 'A-Konjugation',
    });
    expect(
      renderDe(await germanTexts(), line),
      'Präsens: 3. Person Singular: habē + t = habet '
      '(Vokal vor -t am Wortende wird kurz; Endung der A-Konjugation)',
    );
  });
}
