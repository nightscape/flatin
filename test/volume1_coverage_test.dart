import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';

/// Lesson words whose forms belong to the item of another lemma.
const _formOf = {
  'est': 'esse',
  'sunt': 'esse',
  'quid?': 'quis',
  'est/sunt': 'esse',
  'mē': 'ego',
  'tibi': 'tū',
  'tē': 'tū',
  'valē!/valēte!': 'valēre',
  'mihi': 'ego',
  'appāret': 'appārēre',
};

/// Lesson words without an item, with the reason.
const _skipped = {
  'liber':
      'needs a noun type O-Deklination-er; the id nouns:liber is taken by the adjective',
  'iam': 'uninflected word',
  'diū': 'uninflected word',
  'ubi?': 'uninflected word',
  'cūr?': 'uninflected word',
  'nōn': 'uninflected word',
  'tandem': 'uninflected word',
  'et': 'uninflected word',
  'salvē!\u00a0salvēte': 'greeting, imperative of a defective verb',
  'nam': 'uninflected word',
  'etiam': 'uninflected word',
  'saepe': 'uninflected word',
  'ecce!': 'uninflected word',
  'ibi': 'uninflected word',
  'statim': 'uninflected word',
  'tum': 'uninflected word',
  'certē': 'uninflected word',
  'sed': 'uninflected word',
  'subitō': 'uninflected word',
  'cōnsilium habēre': 'phrase or collocation',
  'quattuor': 'indeclinable numeral',
  'squirus': 'no printed entry in the word list',
  'valdē': 'uninflected word',
  'decem': 'indeclinable numeral',
  'sex': 'indeclinable numeral',
  'autem': 'uninflected word',
  'nōn iam': 'phrase or collocation',
  'itaque': 'uninflected word',
  'ut': 'uninflected word',
  'nunc': 'uninflected word',
  'amīcum cūrāre': 'phrase or collocation',
  'imprīmīs': 'uninflected word',
  'dōnum dare': 'phrase or collocation',
  'hūc': 'uninflected word',
  '-que': 'clitic particle',
  'perīculum prohibēre': 'phrase or collocation',
  'negōtium dare': 'phrase or collocation',
  'paulō post': 'phrase or collocation',
  'ergō': 'uninflected word',
  'plūrimī':
      'Pluraletantum: nouns and adjectives have no plural-only mechanism',
  'nōnnūllī':
      'Pluraletantum: nouns and adjectives have no plural-only mechanism',
  'quia': 'uninflected word',
  'semper': 'uninflected word',
  'paucī': 'Pluraletantum: nouns and adjectives have no plural-only mechanism',
  'nihil': 'defective and indeclinable: no type',
  'licet': 'impersonal verb with no personal paradigm',
  'at': 'uninflected word',
  'sē': 'reflexive pronoun without nominative: no Pronomen type',
  'somnō sē dare': 'phrase or collocation',
  'īnsidiae':
      'Pluraletantum: nouns and adjectives have no plural-only mechanism',
  'īnsidiās parāre': 'phrase or collocation',
  'profectō': 'uninflected word',
  'puer': 'needs a noun type O-Deklination-er (nominative without ending)',
  'multī': 'Pluraletantum: nouns and adjectives have no plural-only mechanism',
  'magister': 'needs a noun type O-Deklination-er (nominative without ending)',
  'vir': 'needs a noun type O-Deklination-er (nominative without ending)',
  'in': 'uninflected word',
  'ē, ex': 'uninflected word',
  'cum': 'uninflected word',
  'ante': 'uninflected word',
  'frūstrā': 'uninflected word',
  'ā, ab': 'uninflected word',
  '(ā) cūrīs līber': 'phrase or collocation',
  'ad': 'uninflected word',
  'per': 'uninflected word',
  'numquam': 'uninflected word',
  'prīmum': 'uninflected word',
  'dē': 'uninflected word',
  'dē imperiō contendere': 'phrase or collocation',
  'in animō habēre': 'phrase or collocation',
  'dē imperiō cōnsulere': 'phrase or collocation',
  'auxilium ā deīs petere': 'phrase or collocation',
  'quīnque': 'indeclinable numeral',
  'septem': 'indeclinable numeral',
  'duodecim': 'indeclinable numeral',
  'grātiās agere': 'phrase or collocation',
  'cōnsilium capere': 'phrase or collocation',
  'pācem facere': 'phrase or collocation',
  'iterum': 'uninflected word',
  'vix': 'uninflected word',
  'quod': 'uninflected word',
  'māgnā vōce': 'phrase or collocation',
  'ōrātiōnem habēre': 'phrase or collocation',
  'quamquam': 'uninflected word',
  'tamen': 'uninflected word',
  'adhūc': 'uninflected word',
  'nēmō': 'defective noun-pronoun: no type',
  'dum': 'uninflected word',
  'domī': 'case form of domus, which has no item',
  'ager': 'needs a noun type O-Deklination-er (nominative without ending)',
  'tam': 'uninflected word',
  'postquam': 'uninflected word',
  'prō': 'uninflected word',
  'nōn īgnōrāre': 'phrase or collocation',
  'bellum gerere': 'phrase or collocation',
  'necesse est': 'phrase or collocation',
  'animum amīcī flectere': 'phrase or collocation',
  'prīmā lūce': 'phrase or collocation',
  'apud': 'uninflected word',
  'multum': 'uninflected word',
  'multum valēre': 'phrase or collocation',
  'castra': 'Pluraletantum: nouns and adjectives have no plural-only mechanism',
  'nōndum': 'uninflected word',
  'īrā ārdēre': 'phrase or collocation',
  'honōribus afficere': 'phrase or collocation',
  'castra pōnere': 'phrase or collocation',
  'castra movēre': 'phrase or collocation',
  'quondam': 'uninflected word',
  'contrā': 'uninflected word',
  'vītam agere': 'phrase or collocation',
  'procul': 'uninflected word',
  'vīs': 'irregular noun vīs: no type',
  'vīrēs': 'Pluraletantum: nouns and adjectives have no plural-only mechanism',
  'litterīs sē dare': 'phrase or collocation',
  'prope': 'uninflected word',
  'alius': 'pronominal adjective alius, alia, aliud: no Pronomen type',
  'nāvem solvere': 'phrase or collocation',
  'ē somnō excitāre': 'phrase or collocation',
  'extrā': 'uninflected word',
  'nūper': 'uninflected word',
  'mox': 'uninflected word',
  'tūtus ā perīculīs': 'phrase or collocation',
  'intereā': 'uninflected word',
  'ubīque': 'uninflected word',
  'sine': 'uninflected word',
  'sīc': 'uninflected word',
  'domō': 'case form of domus, which has no item',
  'domum': 'case form of domus, which has no item',
  'labōrēs subīre': 'phrase or collocation',
  'fēlīx': 'needs an einendig adjective type (genitive-stem adjective)',
  'sub': 'uninflected word',
  '(deī) immortālēs': 'phrase or collocation',
  'sī': 'uninflected word',
  '-ne': 'clitic particle',
  'ōtiō sē dare': 'phrase or collocation',
};

String _head(String word) => normalizeDiacritics(
  word.split(RegExp(r'[,(]')).first.trim(),
).replaceAll(RegExp(r'[?!]'), '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every inflectable word of volume 1 has an item or a listed reason',
    () async {
      final lessons = await loadLessonData([lessonDataAssets.first]);
      final items = await loadAllPracticeItems();
      final lemmas = {for (final i in items) normalizeDiacritics(i.lemma)};

      final words = {for (final ws in lessons.lessonWords.values) ...ws};
      final uncovered = {
        for (final w in words)
          if (!lemmas.contains(_head(w)) || _skipped.containsKey(w)) w,
      };

      expect(uncovered.difference(_formOf.keys.toSet()), _skipped.keys.toSet());
      for (final lemma in _formOf.values) {
        expect(lemmas, contains(normalizeDiacritics(lemma)), reason: lemma);
      }
    },
  );

  test(
    'index words sharing a normalized head each have their own item',
    () async {
      final lessons = await loadLessonData([lessonDataAssets.first]);
      final items = await loadAllPracticeItems();
      final words = {for (final ws in lessons.lessonWords.values) ...ws};

      final byHead = <String, Set<String>>{};
      for (final w in words.where((w) => !_skipped.containsKey(w))) {
        byHead.putIfAbsent(_head(w), () => {}).add(w);
      }
      for (final entry in byHead.entries.where((e) => e.value.length > 1)) {
        final matching = items.where(
          (i) => normalizeDiacritics(i.lemma) == entry.key,
        );
        expect(
          matching.length,
          greaterThanOrEqualTo(entry.value.length),
          reason: '${entry.value} share the head "${entry.key}"',
        );
      }
    },
  );

  test('a possessive vocative is the short form', () async {
    final items = await loadPracticeItems('lib/data/latin_nouns.yaml');
    final meus = items.singleWhere((i) => i.lemma == 'meus');
    final index = meus.formOrder.indexOf('vok.sg.m.pos');
    expect(meus.acceptedForms[index], ['mī']);
  });
}
