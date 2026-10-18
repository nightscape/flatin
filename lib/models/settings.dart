import '../data/lesson_data.dart';
import '../data/settings_conversion.dart'
    show settingsVersion, settingsVersionField;
import 'form_label.dart';
import 'lesson_range.dart';

/// What the learner said about one entry, against what the course says.
enum Override { forcedOn, forcedOff, none }

/// Settings model holding the user's practice selection.
///
/// The course ranges say what the learner has been taught; the forced sets
/// say where the learner overruled that. The off sets are the ones the app
/// has always stored, so stored settings of the previous format read as
/// forced-off without conversion.
class Settings {
  /// Map of data file identifier to set of form keys the user switched off
  /// e.g., {"nouns": {"genitive_singular", ...}, ...}
  final Map<String, Set<String>> disabledForms;

  /// Data file identifier → axis id → the value codes the user switched off,
  /// e.g. {"verbs": {"genus_verbi": {"pass"}}}. Switching off one value hides
  /// every form that names it.
  final Map<String, Map<String, Set<String>>> disabledFeatures;

  /// Map of data file identifier to set of type names the user switched off
  /// e.g., {"nouns": {"O-Deklination-maskulinum", ...}, ...}
  final Map<String, Set<String>> disabledTypes;

  /// Map of data file identifier to input strategy id
  /// e.g., {"verbs": "dropdown_all_forms", "nouns": "text_field"}
  final Map<String, String> inputStrategyIds;

  /// Normalized words the user switched off; every other word is practised.
  /// Can be set from either the settings screen (lesson-based) or the
  /// statistics screen (performance-based).
  final Set<String> deselectedWords;

  /// The lessons whose words the learner practises.
  final LessonRange courseWords;

  /// The lessons whose grammar the learner practises. While
  /// [grammarFollowsWords] it is kept at 1..[courseWords].to.
  final LessonRange courseGrammar;

  /// Whether the grammar range trails the word range.
  final bool grammarFollowsWords;

  /// Normalized words the learner practises although the course has not
  /// reached them.
  final Set<String> forcedOnWords;

  /// Data file id -> type names practised ahead of the course.
  final Map<String, Set<String>> forcedOnTypes;

  /// Data file id -> form keys practised ahead of the course.
  final Map<String, Set<String>> forcedOnForms;

  Settings({
    Map<String, Set<String>>? disabledForms,
    Map<String, Map<String, Set<String>>>? disabledFeatures,
    Map<String, Set<String>>? disabledTypes,
    Map<String, String>? inputStrategyIds,
    Set<String>? deselectedWords,
    LessonRange? courseWords,
    LessonRange? courseGrammar,
    this.grammarFollowsWords = true,
    Set<String>? forcedOnWords,
    Map<String, Set<String>>? forcedOnTypes,
    Map<String, Set<String>>? forcedOnForms,
  })  : disabledForms = disabledForms ?? {},
        disabledFeatures = disabledFeatures ?? {},
        disabledTypes = disabledTypes ?? {},
        inputStrategyIds = inputStrategyIds ?? {},
        deselectedWords = deselectedWords ?? {},
        courseWords = courseWords ?? LessonRange.full,
        courseGrammar = courseGrammar ?? LessonRange.full,
        forcedOnWords = forcedOnWords ?? {},
        forcedOnTypes = forcedOnTypes ?? {},
        forcedOnForms = forcedOnForms ?? {} {
    assert(
      this.forcedOnWords.intersection(this.deselectedWords).isEmpty,
      'a word is both forced on and forced off',
    );
    assert(
      _disjoint(this.forcedOnTypes, this.disabledTypes),
      'a type is both forced on and forced off',
    );
    assert(
      _disjoint(this.forcedOnForms, this.disabledForms),
      'a form is both forced on and forced off',
    );
  }

  Settings copyWith({
    Map<String, Set<String>>? disabledForms,
    Map<String, Map<String, Set<String>>>? disabledFeatures,
    Map<String, Set<String>>? disabledTypes,
    Map<String, String>? inputStrategyIds,
    Set<String>? deselectedWords,
    LessonRange? courseWords,
    LessonRange? courseGrammar,
    bool? grammarFollowsWords,
    Set<String>? forcedOnWords,
    Map<String, Set<String>>? forcedOnTypes,
    Map<String, Set<String>>? forcedOnForms,
  }) {
    return Settings(
      disabledForms: disabledForms ?? this.disabledForms,
      disabledFeatures: disabledFeatures ?? this.disabledFeatures,
      disabledTypes: disabledTypes ?? this.disabledTypes,
      inputStrategyIds: inputStrategyIds ?? this.inputStrategyIds,
      deselectedWords: deselectedWords ?? this.deselectedWords,
      courseWords: courseWords ?? this.courseWords,
      courseGrammar: courseGrammar ?? this.courseGrammar,
      grammarFollowsWords: grammarFollowsWords ?? this.grammarFollowsWords,
      forcedOnWords: forcedOnWords ?? this.forcedOnWords,
      forcedOnTypes: forcedOnTypes ?? this.forcedOnTypes,
      forcedOnForms: forcedOnForms ?? this.forcedOnForms,
    );
  }

  /// The lessons whose grammar is practised right now.
  LessonRange get effectiveGrammar =>
      grammarFollowsWords ? LessonRange(1, courseWords.to) : courseGrammar;

  Settings withWordRange(LessonRange range) => copyWith(
        courseWords: range,
        courseGrammar:
            grammarFollowsWords ? LessonRange(1, range.to) : courseGrammar,
      );

  Settings withGrammarRange(LessonRange range) {
    assert(!grammarFollowsWords, 'the grammar range follows the word range');
    return copyWith(courseGrammar: range);
  }

  Settings withGrammarFollowsWords(bool follows) => copyWith(
        grammarFollowsWords: follows,
        courseGrammar: follows ? LessonRange(1, courseWords.to) : courseGrammar,
      );

  /// Drops every override the learner made; the course ranges stay.
  Settings clearOverrides() => copyWith(
        disabledForms: {},
        disabledFeatures: {},
        disabledTypes: {},
        deselectedWords: {},
        forcedOnWords: {},
        forcedOnTypes: {},
        forcedOnForms: {},
      );

  Override overrideOfWord(String normalizedWord) {
    if (deselectedWords.contains(normalizedWord)) return Override.forcedOff;
    if (forcedOnWords.contains(normalizedWord)) return Override.forcedOn;
    return Override.none;
  }

  Override overrideOfType(String dataFileId, String typeName) =>
      _overrideIn(disabledTypes, forcedOnTypes, dataFileId, typeName);

  Override overrideOfForm(String dataFileId, FormKey formKey) =>
      _overrideIn(disabledForms, forcedOnForms, dataFileId, formKey);

  /// Flips what the learner sees for one word; [inRange] is the course
  /// verdict, so an override is stored only where it differs from it.
  Settings toggleWord(String normalizedWord, {required bool inRange}) {
    final (off, on) = _flip(overrideOfWord(normalizedWord), inRange);
    return copyWith(
      deselectedWords: _withEntry(deselectedWords, normalizedWord, off),
      forcedOnWords: _withEntry(forcedOnWords, normalizedWord, on),
    );
  }

  Settings toggleType(
    String dataFileId,
    String typeName, {
    required bool inRange,
  }) {
    final (off, on) = _flip(overrideOfType(dataFileId, typeName), inRange);
    return copyWith(
      disabledTypes: _withKey(disabledTypes, dataFileId, typeName, off),
      forcedOnTypes: _withKey(forcedOnTypes, dataFileId, typeName, on),
    );
  }

  Settings toggleForm(
    String dataFileId,
    FormKey formKey, {
    required bool inRange,
  }) {
    final (off, on) = _flip(overrideOfForm(dataFileId, formKey), inRange);
    return copyWith(
      disabledForms: _withKey(disabledForms, dataFileId, formKey, off),
      forcedOnForms: _withKey(forcedOnForms, dataFileId, formKey, on),
    );
  }

  /// Whether one value of one axis is practised, e.g. the Passive voice
  bool isFeatureEnabled(String dataFileId, String axisId, String code) {
    return !(disabledFeatures[dataFileId]?[axisId]?.contains(code) ?? false);
  }

  /// Whether the form's own switch is on, whatever its features say.
  bool isFormSwitchedOn(String dataFileId, FormKey formKey) {
    return !(disabledForms[dataFileId]?.contains(formKey) ?? false);
  }

  /// The (axis id, value code) pairs the label names that are switched off.
  List<(String axisId, String code)> offFeaturesOf(
    String dataFileId,
    FormLabel label,
  ) =>
      [
        for (final f in label.features.entries)
          if (!isFeatureEnabled(dataFileId, f.key, f.value)) (f.key, f.value),
      ];

  /// Check if a type is enabled for a given data file
  bool isTypeEnabled(String dataFileId, String typeName) {
    return !(disabledTypes[dataFileId]?.contains(typeName) ?? false);
  }

  /// Get the input strategy id for a data file (default: text_field)
  String getInputStrategyId(String dataFileId) {
    return inputStrategyIds[dataFileId] ?? 'text_field';
  }

  /// Set the input strategy for a data file
  Settings setInputStrategy(String dataFileId, String strategyId) {
    final newMap = Map<String, String>.from(inputStrategyIds);
    newMap[dataFileId] = strategyId;
    return copyWith(inputStrategyIds: newMap);
  }

  /// Toggle one axis value for a given data file
  Settings toggleFeature(String dataFileId, String axisId, String code) {
    final next = {
      for (final file in disabledFeatures.entries)
        file.key: {
          for (final axis in file.value.entries)
            axis.key: Set<String>.from(axis.value),
        },
    };
    final codes = next
        .putIfAbsent(dataFileId, () => {})
        .putIfAbsent(axisId, () => <String>{});
    if (!codes.remove(code)) {
      codes.add(code);
    }
    return copyWith(disabledFeatures: next);
  }

  /// Enable every form for a given data file, by key and by feature
  Settings enableAllForms(String dataFileId) {
    final newDisabledForms = Map<String, Set<String>>.from(disabledForms);
    newDisabledForms.remove(dataFileId);
    final newDisabledFeatures =
        Map<String, Map<String, Set<String>>>.from(disabledFeatures);
    newDisabledFeatures.remove(dataFileId);
    return copyWith(
      disabledForms: newDisabledForms,
      disabledFeatures: newDisabledFeatures,
    );
  }

  /// Enable every type for a given data file
  Settings enableAllTypes(String dataFileId) {
    final newDisabledTypes = Map<String, Set<String>>.from(disabledTypes);
    newDisabledTypes.remove(dataFileId);
    return copyWith(disabledTypes: newDisabledTypes);
  }

  /// Whether a specific normalized word is selected.
  bool isWordSelected(String normalizedWord) {
    return !deselectedWords.contains(normalizedWord);
  }

  /// Whether all words in a lesson are selected.
  bool isLessonFullySelected(List<String> rawWords) {
    return rawWords.every((w) => isWordSelected(normalizeDiacritics(w)));
  }

  /// Whether some (but not all) words in a lesson are selected.
  bool isLessonPartiallySelected(List<String> rawWords) {
    final selected = rawWords.where(
      (w) => isWordSelected(normalizeDiacritics(w)),
    );
    return selected.isNotEmpty && selected.length < rawWords.length;
  }

  /// Toggle all words in a lesson.
  ///
  /// If all lesson words are selected, deselect them all.
  /// Otherwise, select all of them.
  Settings toggleLessonWords(List<String> rawLessonWords) {
    final lessonNormalized = rawLessonWords.map(normalizeDiacritics);
    final next = Set<String>.from(deselectedWords);

    if (isLessonFullySelected(rawLessonWords)) {
      next.addAll(lessonNormalized);
    } else {
      next.removeAll(lessonNormalized);
    }
    return copyWith(deselectedWords: next);
  }

  /// Select every word.
  Settings selectAllWords() {
    return copyWith(deselectedWords: <String>{});
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      settingsVersionField: settingsVersion,
      'disabledForms': disabledForms.map(
        (key, value) => MapEntry(key, value.toList()),
      ),
      'disabledFeatures': disabledFeatures.map(
        (file, axes) => MapEntry(
          file,
          axes.map((axis, codes) => MapEntry(axis, codes.toList())),
        ),
      ),
      'disabledTypes': disabledTypes.map(
        (key, value) => MapEntry(key, value.toList()),
      ),
      'inputStrategyIds': inputStrategyIds,
      'deselectedWords': deselectedWords.toList(),
      'courseWords': courseWords.toJson(),
      'courseGrammar': courseGrammar.toJson(),
      'grammarFollowsWords': grammarFollowsWords,
      'forcedOnWords': forcedOnWords.toList(),
      'forcedOnTypes': forcedOnTypes.map(
        (key, value) => MapEntry(key, value.toList()),
      ),
      'forcedOnForms': forcedOnForms.map(
        (key, value) => MapEntry(key, value.toList()),
      ),
    };
  }

  /// Create from JSON
  factory Settings.fromJson(Map<String, dynamic> json) {
    assert(
      json[settingsVersionField] == settingsVersion,
      'stored settings are of another version; convert them first',
    );
    final disabledFormsMap = json['disabledForms'] as Map<String, dynamic>?;
    final featureMap = json['disabledFeatures'] as Map<String, dynamic>?;
    final disabledTypesMap = json['disabledTypes'] as Map<String, dynamic>?;
    final strategyMap = json['inputStrategyIds'] as Map<String, dynamic>?;
    final wordList = json['deselectedWords'] as List<dynamic>?;
    final wordRange = json['courseWords'] as Map<String, dynamic>?;
    final grammarRange = json['courseGrammar'] as Map<String, dynamic>?;
    final forcedWordList = json['forcedOnWords'] as List<dynamic>?;
    final forcedTypeMap = json['forcedOnTypes'] as Map<String, dynamic>?;
    final forcedFormMap = json['forcedOnForms'] as Map<String, dynamic>?;

    final disabledForms = disabledFormsMap?.map(
          (key, value) => MapEntry(key, Set<String>.from(value as List)),
        ) ??
        <String, Set<String>>{};
    final disabledTypes = disabledTypesMap?.map(
          (key, value) => MapEntry(key, Set<String>.from(value as List)),
        ) ??
        <String, Set<String>>{};
    final deselectedWords = wordList != null
        ? Set<String>.from(wordList.map((e) => e as String))
        : <String>{};
    final forcedOnWords = forcedWordList != null
        ? Set<String>.from(forcedWordList.map((e) => e as String))
        : <String>{};
    final forcedOnTypes = forcedTypeMap?.map(
          (key, value) => MapEntry(key, Set<String>.from(value as List)),
        ) ??
        <String, Set<String>>{};
    final forcedOnForms = forcedFormMap?.map(
          (key, value) => MapEntry(key, Set<String>.from(value as List)),
        ) ??
        <String, Set<String>>{};

    _rejectContradictions(forcedOnWords, deselectedWords, 'word');
    _rejectContradictionsByFile(forcedOnTypes, disabledTypes, 'type');
    _rejectContradictionsByFile(forcedOnForms, disabledForms, 'form');

    return Settings(
      disabledForms: disabledForms,
      disabledFeatures: featureMap?.map(
            (file, axes) => MapEntry(
              file,
              (axes as Map<String, dynamic>).map(
                (axis, codes) =>
                    MapEntry(axis, Set<String>.from(codes as List)),
              ),
            ),
          ) ??
          {},
      disabledTypes: disabledTypes,
      inputStrategyIds:
          strategyMap?.map((key, value) => MapEntry(key, value as String)) ??
              {},
      deselectedWords: deselectedWords,
      courseWords: wordRange == null ? null : LessonRange.fromJson(wordRange),
      courseGrammar:
          grammarRange == null ? null : LessonRange.fromJson(grammarRange),
      grammarFollowsWords: json['grammarFollowsWords'] as bool? ?? true,
      forcedOnWords: forcedOnWords,
      forcedOnTypes: forcedOnTypes,
      forcedOnForms: forcedOnForms,
    );
  }
}

/// Stored settings that put one entry in both its on and its off set say two
/// things at once; the app refuses them in release builds too.
void _rejectContradictions(Set<String> on, Set<String> off, String what) {
  final both = on.intersection(off);
  if (both.isNotEmpty) {
    throw StateError(
      'stored settings force $what "${both.first}" both on and off',
    );
  }
}

void _rejectContradictionsByFile(
  Map<String, Set<String>> on,
  Map<String, Set<String>> off,
  String what,
) {
  for (final file in on.entries) {
    _rejectContradictions(
      file.value,
      off[file.key] ?? const {},
      '$what of "${file.key}"',
    );
  }
}

Override _overrideIn(
  Map<String, Set<String>> off,
  Map<String, Set<String>> on,
  String dataFileId,
  String key,
) {
  if (off[dataFileId]?.contains(key) ?? false) return Override.forcedOff;
  if (on[dataFileId]?.contains(key) ?? false) return Override.forcedOn;
  return Override.none;
}

bool _disjoint(
  Map<String, Set<String>> on,
  Map<String, Set<String>> off,
) =>
    on.entries.every(
      (file) => file.value.intersection(off[file.key] ?? const {}).isEmpty,
    );

/// The off/on membership that flips the effective verdict, given what the
/// course says: an override is kept only where it differs from [inRange].
(bool off, bool on) _flip(Override current, bool inRange) {
  final effective = switch (current) {
    Override.forcedOff => false,
    Override.forcedOn => true,
    Override.none => inRange,
  };
  final wanted = !effective;
  if (wanted == inRange) return (false, false);
  return (!wanted, wanted);
}

Set<String> _withEntry(Set<String> entries, String entry, bool present) {
  final next = Set<String>.from(entries);
  if (present) {
    next.add(entry);
  } else {
    next.remove(entry);
  }
  return next;
}

Map<String, Set<String>> _withKey(
  Map<String, Set<String>> byFile,
  String dataFileId,
  String key,
  bool present,
) {
  final next = Map<String, Set<String>>.from(byFile);
  next[dataFileId] = _withEntry(next[dataFileId] ?? const {}, key, present);
  return next;
}
