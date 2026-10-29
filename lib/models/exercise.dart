/// The exercise contract: one exercise asks one word card and one grammar
/// card at once, in one of several kinds.
library;

import 'dart:math';

import '../data/diagnosis.dart';
import '../data/german_forms.dart';
import 'practice_item.dart';

/// A form bundle of one data file: for verbs the codes of Modus, Tempus and
/// Genus verbi (`ind.fut2.pass`), for nouns and vocab the type
/// (`U-Deklination`, `Vokabel`).
/// Produced by [bundleOf]; read by the selection and the generators.
typedef GrammarBundle = String;

const _bundleAxes = {'modus', 'tempus', 'genus_verbi'};

/// The bundle that [key] of [item] belongs to.
/// Produced here; read by the selection, the generators and the storage.
GrammarBundle bundleOf(PracticeItem item, FormKey key) {
  final index = item.formOrder.indexOf(key);
  assert(index >= 0, '"$key" is not a form of ${item.id}');
  return switch (item.dataFileId) {
    'verbs' => item.formLabels[index].axes.formatKey({
      for (final e in item.formLabels[index].features.entries)
        if (_bundleAxes.contains(e.key)) e.key: e.value,
    }),
    'nouns' || 'vocab' => item.type,
    _ => throw ArgumentError('no bundle rule for data file ${item.dataFileId}'),
  };
}

/// `grammar:<dataFileId>:<bundle>`, e.g. `grammar:verbs:ind.fut2.pass`; a
/// String, so FsrsStorage keeps it like a word card id.
/// Produced by [GrammarCardId.new]; read by the storage, the selection and
/// [Exercise].
extension type GrammarCardId._(String id) implements String {
  GrammarCardId(String dataFileId, GrammarBundle bundle)
    : id = 'grammar:$dataFileId:$bundle';

  factory GrammarCardId.of(PracticeItem item, FormKey key) =>
      GrammarCardId(item.dataFileId, bundleOf(item, key));
}

/// The kinds of exercise; `exercise.<name>.*` holds each kind's i18n keys.
/// Produced by the kind selection; read by the generators and the screen.
enum ExerciseKind {
  bestimmen,
  latDeWahl,
  deLatWahl,
  irrlaeufer,
  zuordnen,
  formBilden,
  deLatTippen,
  umformen,
  fehlerFinden,
  formenKette,
  paradigma,
  ankreuzen,
  sortieren,
}

/// One text the learner sees as an option, with the form it stands for, so a
/// wrong choice tells which card caused it.
/// Produced by the generators and the form distractors; read by the screen
/// and `attribute`.
final class FormOption {
  /// A Latin spelling or a German rendering.
  final String text;
  final FormKey formKey;

  /// The [PracticeItem.id] of the word the form belongs to.
  final String lexemeId;

  /// Null when [text] is a real form of [lexemeId] at [formKey]; otherwise how
  /// the text was built wrong (e.g. [EndingOfOtherType], [WrongStem]).
  final Diagnosis? builtWrongBy;

  const FormOption({
    required this.text,
    required this.formKey,
    required this.lexemeId,
    this.builtWrongBy,
  });
}

/// What counts as right in an exercise.
/// Produced by the generators; read by the screen and `attribute`.
sealed class ExerciseAnswer {
  const ExerciseAnswer();
}

final class ChoiceAnswer extends ExerciseAnswer {
  final List<FormOption> options;
  final FormOption right;

  ChoiceAnswer(this.options, this.right) {
    assert(
      options.where((o) => identical(o, right)).length == 1,
      'exactly one option is the right one',
    );
    assert(
      options.map((o) => o.text).toSet().length == options.length,
      'no two options read the same',
    );
  }
}

final class TypedAnswer extends ExerciseAnswer {
  final FormOption expected;

  /// Every accepted spelling, [expected]'s text first.
  final List<String> accepted;

  TypedAnswer(this.expected, this.accepted) {
    assert(accepted.isNotEmpty && accepted.first == expected.text);
  }
}

final class MatchingAnswer extends ExerciseAnswer {
  /// The right pairs; the screen shuffles each side.
  final List<(FormOption, FormOption)> pairs;

  MatchingAnswer(this.pairs) {
    assert(pairs.length >= 2);
  }
}

/// Every form belongs to one of [groups]; with [tick] there are two, the
/// asked bundle and the rest, and the learner ticks the forms of the first.
final class SortingAnswer extends ExerciseAnswer {
  /// The names the learner reads.
  final List<String> groups;

  /// Each shown form with the index of its group in [groups].
  final List<(FormOption, int)> forms;
  final bool tick;

  SortingAnswer(this.groups, this.forms, {required this.tick}) {
    assert(groups.length >= 2 && (!tick || groups.length == 2));
    assert(forms.every((f) => f.$2 >= 0 && f.$2 < groups.length));
    assert(
      forms.map((f) => f.$1.text).toSet().length == forms.length,
      'no two forms read the same',
    );
  }
}

/// What the learner gave.
/// Produced by the screen; read by `attribute`.
sealed class ExerciseResponse {
  const ExerciseResponse();
}

final class ChosenOption extends ExerciseResponse {
  final FormOption chosen;
  const ChosenOption(this.chosen);
}

final class TypedText extends ExerciseResponse {
  final String text;
  const TypedText(this.text);
}

final class MatchedPairs extends ExerciseResponse {
  final List<(FormOption, FormOption)> pairs;
  const MatchedPairs(this.pairs);
}

/// The group index the learner gave each form of a [SortingAnswer], keyed by
/// the answer's own [FormOption]s.
final class SortedForms extends ExerciseResponse {
  final Map<FormOption, int> groupOf;
  const SortedForms(this.groupOf);
}

/// One exercise: a word card and a grammar card asked through one kind.
/// Produced by an [ExerciseGenerator]; read by the screen and `attribute`.
final class Exercise {
  /// `PracticeItemCard.generateItemId` of the word.
  final String wordCardId;
  final GrammarCardId grammarCardId;
  final ExerciseKind kind;
  final String questionKey;
  final Map<String, String> questionParams;
  final ExerciseAnswer answer;

  Exercise({
    required this.wordCardId,
    required this.grammarCardId,
    required this.kind,
    required this.questionKey,
    this.questionParams = const {},
    required this.answer,
  }) {
    assert(
      grammarCardId.startsWith('grammar:${wordCardId.split(':').first}:'),
      'word $wordCardId and $grammarCardId come from two data files',
    );
  }
}

/// Thrown by [ExerciseGenerator.build] when the word has no exercise of its
/// kind for the bundle, so the caller tries another pair or kind.
final class CannotBuild implements Exception {
  final String reason;
  const CannotBuild(this.reason);

  @override
  String toString() => 'CannotBuild: $reason';
}

/// What an exercise may draw on beyond its word: it changes at runtime with
/// the course range and the settings, so it comes with each call.
/// Produced by the selection; read by the generators.
final class ExerciseContext {
  /// The bundles the learner has reached; distractors come only from these.
  final Set<GrammarBundle> unlocked;

  /// The words an exercise may take other words from.
  final List<PracticeItem> pool;
  final GermanForms german;

  /// Whether the spec kinds leave out forms that differ only in macrons.
  final bool avoidMacronTwins;

  /// Whether the learner practises a form; targets, distractors and chain
  /// steps come only from practised forms.
  final bool Function(PracticeItem word, FormLabel label) formPracticed;

  const ExerciseContext({
    required this.unlocked,
    required this.pool,
    required this.german,
    this.avoidMacronTwins = true,
    this.formPracticed = _everyForm,
  });

  static bool _everyForm(PracticeItem word, FormLabel label) => true;
}

/// Builds the exercises of one kind.
/// Implemented once per kind; read by the selection through [generatorFor].
abstract interface class ExerciseGenerator {
  ExerciseKind get kind;

  /// Throws [CannotBuild] when [word] has no exercise of [kind] in [bundle].
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  );
}

/// The one generator of [kind] in [registry].
ExerciseGenerator generatorFor(
  ExerciseKind kind,
  List<ExerciseGenerator> registry,
) => registry.singleWhere((g) => g.kind == kind);
