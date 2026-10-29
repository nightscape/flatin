import 'package:yaml/yaml.dart';

import 'asset_text.dart';

const sentencesAsset = 'lib/data/sentences.yaml';

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

enum ConstructionKind {
  frageNe,
  frageNonne,
  frageNum,
  aciPassiv,
  pcPpa,
  pcPpp,
  doppelterAkkusativ,
}

/// The Sinnrichtung of a participium coniunctum.
enum Meaning { temporal, kausal, konzessiv, modal }

/// The typical mistake a wrong rendering makes.
enum Mistake {
  tempus,
  genusVerbi,
  bezugswort,
  sinnrichtung,
  frageart,
  aussage,
  rollen,
  praedikativum,
}

final class Construction {
  final ConstructionKind kind;

  /// Token index of the participle, the question particle or the
  /// predicative accusative.
  final int head;

  /// Token index of the word [head] refers to; null for a question.
  final int? reference;

  /// Non-empty exactly for a participium coniunctum.
  final List<Meaning> meanings;

  const Construction(this.kind, this.head, this.reference, this.meanings);
}

final class WrongRendering {
  final String german;
  final Mistake mistake;
  const WrongRendering(this.german, this.mistake);
}

final class Sentence {
  final String id;

  /// The lesson whose words and grammar the sentence stays within.
  final int lesson;
  final String latin;
  final List<SentenceToken> tokens;
  final Construction construction;
  final List<String> right;
  final List<WrongRendering> wrong;

  const Sentence({
    required this.id,
    required this.lesson,
    required this.latin,
    required this.tokens,
    required this.construction,
    required this.right,
    required this.wrong,
  });
}

final class SentenceCorpus {
  /// Noun lemma -> genus code, for nouns whose forms carry no genus.
  final Map<String, String> genders;
  final List<Sentence> sentences;
  const SentenceCorpus(this.genders, this.sentences);
}

Future<SentenceCorpus> loadSentenceCorpus() async =>
    parseSentenceCorpus(await loadAssetText(sentencesAsset));

SentenceCorpus parseSentenceCorpus(String source) {
  final yaml = loadYaml(source) as YamlMap;
  final ids = <String>{};
  final sentences = [
    for (final entry in yaml['sentences'] as YamlList)
      _sentence(entry as YamlMap),
  ];
  for (final s in sentences) {
    if (!ids.add(s.id)) throw StateError('sentence id "${s.id}" is twice');
  }
  return SentenceCorpus(
    (yaml['genders'] as YamlMap).cast<String, String>(),
    sentences,
  );
}

Sentence _sentence(YamlMap map) {
  final id = map['id'] as String;
  final tokens = [
    for (final t in map['tokens'] as YamlList)
      _token((t as YamlList).cast<String>(), id),
  ];
  final c = map['construction'] as YamlMap;
  final construction = Construction(
    ConstructionKind.values.byName(c['kind'] as String),
    c['head'] as int,
    c['reference'] as int?,
    [
      for (final m in c['meaning'] as YamlList? ?? const [])
        Meaning.values.byName(m as String),
    ],
  );
  final isPc = const {
    ConstructionKind.pcPpa,
    ConstructionKind.pcPpp,
  }.contains(construction.kind);
  final isQuestion = construction.kind.name.startsWith('frage');
  for (final index in [construction.head, ?construction.reference]) {
    if (index < 0 || index >= tokens.length) {
      throw StateError('$id: token index $index is outside the sentence');
    }
  }
  if ((construction.reference == null) != isQuestion) {
    throw StateError('$id: only a question has no reference word');
  }
  if (construction.meanings.isEmpty == isPc) {
    throw StateError('$id: exactly a participium coniunctum has a meaning');
  }
  final right = (map['right'] as YamlList).cast<String>().toList();
  final wrong = [
    for (final w in map['wrong'] as YamlList)
      WrongRendering(
        (w as YamlMap)['de'] as String,
        Mistake.values.byName(w['mistake'] as String),
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
    latin: map['latin'] as String,
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
