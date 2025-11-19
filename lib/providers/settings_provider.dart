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
        // Initialize with all forms enabled
        return await _initializeDefaultSettings();
      }

      final json = jsonDecode(settingsJson) as Map<String, dynamic>;
      return Settings.fromJson(json);
    } catch (e) {
      // If loading fails, return default settings
      return await _initializeDefaultSettings();
    }
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
      // Default to enabled if settings not loaded yet
      return true;
    }
    return settingsValue.value.isFormEnabled(dataFileId, formKey);
  }
}
