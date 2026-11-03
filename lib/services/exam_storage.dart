import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/exam.dart';
import '../data/languages/language.dart';

/// The imported exam packs, stored as their source text by pack id.
class ExamStorage {
  static const String _storageKey = 'exam_packs';

  static Future<Map<String, String>> _sources() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored == null) return {};
    return (jsonDecode(stored) as Map<String, dynamic>).cast<String, String>();
  }

  static Future<void> _save(Map<String, String> sources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(sources));
  }

  /// Every stored pack, in import order.
  static Future<List<Exam>> load(Language language) async => [
    for (final source in (await _sources()).values) parseExam(source, language),
  ];

  /// Stores [source] under its pack id, in place of a pack of the same id.
  /// Throws [ExamRejected] and stores nothing when the pack breaks a rule.
  static Future<Exam> add(String source, Language language) async {
    final exam = parseExam(source, language);
    final sources = await _sources()
      ..remove(exam.id);
    await _save({...sources, exam.id: source});
    return exam;
  }

  static Future<void> delete(String id) async {
    final sources = await _sources();
    assert(sources.containsKey(id), 'no stored pack "$id"');
    await _save(sources..remove(id));
  }
}
