import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/settings.dart';
import '../data/lesson_data.dart';
import '../data/practice_data.dart';

part 'settings_provider.g.dart';

const Map<String, String> _yamlFiles = {
  'nouns': 'lib/data/latin_nouns.yaml',
  'verbs': 'lib/data/latin_verbs.yaml',
};

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  static const String _settingsKey = 'practice_settings';

  @override
  Future<Settings> build() async {
    return await _loadSettings();
  }

  Future<Settings> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);

    if (settingsJson == null) {
      return Settings();
    }

    final json = jsonDecode(settingsJson) as Map<String, dynamic>;
    if (!json.containsKey('disabledForms')) {
      final converted = await _convertEnabledSets(json);
      await _saveSettings(converted);
      return converted;
    }
    return Settings.fromJson(json);
  }

  /// Convert settings written in the old enabled-set format.
  ///
  /// The old format cannot tell "the user switched this off" apart from "this
  /// entry is new in the YAML", so anything missing from a stored enabled set
  /// becomes disabled.
  Future<Settings> _convertEnabledSets(Map<String, dynamic> json) async {
    final enabledForms = _storedSets(json['enabledForms']);
    final enabledTypes = _storedSets(json['enabledTypes']);

    final disabledForms = <String, Set<String>>{};
    final disabledTypes = <String, Set<String>>{};
    for (final entry in _yamlFiles.entries) {
      final metadata = await getFormMetadata(entry.value);
      final forms = enabledForms[entry.key];
      if (forms != null) {
        disabledForms[entry.key] =
            metadata.formOrder.where((k) => !forms.contains(k)).toSet();
      }
      final types = enabledTypes[entry.key];
      if (types != null) {
        disabledTypes[entry.key] =
            metadata.availableTypes.where((t) => !types.contains(t)).toSet();
      }
    }

    final selectedWords = Set<String>.from(
      (json['selectedWords'] as List<dynamic>? ?? const [])
          .map((e) => e as String),
    );
    final deselectedWords = <String>{};
    if (selectedWords.isNotEmpty) {
      final lessons = await loadLessonData(lessonDataAsset);
      for (final name in lessons.lessonNames) {
        for (final word in lessons.lessonWords[name]!) {
          final normalized = normalizeDiacritics(word);
          if (!selectedWords.contains(normalized)) {
            deselectedWords.add(normalized);
          }
        }
      }
    }

    return Settings.fromJson(json).copyWith(
      disabledForms: disabledForms,
      disabledTypes: disabledTypes,
      deselectedWords: deselectedWords,
    );
  }

  Map<String, Set<String>> _storedSets(dynamic stored) {
    final map = stored as Map<String, dynamic>?;
    if (map == null) return {};
    return map.map(
      (key, value) => MapEntry(key, Set<String>.from(value as List)),
    );
  }

  Future<void> _saveSettings(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  /// Toggle a form's enabled state
  Future<void> toggleForm(String dataFileId, String formKey) async {
    final currentSettings = await future;
    final newSettings = currentSettings.toggleForm(dataFileId, formKey);
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }

  /// Enable all forms for a data file
  Future<void> enableAllForms(String dataFileId) async {
    final currentSettings = await future;
    final newSettings = currentSettings.enableAllForms(dataFileId);
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }

  /// Toggle a type's enabled state
  Future<void> toggleType(String dataFileId, String typeName) async {
    final currentSettings = await future;
    final newSettings = currentSettings.toggleType(dataFileId, typeName);
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }

  /// Enable all types for a data file
  Future<void> enableAllTypes(String dataFileId) async {
    final currentSettings = await future;
    final newSettings = currentSettings.enableAllTypes(dataFileId);
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }

  /// Check if a form is enabled
  bool isFormEnabled(String dataFileId, String formKey) {
    final settingsValue = state;
    if (settingsValue is! AsyncData<Settings>) {
      return true;
    }
    return settingsValue.value.isFormEnabled(dataFileId, formKey);
  }

  /// Set the input strategy for a data file
  Future<void> setInputStrategy(
    String dataFileId,
    String strategyId,
  ) async {
    final currentSettings = await future;
    final newSettings = currentSettings.setInputStrategy(
      dataFileId,
      strategyId,
    );
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }

  /// Toggle a single word's selection state.
  Future<void> toggleWord(String normalizedWord) async {
    final currentSettings = await future;
    final newSettings = currentSettings.toggleWord(normalizedWord);
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }

  /// Toggle all words in a lesson on or off.
  Future<void> toggleLessonWords(List<String> rawLessonWords) async {
    final currentSettings = await future;
    final newSettings = currentSettings.toggleLessonWords(rawLessonWords);
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }

  /// Select every word.
  Future<void> selectAllWords() async {
    final currentSettings = await future;
    final newSettings = currentSettings.selectAllWords();
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }
}
