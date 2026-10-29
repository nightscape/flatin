import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/selection.dart' show grammarLesson;
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/practice_item.dart';

/// Every sentence of the corpus, run through the grammar engine and the
/// course: each token is a known form or a lesson headword, inside the
/// sentence's lesson, and the construction's words agree.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SentenceCorpus corpus;
  late Map<String, PracticeItem> itemByLemma;
  late LessonData lessons;
  late Curriculum curriculum;

  setUpAll(() async {
    corpus = await loadSentenceCorpus();
    itemByLemma = {
      for (final item in await loadAllPracticeItems()) item.lemma: item,
    };
    lessons = await loadLessonData(bookAssets);
    curriculum = await loadCurriculum(bookAssets);
  });

  test('every sentence is placed by the engine and its lesson', () {
    final checker = _Checker(corpus, itemByLemma, lessons, curriculum);
    for (final sentence in corpus.sentences) {
      checker.check(sentence);
    }
    expect(checker.problems, isEmpty, reason: checker.problems.join('\n'));
  });

  test('the noun data agrees with the genders checked by hand', () {
    expect(
      {
        for (final lemma in _checkedGenders.keys)
          lemma: itemByLemma[lemma]!.genus,
      },
      {
        for (final MapEntry(key: lemma, value: genus)
            in _checkedGenders.entries)
          lemma: [genus],
      },
    );
  });

  test('the corpus covers each topic of lessons 24-26', () {
    final count = <ConstructionKind, int>{};
    for (final s in corpus.sentences) {
      count.update(s.construction.kind, (n) => n + 1, ifAbsent: () => 1);
    }
    final questions =
        count[ConstructionKind.frageNe]! +
        count[ConstructionKind.frageNonne]! +
        count[ConstructionKind.frageNum]!;
    expect(questions, greaterThanOrEqualTo(8));
    for (final kind in [
      ConstructionKind.aciPassiv,
      ConstructionKind.pcPpa,
      ConstructionKind.pcPpp,
      ConstructionKind.doppelterAkkusativ,
    ]) {
      expect(count[kind], greaterThanOrEqualTo(8), reason: kind.name);
    }
  });
}

const _checkedGenders = {
  'canis': 'm',
  'cēna': 'f',
  'cīvis': 'm',
  'fīlia': 'f',
  'fīlius': 'm',
  'homō': 'm',
  'hostis': 'm',
  'lēx': 'f',
  'mīles': 'm',
  'mulier': 'f',
  'nāvis': 'f',
  'oppidum': 'n',
  'puella': 'f',
  'senātor': 'm',
  'servus': 'm',
  'templum': 'n',
  'urbs': 'f',
  'fēmina': 'f',
};

const _participleOf = {
  ConstructionKind.pcPpa: 'part.praes.akt.',
  ConstructionKind.pcPpp: 'part.perf.pass.',
  ConstructionKind.aciPassiv: 'part.perf.pass.',
};

const _particleOf = {
  ConstructionKind.frageNe: '-ne',
  ConstructionKind.frageNonne: 'nōnne',
  ConstructionKind.frageNum: 'num',
};

final class _Checker {
  final SentenceCorpus corpus;
  final Map<String, PracticeItem> itemByLemma;
  final LessonData lessons;
  final Curriculum curriculum;
  final problems = <String>[];

  _Checker(this.corpus, this.itemByLemma, this.lessons, this.curriculum);

  void check(Sentence s) {
    void fail(String problem) => problems.add('${s.id}: $problem');

    final joined = s.tokens
        .map((t) => t.isEnclitic ? t.text.substring(1) : ' ${t.text}')
        .join()
        .trim();
    final words = s.latin.replaceAll(RegExp(r'[.,?!;:]'), '');
    if (joined.toLowerCase() != words.toLowerCase()) {
      fail('tokens spell "$joined", the sentence "$words"');
    }

    final features = <int, Map<String, String>>{};
    for (var i = 0; i < s.tokens.length; i++) {
      switch (s.tokens[i]) {
        case FormToken(:final text, :final lemma, :final key):
          final item = itemByLemma[lemma];
          if (item == null) {
            fail('"$text": the engine has no item "$lemma"');
            continue;
          }
          final index = item.formOrder.indexOf(key);
          if (index < 0) {
            fail('"$text": $lemma has no form $key');
            continue;
          }
          final accepted = item.acceptedForms[index];
          if (!accepted.any((f) => f.toLowerCase() == text.toLowerCase())) {
            fail('"$text": $lemma $key is ${accepted.join("/")}');
          }
          final wordLesson = lessons.lessonNumberOf(item);
          if (wordLesson > s.lesson) {
            fail('"$text": $lemma is taught in lesson $wordLesson');
          }
          // A vocab item has no grammar: its word lesson decides alone.
          final formLesson = item.isVocab
              ? wordLesson
              : grammarLesson(curriculum, item, key);
          if (formLesson > s.lesson) {
            fail('"$text": $lemma $key is taught in lesson $formLesson');
          }
          features[i] = item.formLabels[index].features;
        case HeadwordToken(:final text, :final headword):
          final lesson = lessons.wordToLesson[headword];
          if (lesson == null) {
            fail('"$text": no lesson lists "$headword"');
          } else if (lesson > s.lesson) {
            fail('"$text": "$headword" is taught in lesson $lesson');
          }
          if (itemByLemma.containsKey(headword)) {
            fail('"$text": the engine has "$headword"; name its form');
          }
          final parts = headword.split(RegExp(r'[\s()/.]+'));
          if (!parts.contains(text.toLowerCase())) {
            fail('"$text" is no word of the headword "$headword"');
          }
      }
    }

    final c = s.construction;
    final head = s.tokens[c.head];
    final particle = _particleOf[c.kind];
    if (particle != null) {
      final word = switch (head) {
        FormToken(:final lemma) => lemma,
        HeadwordToken(:final headword) => headword,
      };
      if (word != particle) {
        fail('the head of ${c.kind.name} is "${head.text}", not $particle');
      }
      return;
    }
    final headFeatures = features[c.head];
    final refFeatures = features[c.reference!];
    if (headFeatures == null || refFeatures == null) {
      fail('head and reference word must be engine forms');
      return;
    }
    final reference = s.tokens[c.reference!] as FormToken;

    if (c.kind == ConstructionKind.doppelterAkkusativ) {
      if (headFeatures['kasus'] != 'akk' || refFeatures['kasus'] != 'akk') {
        fail('a double accusative needs two accusatives');
      }
      return;
    }

    final participle = _participleOf[c.kind]!;
    if (!(head as FormToken).key.startsWith(participle)) {
      fail('the head "${head.text}" is no $participle* form');
    }
    final refGenus = switch (refFeatures['genus']) {
      final genus? => [genus],
      null => itemByLemma[reference.lemma]!.genus,
    };
    for (final (axis, values) in [
      ('kasus', [refFeatures['kasus']]),
      ('numerus', [refFeatures['numerus']]),
      ('genus', refGenus),
    ]) {
      if (!values.contains(headFeatures[axis])) {
        fail(
          '"${head.text}" ($axis ${headFeatures[axis]}) does not agree '
          'with "${reference.text}" ($axis ${values.join("/")})',
        );
      }
    }

    if (c.kind == ConstructionKind.aciPassiv) {
      if (refFeatures['kasus'] != 'akk') {
        fail('the subject of an AcI "${reference.text}" is no accusative');
      }
      final next = c.head + 1 < s.tokens.length ? s.tokens[c.head + 1] : null;
      if (next is! FormToken ||
          next.lemma != 'esse' ||
          next.key != 'inf.praes.akt') {
        fail('"${head.text}" is not followed by esse');
      }
      final infLesson = curriculum.formLesson('verbs', 'inf.perf.pass');
      if (infLesson > s.lesson) {
        fail('inf.perf.pass is taught in lesson $infLesson');
      }
    }
  }
}
