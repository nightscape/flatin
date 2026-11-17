import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/exam.dart';
import '../data/languages/language.dart';
import '../models/course.dart';

/// The imported exam packs of each course, stored as their source text by
/// pack id under the course's key.
class ExamStorage {
  static const String _storageKey = 'exam_packs';

  static Future<Map<String, String>> _sources(CourseScope scope) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(scope.key(_storageKey));
    if (stored == null) return {};
    return (jsonDecode(stored) as Map<String, dynamic>).cast<String, String>();
  }

  static Future<void> _save(
    CourseScope scope,
    Map<String, String> sources,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(scope.key(_storageKey), jsonEncode(sources));
  }

  /// Every stored pack of the active course, in import order.
  static Future<List<Exam>> load(Language language, CourseScope scope) async =>
      [
        for (final source in (await _sources(scope)).values)
          parseExam(source, language),
      ];

  /// Stores [source] under its pack id, in place of a pack of the same id of
  /// the active course. Throws [ExamRejected] and stores nothing when the pack
  /// breaks a rule or belongs to another course.
  static Future<Exam> add(
    String source,
    Language language,
    CourseScope scope,
  ) async {
    final exam = parseExam(source, language);
    checkExamCourse(
      exam,
      courseIds: [for (final c in scope.all) c.id],
      active: scope.active.id,
    );
    final sources = await _sources(scope)
      ..remove(exam.id);
    await _save(scope, {...sources, exam.id: source});
    return exam;
  }

  static Future<void> delete(String id, CourseScope scope) async {
    final sources = await _sources(scope);
    assert(sources.containsKey(id), 'no stored pack "$id"');
    await _save(scope, sources..remove(id));
  }
}
