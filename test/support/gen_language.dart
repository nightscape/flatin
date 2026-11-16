import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:latin_practice/data/languages/language.dart';
import 'package:yaml/yaml.dart';

import 'latin_course.dart';

/// The language file of the course as JSON, for tests to break.
Map<String, dynamic> latinLanguageData() => _json(latinCourse.language);

Map<String, dynamic> _json(String path) =>
    jsonDecode(jsonEncode(loadYaml(File(path).readAsStringSync())))
        as Map<String, dynamic>;

/// The sentence codes of a drawn language and the Latin codes they replace.
typedef CodeRenames = ({
  Map<String, String> constructions,
  Map<String, String> meanings,
  Map<String, String> mistakes,
});

/// [latinLang] with every construction, meaning and mistake code replaced by
/// a drawn code that no Latin code shares, and the sentences of the real
/// corpus (as JSON) with the same replacement.
({
  Language language,
  Map<String, dynamic> languageData,
  Map<String, dynamic> corpus,
  CodeRenames renames,
})
drawnSentenceLanguage(Random r) {
  final used = <String>{};
  String fresh() {
    String code;
    do {
      code = 'z${r.nextInt(1 << 20)}';
    } while (!used.add(code));
    return code;
  }

  Map<String, String> rename(Iterable<String> codes) => {
    for (final c in codes) c: fresh(),
  };
  final data = _json(latinCourse.language);
  final constructions = data['constructions'] as Map<String, dynamic>;
  final renames = (
    constructions: rename(constructions.keys),
    meanings: rename((data['meanings'] as List).cast()),
    mistakes: rename((data['mistakes'] as List).cast()),
  );
  data['id'] = 'x${r.nextInt(1 << 30)}';
  data['constructions'] = {
    for (final MapEntry(:key, :value) in constructions.entries)
      renames.constructions[key]!: value,
  };
  data['meanings'] = [
    for (final m in (data['meanings'] as List).cast<String>())
      renames.meanings[m]!,
  ];
  data['mistakes'] = [
    for (final m in (data['mistakes'] as List).cast<String>())
      renames.mistakes[m]!,
  ];

  final corpus = _json(latinCourse.sentences);
  for (final s in corpus['sentences'] as List) {
    final c = s['construction'] as Map<String, dynamic>;
    c['kind'] = renames.constructions[c['kind']]!;
    if (c['meaning'] case final List m) {
      c['meaning'] = [for (final x in m) renames.meanings[x]!];
    }
    for (final w in s['wrong'] as List) {
      w['mistake'] = renames.mistakes[w['mistake']]!;
    }
  }
  return (
    language: Language.parse(jsonEncode(data)),
    languageData: data,
    corpus: corpus,
    renames: renames,
  );
}

/// A language `name` map with a fresh name per UI language code.
Map<String, String> drawnLanguageName(Random r) {
  final n = r.nextInt(1 << 30);
  return {'de': 'Sprachede$n', 'en': 'Languageen$n'};
}
