import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/course_provider.dart';

/// The name of the active course; a tap offers the other courses. Built only
/// when the list has two or more courses.
class CourseSwitcher extends ConsumerWidget {
  final double fontSize;
  const CourseSwitcher({super.key, required this.fontSize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(coursesProvider).requireValue;
    final active = ref.watch(activeCourseProvider).requireValue;
    final locale = Localizations.localeOf(context).languageCode;
    return PopupMenuButton<String>(
      key: const Key('course.switcher'),
      tooltip: FlutterI18n.translate(context, 'course.switch'),
      initialValue: active,
      onSelected: ref.read(activeCourseProvider.notifier).select,
      itemBuilder: (_) => [
        for (final c in courses)
          PopupMenuItem(
            key: Key('course.option.${c.id}'),
            value: c.id,
            child: Text(c.name[locale]!),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              courses.singleWhere((c) => c.id == active).name[locale]!,
              key: const Key('course.active'),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: fontSize),
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}
