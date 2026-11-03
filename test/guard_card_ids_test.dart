import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _golden = 'test/fixtures/guard/card_ids.txt';

/// Update with `flutter test --update-goldens test/guard_card_ids_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // An example test: it pins the ids of the one real course, which has no
  // input space to draw from. A renamed id orphans the learner's card.
  test('the real course derives exactly the card ids of the golden', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(retry: noRetry);
    addTearDown(c.dispose);
    final ids = (await c.read(fsrsCardsProvider.future)).keys.toList()..sort();
    if (autoUpdateGoldenFiles) {
      File(_golden).writeAsStringSync('${ids.join('\n')}\n');
    }

    final golden = File(_golden).readAsLinesSync();
    expect(golden, orderedEquals([...golden]..sort()));
    final diff = {
      'derived, not in the golden': ids.toSet().difference(golden.toSet()),
      'in the golden, no longer derived': golden.toSet().difference(
        ids.toSet(),
      ),
    };
    expect(diff, {for (final kind in diff.keys) kind: isEmpty});
  });
}
