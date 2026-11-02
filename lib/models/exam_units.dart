import '../data/exam.dart';

/// What one self-check unit of an exam translation is.
enum Uebersetzungseinheit { teilsatz, satz, text }

/// A model translation: its first reading, shown first, and every other
/// reading of the variant strings it comes from.
final class ModelSegment {
  final String shown;
  final List<String> others;
  const ModelSegment(this.shown, this.others);

  /// The first entry of [variants] gives the shown reading.
  factory ModelSegment.of(List<String> variants) {
    final readings = [for (final v in variants) ...expand(v)];
    final shown = readings.first;
    return ModelSegment(shown, {...readings}.where((r) => r != shown).toList());
  }
}

/// The German of a group of Latin tokens, in its first reading.
typedef AlignedWords = ({List<String> tokens, String de});

final class ExamUnit {
  final String id;

  /// The tokens of the unit, one list per sentence, in text order.
  final List<List<ExamToken>> lines;
  final List<ModelSegment> segments;
  final List<AlignedWords> alignment;
  const ExamUnit(this.id, this.lines, this.segments, this.alignment);
}

/// The units of [exam] for [einheit]: each clause with its own model, each
/// sentence with its first `de`, or the whole text with every sentence's.
List<ExamUnit> examUnits(Exam exam, Uebersetzungseinheit einheit) =>
    switch (einheit) {
      Uebersetzungseinheit.teilsatz => [
        for (final s in exam.saetze)
          for (final c in s.teilsaetze)
            ExamUnit(
              c.id,
              [
                [
                  for (final t in s.tokens)
                    if (c.tokens.contains(t.id)) t,
                ],
              ],
              [if (c.de.isNotEmpty) ModelSegment.of(c.de)],
              _aligned([c]),
            ),
      ],
      Uebersetzungseinheit.satz => [
        for (final s in exam.saetze)
          ExamUnit(
            s.id,
            [s.tokens],
            [ModelSegment.of(s.de)],
            _aligned(s.teilsaetze),
          ),
      ],
      Uebersetzungseinheit.text => [
        if (exam.saetze.isNotEmpty)
          ExamUnit(
            'text',
            [for (final s in exam.saetze) s.tokens],
            [for (final s in exam.saetze) ModelSegment.of(s.de)],
            _aligned([for (final s in exam.saetze) ...s.teilsaetze]),
          ),
      ],
    };

List<AlignedWords> _aligned(List<Clause> clauses) => [
  for (final c in clauses)
    for (final a in c.ausrichtung) (tokens: a.tokens, de: expand(a.de).first),
];
