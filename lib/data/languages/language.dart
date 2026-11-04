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

  /// The codes of each `analyse` key, in display order.
  final Map<String, List<Object>> analyse;
  final String wordClass;

  /// The `analyse` keys a `bilden` item names.
  final List<String> form;
  final List<String> rolle;
  final List<String> clauseArt;
  final List<String> sinnrichtung;
  final ExamRules rules;

  Language._(
    this.id,
    this.name,
    this.analyse,
    this.wordClass,
    this.form,
    this.rolle,
    this.clauseArt,
    this.sinnrichtung,
    this.rules,
  );

  /// Every code list by its path in the language file.
  Map<String, List<Object>> get axes => {
    for (final MapEntry(:key, :value) in analyse.entries) 'analyse.$key': value,
    'rolle': rolle,
    'clause.art': clauseArt,
    'clause.sinnrichtung': sinnrichtung,
  };

  factory Language.parse(String source) {
    final y = loadYaml(source) as YamlMap;
    final analyse = {
      for (final MapEntry(:key, :value) in (y['analyse'] as YamlMap).entries)
        key as String: List<Object>.unmodifiable(value as YamlList),
    };
    final clause = y['clause'] as YamlMap;
    final language = Language._(
      y['id'] as String,
      Map<String, String>.unmodifiable(y['name'] as YamlMap),
      analyse,
      y['word_class'] as String,
      _strings(y['form']),
      _strings(y['rolle']),
      _strings(clause['art']),
      _strings(clause['sinnrichtung']),
      ExamRules._parse(y['rules'] as YamlMap),
    );
    language._check();
    return language;
  }

  /// Throws when a rule names a key or code the language lacks.
  void _check() {
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

List<String> _strings(Object? y) => List.unmodifiable(y as YamlList);

Codes _codes(Object? y) => Map.unmodifiable((y as YamlMap).cast());
