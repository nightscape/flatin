import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/settings.dart';
import '../data/asset_text.dart';
import '../data/lesson_data.dart';
import '../data/settings_conversion.dart';

part 'settings_provider.g.dart';

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
    if (json[settingsVersionField] == settingsVersion) {
      return Settings.fromJson(json);
    }
    final converted = Settings.fromJson(await _convert(json));
    await _saveSettings(converted);
    return converted;
  }

  /// Reads settings of the v0 or v1 format against the current data.
  Future<Map<String, dynamic>> _convert(Map<String, dynamic> json) async {
    final map = MigrationMap.parse(
      await loadAssetText('lib/data/migration_v2.yaml'),
    );
    final converted = convertSettingsV2(json, map);
    final isV0 = !json.containsKey('disabledForms');
    if (isV0) {
      converted['deselectedWords'] = await _deselectedFromSelected(
        json['selectedWords'] as List<dynamic>? ?? const [],
        map,
      );
    }
    return converted;
  }

  /// The v0 format stored the words that were ON; every lesson word that is
  /// not among them is off. An empty set meant "no selection yet".
  Future<List<String>> _deselectedFromSelected(
    List<dynamic> selectedWords,
    MigrationMap map,
  ) async {
    if (selectedWords.isEmpty) return [];
    final selected = {
      for (final word in selectedWords) map.wordMap['$word'] ?? '$word',
    };
    final lessons = await loadLessonData(lessonDataAssets);
    return {
      for (final name in lessons.lessonNames)
        for (final word in lessons.lessonWords[name]!)
          if (!selected.contains(normalizeDiacritics(word))) normalizeDiacritics(word),
    }.toList();
  }

  Future<void> _saveSettings(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  /// Toggle a form's enabled state.
  Future<void> toggleForm(
    String dataFileId,
    String formKey, {
    required bool inRange,
  }) async {
    final currentSettings = await future;
    final newSettings =
        currentSettings.toggleForm(dataFileId, formKey, inRange: inRange);
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }

  /// Toggle one axis value, e.g. the Passive voice of the verbs
  Future<void> toggleFeature(
    String dataFileId,
    String axisId,
    String code,
  ) async {
    final currentSettings = await future;
    final newSettings = currentSettings.toggleFeature(dataFileId, axisId, code);
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
  Future<void> toggleType(
    String dataFileId,
    String typeName, {
    required bool inRange,
  }) async {
    final currentSettings = await future;
    final newSettings =
        currentSettings.toggleType(dataFileId, typeName, inRange: inRange);
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
  Future<void> toggleWord(
    String normalizedWord, {
    required bool inRange,
  }) async {
    final currentSettings = await future;
    final newSettings =
        currentSettings.toggleWord(normalizedWord, inRange: inRange);
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
