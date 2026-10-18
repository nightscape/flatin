/// The ESEL steps of one form: Erkennen, Stamm, Endung, Lautregel, and
/// Verbinden or Merken. Every step is built from the item's derivation trace,
/// so no step text is written per word; the screens translate the keys.
library;

import 'dart:math';

import '../models/derivation.dart';
import '../models/practice_item.dart';
import 'diagnosis.dart';
import 'explanation.dart';

enum EselKind { erkennen, stamm, endung, lautregel, verbinden, merken }

/// One choice of a step. Either [text] (a Latin spelling) or [textKey] (an
/// i18n key for a phrase such as "keine Lautregel") carries the option.
final class EselOption {
  final String text;
  final String? textKey;
  final bool isRight;

  const EselOption(this.text, {required this.isRight}) : textKey = null;

  const EselOption.phrase(this.textKey, {required this.isRight}) : text = '';

  /// What makes two options the same choice.
  String get identity => textKey ?? text;
}

final class EselStep {
  final EselKind kind;
  final String questionKey;
  final Map<String, String> questionParams;

  /// The text shown once the step is done; empty when [answerKey] names it.
  final String answer;

  /// The i18n key of the answer when it is a phrase, else null.
  final String? answerKey;

  /// Exactly one option is right; empty for merken and for absent steps.
  final List<EselOption> options;

  /// The trace has no such part: the step is shown done and dashed.
  final bool absent;

  /// What the rules would give for an irregular form, if they give anything.
  final String? regular;

  EselStep({
    required this.kind,
    required this.questionKey,
    this.questionParams = const {},
    this.answer = '',
    this.answerKey,
    this.options = const [],
    this.absent = false,
    this.regular,
  })  : assert(answer.isEmpty != (answerKey == null)),
        assert(
          options.where((option) => option.isRight).length ==
              (options.isEmpty ? 0 : 1),
          'a step needs exactly one right option',
        ),
        assert(options.length != 1, 'a question needs a distractor'),
        assert(options.length <= 3),
        assert(
          options.map((option) => option.identity).toSet().length ==
              options.length,
          'two options are the same text',
        ),
        assert(
          options.map((option) => norm(option.identity)).toSet().length ==
              options.length,
          'two options differ only in quantity marks',
        );
}

/// The word class a type belongs to: an erkennen distractor is a type of the
/// same class, so the choice is between the types a learner weighs against
/// each other. Every type an item has is listed (pinned by a test over the
/// data), abstract and internal ending tables are not.
const eselWordClasses = <String, String>{
  'A-Deklination': 'deklination',
  'E-Deklination': 'deklination',
  'E-Deklination-Konsonantstamm': 'deklination',
  'Konsonantische-Deklination-i-mf': 'deklination',
  'Konsonantische-Deklination-i-n': 'deklination',
  'Konsonantische-Deklination-mf': 'deklination',
  'Konsonantische-Deklination-n': 'deklination',
  'O-Deklination-maskulinum': 'deklination',
  'O-Deklination-neutrum': 'deklination',
  'U-Deklination': 'deklination',
  'Adjektiv-a-o': 'adjektiv',
  'Adjektiv-a-o-er': 'adjektiv',
  'Adjektiv-dreiendig': 'adjektiv',
  'Adjektiv-zweiendig': 'adjektiv',
  'Pronomen-hic': 'pronomen',
  'Pronomen-idem': 'pronomen',
  'Pronomen-ille': 'pronomen',
  'Pronomen-ipse': 'pronomen',
  'Pronomen-is': 'pronomen',
  'Pronomen-iste': 'pronomen',
  'Pronomen-personal': 'pronomen',
  'Pronomen-qui': 'pronomen',
  'Pronomen-quis': 'pronomen',
  'Numerale-duo': 'numerale',
  'Numerale-milia': 'numerale',
  'Numerale-tres': 'numerale',
  'Numerale-unus': 'numerale',
  'A-Konjugation': 'konjugation',
  'E-Konjugation': 'konjugation',
  'I-Konjugation': 'konjugation',
  'Konsonantische': 'konjugation',
  'Mischkonjugation': 'konjugation',
  'Unregelmäßig': 'konjugation',
  'esse-Kompositum': 'konjugation',
  'esse-Typ': 'konjugation',
};

/// The steps of [formKey] of [item], in the fixed ESEL order. [diagnosis] is
/// the learner's mistake when there is one; without it the steps are the same,
/// only the distractors are drawn from the data alone.
List<EselStep> eselSteps(
  PracticeItem item,
  FormKey formKey, {
  Diagnosis? diagnosis,
}) {
  final int index = item.formOrder.indexOf(formKey);
  assert(index >= 0, '"$formKey" is not a form of "${item.translation}"');
  final String label = describeLabels([item.formLabels[index]]);
  final form = item.derivation.forms[formKey]!;

  return switch (form) {
    final GeneratedForm generated when _isDictionaryForm(item, formKey, generated) => [
        _erkennen(item, formKey),
        _absent(EselKind.stamm, {'word': headword(item)}),
        _absent(EselKind.endung, {'label': label}),
        _absent(EselKind.lautregel, {'label': label}),
        EselStep(
          kind: EselKind.merken,
          questionKey: 'esel.question.given',
          questionParams: {'label': label, 'result': generated.result},
          answerKey: 'esel.dictionaryForm',
        ),
      ],
    final GeneratedForm generated => [
        _erkennen(item, formKey),
        _stamm(item, formKey, generated, diagnosis),
        _endung(item, formKey, generated, label, diagnosis),
        _lautregel(item, formKey, generated.sandhiRule, label),
      ],
    final ComposedForm composed => [
        _erkennen(item, formKey),
        _absent(EselKind.stamm, {'word': headword(item)}),
        _absent(EselKind.endung, {'label': label}),
        _lautregel(item, formKey, _seamRule(composed), label),
        _verbinden(item, formKey, composed, label),
      ],
    IrregularForm(:final result, :final regular) => [
        _erkennen(item, formKey),
        _absent(EselKind.stamm, {'word': headword(item)}),
        _absent(EselKind.endung, {'label': label}),
        _absent(EselKind.lautregel, {'label': label}),
        EselStep(
          kind: EselKind.merken,
          questionKey: 'esel.question.merken',
          questionParams: {'label': label},
          answer: result,
          regular: regular?.result,
        ),
      ],
    GivenForm(:final result) => [
        _erkennen(item, formKey),
        _absent(EselKind.stamm, {'word': headword(item)}),
        _absent(EselKind.endung, {'label': label}),
        _absent(EselKind.lautregel, {'label': label}),
        EselStep(
          kind: EselKind.merken,
          questionKey: 'esel.question.given',
          questionParams: {'label': label, 'result': result},
          answer: result,
        ),
      ],
  };
}

/// The form the dictionary itself writes: no ending on the stem, a result the
/// principal parts name, and the first key of the word that writes it — a
/// later cell of the same spelling (vocative, neuter accusative) is a form the
/// learner still builds.
bool _isDictionaryForm(PracticeItem item, FormKey formKey, GeneratedForm form) {
  if (form.ending.isNotEmpty) return false;
  final dictionary = {
    for (final part in item.principalParts) norm(part.$2),
    norm(item.lemma),
  };
  if (!dictionary.contains(norm(form.result))) return false;
  return item.formOrder.firstWhere((key) =>
          norm(item.derivation.forms[key]!.result) == norm(form.result)) ==
      formKey;
}

EselStep _absent(EselKind kind, Map<String, String> params) => EselStep(
      kind: kind,
      questionKey: 'esel.question.${kind.name}',
      questionParams: params,
      answerKey: 'esel.absent.${kind.name}',
      absent: true,
    );

SandhiRule? _seamRule(ComposedForm form) => form.parts
    .whereType<AffixPart>()
    .map((part) => part.sandhiRule)
    .nonNulls
    .firstOrNull;

// ---------------------------------------------------------------- Erkennen

EselStep _erkennen(PracticeItem item, FormKey formKey) {
  final String right = item.derivation.type;
  final String wordClass = eselWordClasses[right] ??
      (throw StateError('no word class for type $right'));
  final recognition = item.derivation.recognition;
  final sameEnding = recognition is TypeByRule
      ? recognition.candidateTypes
      : const <String>[];
  final others = [
    for (final type in sameEnding)
      if (eselWordClasses[type] == wordClass) type,
    for (final entry in eselWordClasses.entries)
      if (entry.value == wordClass) entry.key,
  ];

  return EselStep(
    kind: EselKind.erkennen,
    questionKey: 'esel.question.erkennen',
    questionParams: {'word': headword(item)},
    answer: right,
    options: _options(
      item: item,
      formKey: formKey,
      kind: EselKind.erkennen,
      right: right,
      candidates: others,
    ),
  );
}

// ------------------------------------------------------------------- Stamm

EselStep _stamm(
  PracticeItem item,
  FormKey formKey,
  GeneratedForm form,
  Diagnosis? diagnosis,
) {
  final stem = item.derivation.stems[form.stemName]!;
  final String source = stem is StemFromPart
      ? stem.sourceWord
      : item.principalParts.first.$2;
  // One letter later than the stem, and still short of the whole word: the
  // dictionary form is not a stem and is never an option.
  final bool cuts = norm(source).startsWith(norm(stem.stem)) &&
      source.length > stem.stem.length + 1;
  final dictionary = {
    '${item.lemma}-',
    '$source-',
    for (final part in item.principalParts) '${part.$2}-',
  };
  // The stem the learner used is what the step holds against the right one,
  // even where that is the dictionary form.
  if (diagnosis is WrongStem) {
    dictionary.removeWhere((word) => norm(word) == norm('${diagnosis.usedStem}-'));
  }

  return EselStep(
    kind: EselKind.stamm,
    questionKey: 'esel.question.stamm',
    questionParams: {'word': headword(item)},
    answer: '${stem.stem}-',
    options: _options(
      item: item,
      formKey: formKey,
      kind: EselKind.stamm,
      right: '${stem.stem}-',
      candidates: [
        if (diagnosis is WrongStem) '${diagnosis.usedStem}-',
        if (cuts) '${source.substring(0, stem.stem.length + 1)}-',
        for (final other in item.derivation.stems.values) '${other.stem}-',
        // A stem cut too short is the mistake left when the word gives no
        // longer spelling and has no second stem.
        if (stem.stem.length > 1)
          '${stem.stem.substring(0, stem.stem.length - 1)}-',
      ],
      forbidden: dictionary,
    ),
  );
}

// ------------------------------------------------------------------ Endung

EselStep _endung(
  PracticeItem item,
  FormKey formKey,
  GeneratedForm form,
  String label,
  Diagnosis? diagnosis,
) {
  final templates = item.derivation.grammar.templatesByType;
  final String right = '-${form.ending}';
  final bool borrowed =
      borrowedEndings[item.type]?.contains(form.endingType) ?? false;
  // "-" alone is no text: a form built without an ending says so in words,
  // and an empty ending borrowed from another type names no type either.
  final String? emptyEnding = form.ending.isEmpty ? 'esel.noEnding' : null;

  String endingOf(FormKey key) {
    final other = item.derivation.forms[key];
    return other is GeneratedForm ? '-${other.ending}' : '';
  }

  final int index = item.formOrder.indexOf(formKey);
  final stem = item.derivation.stems[form.stemName]!;

  /// An ending that builds an accepted spelling of the asked key is the right
  /// answer in another spelling, not a distractor.
  bool correct(String ending) => stem.variants
      .any((spelling) => item.accepts(index, spelling + ending.substring(1)));

  return EselStep(
    kind: EselKind.endung,
    questionKey: 'esel.question.endung',
    questionParams: {'label': label},
    answer: emptyEnding != null
        ? ''
        : borrowed
            ? '$right (${endingTypePhrase(form.endingType)})'
            : right,
    answerKey: emptyEnding,
    options: _options(
      item: item,
      formKey: formKey,
      kind: EselKind.endung,
      right: right,
      rightKey: emptyEnding,
      forbidden: _acceptedEndings(item, formKey, form),
      candidates: [
        if (diagnosis is OtherFormOfWord)
          for (final key in diagnosis.formKeys) endingOf(key),
        if (diagnosis is EndingOfOtherType)
          for (final type in diagnosis.types)
            '-${templates[type]?[formKey]?.endings.first ?? ''}',
        for (final neighbour in templates[form.endingType]!.entries)
          if (neighbour.key != formKey) '-${neighbour.value.endings.first}',
        for (final other in templates.entries)
          if (other.key != form.endingType && other.value[formKey] != null)
            '-${other.value[formKey]!.endings.first}',
        // The word's own paradigm, for a key whose ending table is as short
        // as the adverb pair.
        for (final key in item.formOrder)
          if (key != formKey) endingOf(key),
      ].where((ending) => ending.length > 1 && !correct(ending)).toList(),
    ),
  );
}

/// Every ending that builds an accepted spelling of [formKey]: the shown one,
/// its S9 variants, and whatever the own type writes for the key.
Set<String> _acceptedEndings(
  PracticeItem item,
  FormKey formKey,
  GeneratedForm form,
) {
  final stems = item.derivation.stems.values
      .expand((stem) => stem.variants)
      .map(norm)
      .toList();
  return {
    form.ending,
    ...?item.derivation.grammar.templatesByType[form.endingType]?[formKey]
        ?.endings,
    for (final variant in form.variants)
      for (final stem in stems)
        if (norm(variant).startsWith(stem))
          norm(variant).substring(stem.length),
  }.map((ending) => '-$ending').toSet();
}

// --------------------------------------------------------------- Lautregel

EselStep _lautregel(
  PracticeItem item,
  FormKey formKey,
  SandhiRule? rule,
  String label,
) =>
    EselStep(
      kind: EselKind.lautregel,
      questionKey: 'esel.question.lautregel',
      questionParams: {'label': label},
      answer: rule?.explain ?? '',
      answerKey: rule == null ? 'esel.noRule' : null,
      options: (rule == null
          ? [
              const EselOption.phrase('esel.noRule', isRight: true),
              const EselOption.phrase('esel.soundChanges', isRight: false),
            ]
          : [
              EselOption(rule.explain, isRight: true),
              const EselOption.phrase('esel.noRule', isRight: false),
            ])
        ..shuffle(_seeded(item.id, formKey, EselKind.lautregel)),
    );

// --------------------------------------------------------------- Verbinden

EselStep _verbinden(
  PracticeItem item,
  FormKey formKey,
  ComposedForm form,
  String label,
) {
  final String right = _parts(item, form);
  return EselStep(
    kind: EselKind.verbinden,
    questionKey: 'esel.question.verbinden',
    questionParams: {'label': label},
    answer: right,
    options: _options(
      item: item,
      formKey: formKey,
      kind: EselKind.verbinden,
      right: right,
      candidates: _otherAuxiliaryForm(item, formKey, form),
    ),
  );
}

String _parts(PracticeItem item, ComposedForm form) => form.parts
    .map((part) => part is AffixPart
        ? item.derivation.stems[part.stemName]!.stem
        : part.text)
    .join(' + ');

/// The same composition with the auxiliary of another tense or mood: the
/// item's own keys that differ from [formKey] in the fewest features and
/// keep every part but the last.
List<String> _otherAuxiliaryForm(
  PracticeItem item,
  FormKey formKey,
  ComposedForm form,
) {
  final asked = item.formLabels[item.formOrder.indexOf(formKey)].features;
  final heads = form.parts
      .take(form.parts.length - 1)
      .map((part) => part.text)
      .toList();

  final sameHead = <(int distance, String text)>[];
  final ownHead = <(int distance, String text)>[];
  for (var i = 0; i < item.formOrder.length; i++) {
    final other = item.derivation.forms[item.formOrder[i]];
    if (other is! ComposedForm || other.parts.length != form.parts.length) {
      continue;
    }
    if (other.parts.last.text == form.parts.last.text) continue;
    final features = item.formLabels[i].features;
    final int distance = features.entries
        .where((entry) => asked[entry.key] != entry.value)
        .length;
    final otherHeads =
        other.parts.take(other.parts.length - 1).map((part) => part.text);
    if (_sameList(heads, otherHeads.toList())) {
      sameHead.add((distance, _parts(item, other)));
    } else {
      // The word's own parts with that auxiliary: a form the learner could
      // write, where no key of the word pairs the two.
      ownHead.add((
        distance,
        [..._heads(item, form), other.parts.last.text].join(' + '),
      ));
    }
  }
  for (final list in [sameHead, ownHead]) {
    list.sort((a, b) => a.$1.compareTo(b.$1));
  }
  return [for (final candidate in [...sameHead, ...ownHead]) candidate.$2];
}

List<String> _heads(PracticeItem item, ComposedForm form) => [
      for (final part in form.parts.take(form.parts.length - 1))
        part is AffixPart
            ? item.derivation.stems[part.stemName]!.stem
            : part.text,
    ];

bool _sameList(List<String> a, List<String> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);

// ----------------------------------------------------------------- options

/// The right option plus up to two distractors from [candidates], in a stable
/// shuffled order. A candidate that reads as the right answer — the same text,
/// the same text without quantity marks, or another accepted spelling named in
/// [forbidden] — is no distractor.
List<EselOption> _options({
  required PracticeItem item,
  required FormKey formKey,
  required EselKind kind,
  required String right,
  required List<String> candidates,
  String? rightKey,
  Set<String> forbidden = const {},
}) {
  final taken = {norm(right), ...forbidden.map(norm)};
  final distractors = <String>[];
  for (final candidate in candidates) {
    if (candidate.isEmpty || candidate == '-') continue;
    if (!taken.add(norm(candidate))) continue;
    distractors.add(candidate);
    if (distractors.length == 2) break;
  }
  if (distractors.isEmpty) {
    throw StateError(
      'no distractor for ${kind.name} of "$formKey" of "${item.id}"',
    );
  }

  final options = [
    if (rightKey != null)
      EselOption.phrase(rightKey, isRight: true)
    else
      EselOption(right, isRight: true),
    for (final distractor in distractors) EselOption(distractor, isRight: false),
  ];
  return options..shuffle(_seeded(item.id, formKey, kind));
}

/// FNV-1a over item, form key and step, so the order of a step is the same in
/// every run and differs between steps.
Random _seeded(String id, FormKey formKey, EselKind kind) {
  var hash = 2166136261;
  for (final unit in '$id|$formKey|${kind.name}'.codeUnits) {
    hash = ((hash ^ unit) * 16777619) & 0xffffffff;
  }
  return Random(hash);
}
