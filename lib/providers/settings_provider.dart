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
      final savedForms = settings.enabledForms[dataFileId];
      if (savedForms == null) continue;

      final currentFormOrder = await _getFormOrder(entry.value);
      final newKeys =
          currentFormOrder.where((k) => !savedForms.contains(k)).toSet();
      if (newKeys.isEmpty) continue;

      final updated = Map<String, Set<String>>.from(migrated.enabledForms);
      updated[dataFileId] = {...savedForms, ...newKeys};
      migrated = migrated.copyWith(enabledForms: updated);
    }

    return migrated;
  }

  Future<Settings> _initializeDefaultSettings() async {
    // Load form orders from both YAML files
    final nounsFormOrder = await _getFormOrder('lib/data/latin_nouns.yaml');
    final verbsFormOrder = await _getFormOrder('lib/data/latin_verbs.yaml');

    final defaultSettings = Settings(
      enabledForms: {
        'nouns': Set<String>.from(nounsFormOrder),
        'verbs': Set<String>.from(verbsFormOrder),
      },
    );

    // Save default settings
    await _saveSettings(defaultSettings);
    return defaultSettings;
  }

  Future<List<String>> _getFormOrder(String assetPath) async {
    try {
      final formMetadata = await getFormMetadata(assetPath);
      return formMetadata.formOrder;
    } catch (e) {
      return [];
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

  /// Toggle a lesson's selection state.
  ///
  /// [allLessons] is required because an empty selection means "all lessons",
  /// so toggling one off from the "all" state needs to materialize the full
  /// list first.
  Future<void> toggleLesson(
    String lessonName,
    List<String> allLessons,
  ) async {
    final currentSettings = await future;
    final newSettings = currentSettings.toggleLesson(lessonName, allLessons);
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }

  /// Select every lesson (stored as the empty "no filter" state).
  Future<void> selectAllLessons() async {
    final currentSettings = await future;
    final newSettings = currentSettings.selectAllLessons();
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }
}
