import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';

const _perfect = 'ind.perf.akt.1.sg';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every verb shows its perfect among its principal parts, unless the '
      'perfect is deponent and so made from the supine', () async {
    final verbs = await loadGrammarFile('verbs');
    final items = await loadAllPracticeItems();
    final verbItems = items.where((i) => i.dataFileId == 'verbs').toList();
    expect(verbItems, hasLength(verbs.items.length));
    final missing = <String>[];
    for (final item in verbItems) {
      final keys = verbs.keysByItem[item.id.substring('verbs:'.length)]!;
      expect(keys.emitted, contains(_perfect), reason: item.id);
      final perfect = item.forms[item.formOrder.indexOf(_perfect)];
      final shown = item.principalParts.any((part) => part.$2 == perfect);
      if (!shown && !keys.deponent.contains(_perfect)) {
        missing.add('${item.id} ($perfect)');
      }
    }
    expect(missing, isEmpty, reason: 'no perfect part: ${missing.join(', ')}');
  });
}
