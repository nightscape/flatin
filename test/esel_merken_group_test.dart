import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/widgets/esel_panel.dart';

import 'support/esel_render.dart';

const _nouns = 'lib/data/latin_nouns.yaml';

void main() {
  testWidgets('is "ea": the Ablativ reading keeps its own Merken form', (
    tester,
  ) async {
    final item = await loadItem(_nouns, 'is');
    await pumpClassified(tester, item, 'nom.sg.f');

    final rendered = {
      for (final p in tester.widgetList<EselStaticSteps>(
        find.byType(EselStaticSteps),
      ))
        p.title: renderSteps(tester, p.scope),
    };
    final ablative = rendered.entries.firstWhere(
      (e) => e.key.contains('Ablativ'),
      orElse: () => const MapEntry('<no Ablativ panel>', ''),
    );
    expect(ablative.value, contains('eā'), reason: 'panels: $rendered');
  });
}
