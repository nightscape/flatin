import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/settings.dart';
import '../data/practice_data.dart';

part 'settings_provider.g.dart';

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  static const String _settingsKey = 'practice_settings';

  @override
  Future<Settings> build() async {
    return await _loadSettings();
  }

  Future<Settings> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson == null) {
        return await _initializeDefaultSettings();
      }

      final settings = Settings.fromJson(
        jsonDecode(settingsJson) as Map<String, dynamic>,
      );

      // Migrate: enable any new forms that were added to the YAML since
      // the settings were last saved.
      final migrated = await _migrateNewForms(settings);
      if (migrated != settings) {
        await _saveSettings(migrated);
      }
      return migrated;
    } catch (e) {
      return await _initializeDefaultSettings();
    }
  }

  Future<Settings> _migrateNewForms(Settings settings) async {
    final yamlFiles = {
      'nouns': 'lib/data/latin_nouns.yaml',
      'verbs': 'lib/data/latin_verbs.yaml',
    };

    var migrated = settings;
    for (final entry in yamlFiles.entries) {
      final dataFileId = entry.key;
      final metadata = await _getMetadata(entry.value);
      if (metadata == null) continue;

      // Migrate new form keys
      final savedForms = settings.enabledForms[dataFileId];
      if (savedForms != null) {
        final newFormKeys =
            metadata.formOrder.where((k) => !savedForms.contains(k)).toSet();
        if (newFormKeys.isNotEmpty) {
          final updated = Map<String, Set<String>>.from(migrated.enabledForms);
          updated[dataFileId] = {...savedForms, ...newFormKeys};
          migrated = migrated.copyWith(enabledForms: updated);
        }
      }

      // Migrate new types (enable by default)
      final savedTypes = settings.enabledTypes[dataFileId];
      if (savedTypes == null) {
        // No types saved yet — enable all
        final updated = Map<String, Set<String>>.from(migrated.enabledTypes);
        updated[dataFileId] = Set<String>.from(metadata.availableTypes);
        migrated = migrated.copyWith(enabledTypes: updated);
      } else {
        final newTypes = metadata.availableTypes
            .where((t) => !savedTypes.contains(t))
            .toSet();
        if (newTypes.isNotEmpty) {
          final updated = Map<String, Set<String>>.from(migrated.enabledTypes);
          updated[dataFileId] = {...savedTypes, ...newTypes};
          migrated = migrated.copyWith(enabledTypes: updated);
        }
      }
    }

    return migrated;
  }

  Future<Settings> _initializeDefaultSettings() async {
    final nounsMetadata = await _getMetadata('lib/data/latin_nouns.yaml');
    final verbsMetadata = await _getMetadata('lib/data/latin_verbs.yaml');

    final defaultSettings = Settings(
      enabledForms: {
        'nouns': Set<String>.from(nounsMetadata?.formOrder ?? []),
        'verbs': Set<String>.from(verbsMetadata?.formOrder ?? []),
      },
      enabledTypes: {
        'nouns': Set<String>.from(nounsMetadata?.availableTypes ?? []),
        'verbs': Set<String>.from(verbsMetadata?.availableTypes ?? []),
      },
    );

    await _saveSettings(defaultSettings);
    return defaultSettings;
  }

  Future<FormMetadata?> _getMetadata(String assetPath) async {
    try {
      return await getFormMetadata(assetPath);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveSettings(Settings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(settings.toJson());
      await prefs.setString(_settingsKey, settingsJson);
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Toggle a form's enabled state
  Future<void> toggleForm(String dataFileId, String formKey) async {
    final currentSettings = await future;
    final newSettings = currentSettings.toggleForm(dataFileId, formKey);
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }

  /// Enable all forms for a data file
  Future<void> enableAllForms(
    String dataFileId,
    List<String> allFormKeys,
  ) async {
    final currentSettings = await future;
    final newSettings = currentSettings.enableAllForms(dataFileId, allFormKeys);
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
  Future<void> enableAllTypes(
    String dataFileId,
    List<String> allTypes,
  ) async {
    final currentSettings = await future;
    final newSettings = currentSettings.enableAllTypes(dataFileId, allTypes);
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
  ///
  /// [allNormalizedWords] is required to handle the "all selected" collapse.
  Future<void> toggleWord(
    String normalizedWord,
    List<String> allNormalizedWords,
  ) async {
    final currentSettings = await future;
    final newSettings =
        currentSettings.toggleWord(normalizedWord, allNormalizedWords);
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }

  /// Toggle all words in a lesson on or off.
  Future<void> toggleLessonWords(
    List<String> rawLessonWords,
    List<String> allNormalizedWords,
  ) async {
    final currentSettings = await future;
    final newSettings = currentSettings.toggleLessonWords(
      rawLessonWords,
      allNormalizedWords,
    );
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }

  /// Replace the entire word selection (e.g. from the statistics screen).
  /// Pass an empty set to select all words.
  Future<void> setSelectedWords(Set<String> normalizedWords) async {
    final currentSettings = await future;
    final newSettings = currentSettings.withSelectedWords(normalizedWords);
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }

  /// Select every word (stored as the empty "no filter" state).
  Future<void> selectAllWords() async {
    final currentSettings = await future;
    final newSettings = currentSettings.selectAllWords();
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }
}
