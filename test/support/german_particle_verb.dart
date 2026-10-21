import 'dart:io';

import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'trace_fixtures.dart';

const _path = 'lib/data/german_verbs.yaml';

/// The course verbs have no glued particle ending in t before a verb in t.
const _item = '''
  - type: schwach
    translation: {de: mitteilen, en: inform}
    parts: {infinitiv: mitteilen, grundverb: teilen, partikel: mit, partizip2: mitgeteilt}
''';

/// The German verb file with the test verb "mitteilen" appended to its items.
List<GrammarFile> mitteilenFiles() =>
    parseGrammarFiles({_path: File(_path).readAsStringSync() + _item});

PracticeItem mitteilen() {
  final files = mitteilenFiles();
  return traceItem(
    id: 'german_verbs:mitteilen',
    lemma: 'mitteilen',
    type: 'schwach',
    translation: 'mitteilen',
    principalParts: const [('', 'mitteilen')],
    axes: files.single.axes,
    derivation: GrammarEngine(files).of('german_verbs', 'mitteilen'),
    dataFileId: 'german_verbs',
  );
}
