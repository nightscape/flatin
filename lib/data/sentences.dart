import 'package:yaml/yaml.dart';

import '../models/course.dart';
import 'asset_text.dart';
import 'languages/language.dart';

/// One word of a sentence, as the sentence spells it.
sealed class SentenceToken {
  final String text;
  const SentenceToken(this.text);

  /// An enclitic (`-ne`, `-que`) is written onto the word before it.
  bool get isEnclitic => text.startsWith('-');
}

/// A form the grammar engine generates: item [lemma], form [key].
final class FormToken extends SentenceToken {
  final String lemma;
  final String key;
  const FormToken(super.text, this.lemma, this.key);
}

/// A lesson headword the engine has no item for (et, nōn, -ne, …); [text]
/// is one of its words.
final class HeadwordToken extends SentenceToken {
  final String headword;
  const HeadwordToken(super.text, this.headword);
}

final class Construction {
  /// A code of [Language.constructions].
  final String kind;

  /// Token index of the participle, the question particle or the
  /// predicative accusative.
  final int head;

  /// Token index of the word [head] refers to; null for a question.
  final int? reference;

  /// Codes of [Language.meanings]; non-empty exactly when the construction
  /// [ConstructionRule.hasMeaning].
  final List<String> meanings;

  const Construction(this.kind, this.head, this.reference, this.meanings);
}

final class WrongRendering {
  final String german;

  /// A code of [Language.mistakes].
  final String mistake;
  const WrongRendering(this.german, this.mistake);
}

final class Sentence {
  final String id;

  /// The lesson whose words and grammar the sentence stays within.
  final int lesson;
  final String text;
  final List<SentenceToken> tokens;
  final Construction construction;
  final List<String> right;
  final List<WrongRendering> wrong;

  const Sentence({
    required this.id,
    required this.lesson,
    required this.text,
    required this.tokens,
    required this.construction,
    required this.right,
    required this.wrong,
  });
}

final class SentenceCorpus {
  /// The language whose codes the sentences use.
  final Language language;
  final List<Sentence> sentences;
  const SentenceCorpus(this.language, this.sentences);
}

Future<SentenceCorpus> loadSentenceCorpus() async => parseSentenceCorpus(
  await loadAssetText((await loadCourse()).sentences),
  await loadLanguage(),
);

/// Throws when a sentence uses a code that [language] lacks.
SentenceCorpus parseSentenceCorpus(String source, Language language) {
  final yaml = loadYaml(source) as YamlMap;
  final ids = <String>{};
  final sentences = [
    for (final entry in yaml['sentences'] as YamlList)
      _sentence(entry as YamlMap, language),
  ];
  for (final s in sentences) {
    if (!ids.add(s.id)) throw StateError('sentence id "${s.id}" is twice');
  }
  return SentenceCorpus(language, sentences);
}

Sentence _sentence(YamlMap map, Language language) {
  final id = map['id'] as String;
  final tokens = [
    for (final t in map['tokens'] as YamlList)
      _token((t as YamlList).cast<String>(), id),
  ];
  final c = map['construction'] as YamlMap;
  final kind = _code(
    c['kind'],
    language.constructions.keys,
    'construction',
    id,
  );
  final rule = language.constructions[kind]!;
  final construction =
      Construction(kind, c['head'] as int, c['reference'] as int?, [
        for (final m in c['meaning'] as YamlList? ?? const [])
          _code(m, language.meanings, 'meaning', id),
      ]);
  for (final index in [construction.head, ?construction.reference]) {
    if (index < 0 || index >= tokens.length) {
      throw StateError('$id: token index $index is outside the sentence');
    }
  }
  if ((construction.reference != null) != rule.hasReference) {
    throw StateError(
      '$id: $kind ${rule.hasReference ? 'needs' : 'has no'} '
      'reference word',
    );
  }
  if (construction.meanings.isNotEmpty != rule.hasMeaning) {
    throw StateError(
      '$id: $kind ${rule.hasMeaning ? 'needs' : 'has no'} '
      'meaning',
    );
  }
  final right = (map['right'] as YamlList).cast<String>().toList();
  final wrong = [
    for (final w in map['wrong'] as YamlList)
      WrongRendering(
        (w as YamlMap)['de'] as String,
        _code(w['mistake'], language.mistakes, 'mistake', id),
      ),
  ];
  if (right.length < 2 || right.length > 4) {
    throw StateError('$id: ${right.length} right renderings, not 2-4');
  }
  if (wrong.length < 2 || wrong.length > 3) {
    throw StateError('$id: ${wrong.length} wrong renderings, not 2-3');
  }
  return Sentence(
    id: id,
    lesson: map['lesson'] as int,
    text: map['text'] as String,
    tokens: tokens,
    construction: construction,
    right: right,
    wrong: wrong,
  );
}

SentenceToken _token(List<String> fields, String id) => switch (fields) {
  [final text] => HeadwordToken(text, text),
  [final text, final headword] => HeadwordToken(text, headword),
  [final text, final lemma, final key] => FormToken(text, lemma, key),
  _ => throw StateError('$id: token $fields has no 1-3 fields'),
};

String _code(Object? code, Iterable<String> known, String what, String id) =>
    known.contains(code)
    ? code as String
    : throw StateError('$id: "$code" is no $what of the language');
