import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../models/course_filter.dart';

const settingsBackground = Color(0xFFE5E5E5);
const settingsCheckboxColor = Color(0xFFD0D0D0);

/// The page frame every settings page shares.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.titleKey,
    required this.title,
    required this.body,
    this.leading,
  });

  final Key titleKey;
  final String title;
  final Widget body;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: settingsBackground,
      appBar: AppBar(
        backgroundColor: settingsBackground,
        elevation: 0,
        leading: leading,
        title: Text(
          title,
          key: titleKey,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: body,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    ),
  );
}

/// Why the course holds something back, in a few words.
String gapText(BuildContext context, CourseGap gap) => switch (gap) {
  OutsideRange() => FlutterI18n.translate(context, 'settings.outsideRange'),
  GrammarOutsideRange() =>
    FlutterI18n.translate(context, 'settings.grammarOutsideRange'),
  FromLesson(:final lesson) => FlutterI18n.translate(
    context,
    'settings.fromLesson',
    translationParams: {'lesson': '$lesson'},
  ),
};

Color rowTextColor(BuildContext context, {required bool greyed}) =>
    greyed ? Theme.of(context).disabledColor : Colors.black;
