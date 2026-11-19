import 'package:flutter/material.dart';

import '../../data/exam.dart';

final _inline = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');

/// The task text of an exam: paragraphs separated by a blank line, with
/// `**bold**` and `*italic*`. A `{{n}}` marker shows as a numbered blank.
class ExamMarkdown extends StatelessWidget {
  final String text;
  const ExamMarkdown(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final shown = text.replaceAllMapped(gapMarker, (m) => '(${m[1]}) ____');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, paragraph) in shown.split(RegExp(r'\n\s*\n')).indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text.rich(
              TextSpan(children: markdownSpans(paragraph.trim())),
              key: Key('exam.markdown.$i'),
            ),
          ),
      ],
    );
  }
}

List<InlineSpan> markdownSpans(String paragraph) {
  final spans = <InlineSpan>[];
  var from = 0;
  for (final m in _inline.allMatches(paragraph)) {
    spans.add(TextSpan(text: paragraph.substring(from, m.start)));
    spans.add(
      m[1] != null
          ? TextSpan(
              text: m[1],
              style: const TextStyle(fontWeight: FontWeight.bold),
            )
          : TextSpan(
              text: m[2],
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
    );
    from = m.end;
  }
  spans.add(TextSpan(text: paragraph.substring(from)));
  return spans;
}
