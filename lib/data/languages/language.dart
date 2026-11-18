import 'package:yaml/yaml.dart';

/// Codes by key: an `analyse` map, or a constraint on one.
typedef Codes = Map<String, Object>;

/// Whether [codes] hold every code of [want].
bool matches(Codes codes, Codes want) =>
    want.entries.every((e) => codes[e.key] == e.value);

/// A language file of `lib/data/languages/`: the analysis codes of `.exam`
/// packs and the parameters of their rules.
final class Language {
  final String id;
  final Map<String, String> name;

  /// The spellings the language writes the same word without a quantity mark
  /// for: each key is one code unit that [fold] replaces by its value.
  final Map<String, String> _fold;
  final RegExp _foldKeys;

  /// Matches a word made of the letters of the language and nothing else.
  final RegExp letters;

  /// How an answer is compared with the expected text; null when the language
  /// gives no answer rules.
  final AnswerRules? answerRules;

  /// The codes of each `analyse` key, in display order. This and every field
  /// below are empty (or throw, for [wordClass] and [rules]) in a language
  /// without a token analysis.
  final Map<String, List<Object>> analyse;
  final String? _wordClass;

  /// The `analyse` keys a `bilden` item names.
  final List<String> form;
  final List<String> rolle;
  final List<String> clauseArt;
  final List<String> sinnrichtung;
  final ExamRules? _rules;

  /// The constructions a sentence of the corpus illustrates, by code.
  final Map<String, ConstructionRule> constructions;

  /// The meaning codes of a construction with [ConstructionRule.hasMeaning].
  final List<String> meanings;

  /// The codes of the typical mistakes a wrong rendering makes.
  final List<String> mistakes;

  Language._(
    this.id,
    this.name,
    this._fold,
    this._foldKeys,
    this.letters,
    this.answerRules,
    this.analyse,
    this._wordClass,
    this.form,
    this.rolle,
    this.clauseArt,
    this.sinnrichtung,
    this._rules,
    this.constructions,
    this.meanings,
    this.mistakes,
  );

  /// The one key every `analyse` has.
  String get wordClass =>
      _wordClass ?? (throw StateError('language $id has no token analysis'));

  ExamRules get rules =>
      _rules ?? (throw StateError('language $id has no token analysis'));

  /// Every code list by its path in the language file.
  Map<String, List<Object>> get axes => {
    for (final MapEntry(:key, :value) in analyse.entries) 'analyse.$key': value,
    'rolle': rolle,
    'clause.art': clauseArt,
    'clause.sinnrichtung': sinnrichtung,
  };

  /// [text] with every [_fold] key replaced.
  String fold(String text) =>
      text.replaceAllMapped(_foldKeys, (m) => _fold[m[0]]!);

  /// [fold] of [text] in lower case.
  String foldLower(String text) => fold(text).toLowerCase();

  /// The comparison form of a spelling: trimmed, lower case, without quantity
  /// marks.
  String norm(String text) => fold(text.trim().toLowerCase());

  /// Whether [text] holds a character that [fold] changes.
  bool hasQuantityMark(String text) => _foldKeys.hasMatch(text);

  factory Language.parse(String source) {
    final y = loadYaml(source) as YamlMap;
    final fold = Map<String, String>.unmodifiable(
      (y['fold'] as YamlMap).cast(),
    );
    for (final MapEntry(:key, :value) in fold.entries) {
      if (key.length != 1 || value.length != 1 || r'^]\-['.contains(key)) {
        throw FormatException(
          'language ${y['id']}: fold "$key" must map one code unit, not a '
          'regex class character, to one code unit',
        );
      }
    }
    final hasAnalysis = y.containsKey('analyse');
    const analysisKeys = [
      'word_class',
      'form',
      'rolle',
      'clause',
      'rules',
      'constructions',
      'meanings',
      'mistakes',
    ];
    for (final key in analysisKeys) {
      if (y.containsKey(key) != hasAnalysis) {
        throw FormatException(
          'language ${y['id']}: "$key" and "analyse" are given together or '
          'not at all',
        );
      }
    }
    final analyse = {
      if (hasAnalysis)
        for (final MapEntry(:key, :value) in (y['analyse'] as YamlMap).entries)
          key as String: List<Object>.unmodifiable(value as YamlList),
    };
    final clause = hasAnalysis ? y['clause'] as YamlMap : null;
    final language = Language._(
      y['id'] as String,
      Map<String, String>.unmodifiable(y['name'] as YamlMap),
      fold,
      RegExp('[${fold.keys.join()}]'),
      RegExp('^[${y['letters'] as String}]+\$', caseSensitive: false),
      AnswerRules._parse(y),
      analyse,
      y['word_class'] as String?,
      _strings(y['form']),
      _strings(y['rolle']),
      _strings(clause?['art']),
      _strings(clause?['sinnrichtung']),
      hasAnalysis ? ExamRules._parse(y['rules'] as YamlMap) : null,
      Map.unmodifiable({
        if (hasAnalysis)
          for (final MapEntry(:key, :value)
              in (y['constructions'] as YamlMap).entries)
            key as String: ConstructionRule._parse(key, value as YamlMap),
      }),
      _strings(y['meanings']),
      _strings(y['mistakes']),
    );
    language._check();
    return language;
  }

  /// Throws when a rule names a key or code the language lacks.
  void _check() {
    if (_rules == null) return;
    final codesOf = {
      ...analyse,
      'rolle': rolle,
      'clause.art': clauseArt,
      'clause.sinnrichtung': sinnrichtung,
    };
    void code(String key, Object code) {
      if (!(codesOf[key]?.contains(code) ?? false)) {
        throw FormatException('language $id: "$code" is no code of "$key"');
      }
    }

    void key(String key) {
      if (!analyse.containsKey(key)) {
        throw FormatException('language $id: no analyse key "$key"');
      }
    }

    void codes(Codes want) => want.forEach(code);

    key(wordClass);
    form.forEach(key);
    final r = rules;
    code('clause.art', r.mainClause);
    for (final c in r.noRole) {
      code(wordClass, c);
    }
    r.needsBezug.forEach(codes);
    if (r.person case final p?) {
      key(p.key);
      codes(p.neededBy);
    }
    if (r.participle case final p?) {
      codes(p.isA);
      codes(p.form);
      p.agrees.forEach(key);
      code('clause.art', p.clause);
      for (final MapEntry(:key, :value) in p.rolleBySinnrichtung.entries) {
        code('clause.sinnrichtung', key);
        code('rolle', value);
      }
      code('rolle', p.otherRolle);
    }
    if (r.compound case final c?) {
      codes(c.verb);
      codes(c.passive);
      c.tenseMap.forEach((from, to) {
        code(c.tense, from);
        code(c.tense, to);
      });
      c.marks.forEach(key);
      codes(c.auxForm);
      code('rolle', c.rolle);
      c.agrees.forEach(key);
      codes(c.infinitive);
      codes(c.infinitiveAux);
    }
  }
}

/// The words of a construction a learner can mark; each names a feedback key
/// `exercise.markieren.feedback.<role>`.
enum PillRole { participle, reference, subject, predicative, object }

/// What a construction code of a sentence must have: a [hasReference] word
/// and a [hasMeaning] list. [roles] is the pills a learner puts on the head
/// and the reference word; present exactly when [hasReference].
final class ConstructionRule {
  final bool hasReference;
  final bool hasMeaning;
  final ({PillRole head, PillRole reference})? roles;
  ConstructionRule._(this.hasReference, this.hasMeaning, this.roles);

  factory ConstructionRule._parse(String code, YamlMap y) {
    final path = 'constructions.$code';
    final hasReference = y['reference'] as bool;
    final roles = y['roles'] as YamlMap?;
    if ((roles != null) != hasReference) {
      throw FormatException(
        '$path: roles are given exactly when the construction has a reference',
      );
    }
    PillRole role(String key) {
      final name = roles![key];
      return PillRole.values.asNameMap()[name] ??
          (throw FormatException('$path.roles.$key: "$name" is no pill role'));
    }

    return ConstructionRule._(
      hasReference,
      y['meaning'] as bool,
      roles == null ? null : (head: role('head'), reference: role('reference')),
    );
  }
}

/// The parameters of the exam rules of lib/data/EXAM_SCHEMA.md. A language
/// without participles or compound forms leaves out [participle] or
/// [compound], and their rules check nothing.
final class ExamRules {
  /// The clause art without `uebergeordnet`.
  final String mainClause;

  /// The word classes without `rolle`.
  final List<String> noRole;
  final List<Codes> needsBezug;
  final PersonRule? person;
  final ParticipleRule? participle;
  final CompoundRule? compound;

  ExamRules._(
    this.mainClause,
    this.noRole,
    this.needsBezug,
    this.person,
    this.participle,
    this.compound,
  );

  factory ExamRules._parse(YamlMap y) => ExamRules._(
    y['main_clause'] as String,
    _strings(y['no_role']),
    [for (final c in y['needs_bezug'] as YamlList) _codes(c)],
    y['person'] == null ? null : PersonRule._parse(y['person'] as YamlMap),
    y['participle'] == null
        ? null
        : ParticipleRule._parse(y['participle'] as YamlMap),
    y['compound'] == null
        ? null
        : CompoundRule._parse(y['compound'] as YamlMap),
  );
}

/// A word that matches [neededBy] has [key].
final class PersonRule {
  final String key;
  final Codes neededBy;
  PersonRule._(this.key, this.neededBy);

  factory PersonRule._parse(YamlMap y) =>
      PersonRule._(y['key'] as String, _codes(y['needed_by']));
}

/// A participle clause: one participle that agrees with its `bezug` outside
/// the clause.
final class ParticipleRule {
  /// What makes a word a participle.
  final Codes isA;
  final Codes form;
  final List<String> agrees;
  final String clause;
  final Map<String, String> rolleBySinnrichtung;
  final String otherRolle;

  ParticipleRule._(
    this.isA,
    this.form,
    this.agrees,
    this.clause,
    this.rolleBySinnrichtung,
    this.otherRolle,
  );

  factory ParticipleRule._parse(YamlMap y) {
    final rolle = y['rolle'] as YamlMap;
    return ParticipleRule._(
      _codes(y['is']),
      _codes(y['form']),
      _strings(y['agrees']),
      y['clause'] as String,
      Map.unmodifiable((rolle['by_sinnrichtung'] as YamlMap).cast()),
      rolle['otherwise'] as String,
    );
  }
}

/// A compound tense: a passive participle of a [tenseMap] tense and an
/// [aux] token in the mapped tense.
final class CompoundRule {
  final Codes verb;
  final Codes passive;
  final String tense;

  /// The tense of the [aux] token for each tense of the participle.
  final Map<String, String> tenseMap;

  /// The keys a passive participle of a [tenseMap] tense has.
  final List<String> marks;
  final String aux;
  final Codes auxForm;
  final String rolle;
  final List<String> agrees;
  final Codes infinitive;
  final Codes infinitiveAux;

  CompoundRule._(
    this.verb,
    this.passive,
    this.tense,
    this.tenseMap,
    this.marks,
    this.aux,
    this.auxForm,
    this.rolle,
    this.agrees,
    this.infinitive,
    this.infinitiveAux,
  );

  factory CompoundRule._parse(YamlMap y) {
    final aux = y['aux'] as YamlMap;
    final infinitive = y['infinitive'] as YamlMap;
    return CompoundRule._(
      _codes(y['verb']),
      _codes(y['passive']),
      y['tense'] as String,
      Map.unmodifiable((y['tense_map'] as YamlMap).cast()),
      _strings(y['marks']),
      aux['lemma'] as String,
      _codes(aux['form']),
      y['rolle'] as String,
      _strings(y['agrees']),
      _codes(infinitive['is']),
      _codes(infinitive['aux']),
    );
  }

  /// Whether [f] is a passive participle of a [tenseMap] tense.
  bool perfectPassive(Codes f) =>
      matches(f, passive) && tenseMap.containsKey(f[tense]);
}

List<String> _strings(Object? y) =>
    y == null ? const [] : List.unmodifiable(y as YamlList);

/// How two spellings of an answer count as the same: the language's `fold`
/// applies, and nothing else is normalized.
final class AnswerRules {
  /// Trim, and every inner run of whitespace becomes one space.
  final bool collapseSpaces;

  /// Only `first_letter` exists: the case of the first character is ignored.
  final bool ignoreFirstLetterCase;

  AnswerRules._(this.collapseSpaces, this.ignoreFirstLetterCase);

  /// Null when [y] has neither `collapse_spaces` nor `ignore_case`.
  static AnswerRules? _parse(YamlMap y) {
    if (y.containsKey('collapse_spaces') != y.containsKey('ignore_case')) {
      throw FormatException(
        'language ${y['id']}: "collapse_spaces" and "ignore_case" are given '
        'together or not at all',
      );
    }
    if (!y.containsKey('ignore_case')) return null;
    if (y['ignore_case'] != 'first_letter') {
      throw FormatException(
        'language ${y['id']}: ignore_case "${y['ignore_case']}" is not '
        '"first_letter"',
      );
    }
    return AnswerRules._(y['collapse_spaces'] as bool, true);
  }
}

final _whitespaceRun = RegExp(r'\s+');

/// [text] as [language]'s answer rules compare it; throws when the language
/// gives none.
String normalizeAnswer(Language language, String text) {
  final rules =
      language.answerRules ??
      (throw StateError('language ${language.id} has no answer rules'));
  var out = language.fold(text);
  if (rules.collapseSpaces) {
    out = out.trim().replaceAll(_whitespaceRun, ' ');
  }
  if (rules.ignoreFirstLetterCase && out.isNotEmpty) {
    out = out[0].toLowerCase() + out.substring(1);
  }
  return out;
}

Codes _codes(Object? y) => Map.unmodifiable((y as YamlMap).cast());
