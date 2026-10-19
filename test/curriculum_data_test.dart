import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/lesson_range.dart';

/// The real progression, pinned against the real practice data: one point per
/// lesson that introduces a form or a type, and the laws the whole table obeys.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Curriculum curriculum;
  late Map<String, FormMetadata> metadata;

  setUpAll(() async {
    curriculum = await loadCurriculum(curriculumAssets);
    metadata = {
      for (final path in [
        'lib/data/latin_nouns.yaml',
        'lib/data/latin_verbs.yaml',
      ])
        (await getFormMetadata(path)).dataFileId: await getFormMetadata(path),
    };
  });

  test('every lesson that introduces a form or a type is pinned to one', () {
    for (final pin in firstTaught) {
      final actual = pin.isType
          ? curriculum.typeLesson(pin.dataFileId, pin.name)
          : curriculum.formLesson(pin.dataFileId, pin.name);
      expect(actual, pin.lesson, reason: '${pin.topic}: ${pin.name}');
    }
  });

  test('the lessons without a pin introduce no form and no type', () {
    final pinned = {for (final pin in firstTaught) pin.lesson};
    final taught = <int>{};
    for (final entry in metadata.entries) {
      for (final key in entry.value.formOrder) {
        taught.add(curriculum.formLesson(entry.key, key));
      }
      for (final type in entry.value.availableTypes) {
        taught.add(curriculum.typeLesson(entry.key, type));
      }
    }
    expect(taught.difference({laterLesson}), pinned);
    expect([
      for (var l = 1; l <= lastLesson; l++)
        if (!pinned.contains(l)) l,
    ], syntaxOnlyLessons);
  });

  test('every form is taught in 1..lastLesson or waits beyond the course', () {
    for (final entry in metadata.entries) {
      for (final key in entry.value.formOrder) {
        final lesson = curriculum.formLesson(entry.key, key);
        expect(lesson, inInclusiveRange(1, laterLesson), reason: key);
        expect(
          lesson == laterLesson,
          isLater(key),
          reason: '${entry.key} $key is $lesson',
        );
      }
    }
  });

  test('a verb form family is taught in one lesson', () {
    final byFamily = <String, Set<int>>{};
    for (final key in metadata['verbs']!.formOrder) {
      final parts = key.split('.');
      final family = parts
          .take(key.startsWith('ger') || key.startsWith('sup') ? 1 : 3)
          .join('.');
      byFamily
          .putIfAbsent(family, () => {})
          .add(curriculum.formLesson('verbs', key));
    }
    for (final family in byFamily.entries) {
      expect(
        family.value,
        family.key == 'ind.praes.akt' ? {1, 2, 4} : hasLength(1),
        reason: family.key,
      );
    }
  });

  test('a noun case is taught in one lesson', () {
    final byCase = <String, Set<int>>{};
    for (final key in metadata['nouns']!.formOrder) {
      if (key.startsWith('adv')) continue;
      final lesson = curriculum.formLesson('nouns', key);
      if (lesson == laterLesson) continue;
      byCase.putIfAbsent(key.split('.').first, () => {}).add(lesson);
    }
    for (final kasus in byCase.entries) {
      expect(
        kasus.value,
        kasus.key == 'nom' ? {1, 2} : hasLength(1),
        reason: kasus.key,
      );
    }
  });

  test('a tense is never taught before the tense the book teaches first', () {
    for (final order in tenseOrders) {
      final lessons = [
        for (final family in order) curriculum.formLesson('verbs', family),
      ];
      expect(
        lessons,
        orderedEquals([...lessons]..sort()),
        reason: order.join(' < '),
      );
    }
  });

  test('what no lesson teaches sits one stop beyond the last lesson', () {
    expect(curriculum.formLesson('verbs', 'ger.gen'), laterLesson);
    expect(curriculum.formLesson('nouns', 'nom.sg.m.komp'), laterLesson);
    expect(
      curriculum.taughtForm('verbs', 'ger.gen', LessonRange(1, lastLesson)),
      isFalse,
    );
    expect(
      curriculum.taughtForm('verbs', 'ger.gen', LessonRange.fullGrammar),
      isTrue,
    );
  });
}

typedef Pin = ({
  int lesson,
  String dataFileId,
  String name,
  bool isType,
  String topic,
});

Pin form(int lesson, String dataFileId, String name, String topic) => (
  lesson: lesson,
  dataFileId: dataFileId,
  name: name,
  isType: false,
  topic: topic,
);

Pin type(int lesson, String dataFileId, String name, String topic) => (
  lesson: lesson,
  dataFileId: dataFileId,
  name: name,
  isType: true,
  topic: topic,
);

/// One point per lesson that introduces something, with the topic in our
/// words. Only lessons that teach syntax or words alone are missing; they are
/// listed in [syntaxOnlyLessons].
final firstTaught = <Pin>[
  form(1, 'nouns', 'nom.sg', 'Nominativ Singular'),
  form(2, 'nouns', 'nom.pl', 'Nominativ Plural'),
  form(3, 'nouns', 'akk.sg', 'Akkusativ'),
  form(4, 'nouns', 'dat.sg', 'Dativ'),
  form(5, 'nouns', 'vok.sg', 'Vokativ'),
  form(6, 'nouns', 'gen.sg', 'Genitiv'),
  type(7, 'nouns', 'Adjektiv-a-o', 'Adjektive der a-/o-Deklination'),
  form(8, 'nouns', 'abl.sg', 'Ablativ'),
  type(9, 'nouns', 'Adjektiv-a-o-er', 'Adjektive auf -(e)r'),
  form(10, 'verbs', 'ind.impf.akt.3.sg', 'Imperfekt Aktiv'),
  type(11, 'verbs', 'Konsonantische', 'konsonantische Konjugation'),
  type(
    12,
    'nouns',
    'Konsonantische-Deklination-mf',
    'dritte Deklination, Konsonantenstämme',
  ),
  form(13, 'verbs', 'ind.perf.akt.3.sg', 'Perfekt Aktiv'),
  form(14, 'verbs', 'inf.perf.akt', 'Infinitiv Perfekt Aktiv'),
  form(15, 'verbs', 'ind.plusq.akt.3.sg', 'Plusquamperfekt Aktiv'),
  type(16, 'nouns', 'Pronomen-qui', 'Relativpronomen'),
  form(17, 'verbs', 'ind.fut.akt.3.sg', 'Futur I Aktiv'),
  type(18, 'nouns', 'Adjektiv-zweiendig', 'Adjektive der dritten Deklination'),
  form(20, 'verbs', 'ind.fut2.akt.3.sg', 'Futur II Aktiv'),
  form(22, 'verbs', 'ind.perf.pass.3.sg', 'Perfekt Passiv'),
  type(23, 'nouns', 'E-Deklination', 'e-Deklination'),
  form(24, 'verbs', 'inf.perf.pass', 'Infinitiv Perfekt Passiv'),
  form(26, 'verbs', 'part.praes.akt.sg.nom.m', 'Partizip Präsens Aktiv'),
  form(27, 'verbs', 'ind.praes.pass.3.sg', 'Präsens Passiv'),
  form(28, 'verbs', 'ind.impf.pass.3.sg', 'Imperfekt Passiv'),
  form(29, 'verbs', 'konj.impf.akt.3.sg', 'Konjunktiv Imperfekt Aktiv'),
  form(30, 'verbs', 'konj.plusq.akt.3.sg', 'Konjunktiv Plusquamperfekt Aktiv'),
  type(32, 'nouns', 'U-Deklination', 'u-Deklination'),
  form(33, 'verbs', 'konj.praes.akt.3.sg', 'Konjunktiv Präsens Aktiv'),
  form(34, 'verbs', 'konj.perf.akt.3.sg', 'Konjunktiv Perfekt Aktiv'),
  type(35, 'nouns', 'Pronomen-ipse', 'Pronomen ipse'),
  type(36, 'nouns', 'Numerale-milia', 'Zahlwort mīlia'),
  type(37, 'nouns', 'Pronomen-idem', 'Pronomen īdem'),
  form(38, 'verbs', 'konj.perf.pass.3.sg', 'Konjunktiv Perfekt Passiv'),
  type(
    39,
    'nouns',
    'Adjektiv-einendig-Konsonantstamm',
    'einendige Adjektive der Konsonantenstämme',
  ),
];

/// Lessons whose grammar is syntax or vocabulary only: they add no form and
/// no type to the practice data.
const syntaxOnlyLessons = [19, 21, 25, 31, 40];

/// Whether the course never reaches [key]: a comparison degree, or one of
/// the verb families in [laterFamilies].
bool isLater(String key) =>
    key.endsWith('.komp') ||
    key.endsWith('.sup') ||
    laterFamilies.any(key.startsWith);

/// Form key prefixes the course never reaches.
const laterFamilies = [
  'inf.fut.',
  'imp.fut.',
  'imp.praes.pass.',
  'part.fut.',
  'part.perf.akt.',
  'ger.',
  'gerv.',
  'sup.',
];

/// Tense families in the order the book introduces them, within one mood and
/// one voice.
const tenseOrders = [
  [
    'ind.praes.akt.3.sg',
    'ind.impf.akt.3.sg',
    'ind.perf.akt.3.sg',
    'ind.plusq.akt.3.sg',
    'ind.fut.akt.3.sg',
    'ind.fut2.akt.3.sg',
  ],
  [
    'ind.perf.pass.3.sg',
    'ind.plusq.pass.3.sg',
    'ind.fut2.pass.3.sg',
    'ind.praes.pass.3.sg',
    'ind.impf.pass.3.sg',
    'ind.fut.pass.3.sg',
  ],
  [
    'konj.impf.akt.3.sg',
    'konj.plusq.akt.3.sg',
    'konj.praes.akt.3.sg',
    'konj.perf.akt.3.sg',
  ],
  [
    'konj.praes.pass.3.sg',
    'konj.impf.pass.3.sg',
    'konj.perf.pass.3.sg',
    'konj.plusq.pass.3.sg',
  ],
];
