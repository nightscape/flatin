import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';

const _iStem = 'Adjektiv-einendig-i';
const _consonantStem = 'Adjektiv-einendig-Konsonantstamm';

const _iStemIds = ['felix', 'infelix', 'ingens', 'prudens', 'clemens'];
const _consonantStemIds = ['vetus', 'dives', 'pauper'];

const _neuterPluralKeys = ['nom.pl.n.pos', 'akk.pl.n.pos', 'vok.pl.n.pos'];

/// Item id -> {form key -> the form the learner types}.
const _expected = {
  'felix': {
    'nom.sg.m.pos': 'fēlīx',
    'nom.sg.n.pos': 'fēlīx',
    'akk.sg.m.pos': 'fēlīcem',
    'akk.sg.f.pos': 'fēlīcem',
    'akk.sg.n.pos': 'fēlīx',
    'abl.sg.m.pos': 'fēlīcī',
    'gen.pl.m.pos': 'fēlīcium',
    'nom.pl.n.pos': 'fēlīcia',
    'nom.sg.m.komp': 'fēlīcior',
    'nom.sg.m.sup': 'fēlīcissimus',
    'adv.pos': 'fēlīciter',
  },
  'ingens': {
    'akk.sg.m.pos': 'ingentem',
    'abl.sg.m.pos': 'ingentī',
    'gen.pl.m.pos': 'ingentium',
    'nom.pl.n.pos': 'ingentia',
    'nom.sg.m.komp': 'ingentior',
    'nom.sg.m.sup': 'ingentissimus',
    'adv.pos': 'ingenter',
  },
  'prudens': {
    'abl.sg.m.pos': 'prūdentī',
    'gen.pl.m.pos': 'prūdentium',
    'nom.pl.n.pos': 'prūdentia',
    'nom.sg.m.komp': 'prūdentior',
    'adv.pos': 'prūdenter',
  },
  'vetus': {
    'nom.sg.m.pos': 'vetus',
    'nom.sg.n.pos': 'vetus',
    'akk.sg.m.pos': 'veterem',
    'akk.sg.f.pos': 'veterem',
    'akk.sg.n.pos': 'vetus',
    'abl.sg.m.pos': 'vetere',
    'gen.pl.m.pos': 'veterum',
    'nom.pl.n.pos': 'vetera',
  },
  'dives': {
    'akk.sg.m.pos': 'dīvitem',
    'abl.sg.m.pos': 'dīvite',
    'gen.pl.m.pos': 'dīvitum',
  },
  'pauper': {
    'akk.sg.m.pos': 'pauperem',
    'abl.sg.m.pos': 'paupere',
    'gen.pl.m.pos': 'pauperum',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, PracticeItem> byId;
  late List<PracticeItem> all;

  setUpAll(() async {
    all = await loadAllPracticeItems();
    byId = {for (final i in all) i.id.split(':').last: i};
  });

  String form(PracticeItem item, String key) =>
      item.forms[item.formOrder.indexOf(key)];

  test('the one-ending adjectives give the forms of their pattern', () {
    for (final entry in _expected.entries) {
      final item = byId[entry.key]!;
      for (final form_ in entry.value.entries) {
        expect(
          item.formOrder,
          contains(form_.key),
          reason: '${entry.key} ${form_.key}',
        );
        expect(
          form(item, form_.key),
          form_.value,
          reason: '${entry.key} ${form_.key}',
        );
      }
    }
  });

  test('the two patterns have their own type', () {
    for (final id in _iStemIds) {
      expect(byId[id]!.type, _iStem, reason: id);
    }
    for (final id in _consonantStemIds) {
      expect(byId[id]!.type, _consonantStem, reason: id);
    }
  });

  test('the i-stem items carry the nominative of every gender', () {
    for (final id in _iStemIds) {
      final item = byId[id]!;
      for (final key in [
        'nom.sg.f.pos',
        'nom.sg.n.pos',
        'vok.sg.m.pos',
        'vok.sg.n.pos',
      ]) {
        expect(form(item, key), item.lemma, reason: '$id $key');
      }
    }
  });

  test('the consonant-stem items have no comparison and no adverb', () {
    for (final id in _consonantStemIds) {
      final item = byId[id]!;
      final graded = item.formOrder.where(
        (k) => k.endsWith('.komp') || k.endsWith('.sup') || k.startsWith('adv'),
      );
      expect(graded, isEmpty, reason: id);
    }
  });

  test('dives and pauper lack exactly the neuter plural', () {
    final vetus = byId['vetus']!.formOrder.toSet();
    for (final id in ['dives', 'pauper']) {
      final keys = byId[id]!.formOrder.toSet();
      expect(vetus.difference(keys), _neuterPluralKeys.toSet(), reason: id);
      expect(keys.difference(vetus), isEmpty, reason: id);
    }
  });

  test('the i-stem items keep their comparison', () {
    for (final id in _iStemIds) {
      final keys = byId[id]!.formOrder;
      expect(keys, contains('nom.sg.m.komp'), reason: id);
      expect(keys, contains('nom.sg.m.sup'), reason: id);
      expect(keys, contains('adv.pos'), reason: id);
    }
  });

  test(
    'no comparative, superlative or graded adverb is built for vetus, dives, pauper',
    () {
      const stems = {'vetus': 'veter', 'dives': 'dīvit', 'pauper': 'pauper'};
      for (final entry in stems.entries) {
        final item = byId[entry.key]!;
        final graded = RegExp('^${entry.value}(ior|iōr|issim|rim|ius)');
        expect(item.forms.where(graded.hasMatch), isEmpty, reason: entry.key);
      }
    },
  );

  test('each pattern is taught in its lesson', () async {
    final curriculum = await loadCurriculum(bookAssets);
    expect(curriculum.taughtType('nouns', _iStem, LessonRange(1, 17)), isFalse);
    expect(curriculum.taughtType('nouns', _iStem, LessonRange(1, 18)), isTrue);
    expect(
      curriculum.taughtType('nouns', _consonantStem, LessonRange(1, 38)),
      isFalse,
    );
    expect(
      curriculum.taughtType('nouns', _consonantStem, LessonRange(1, 39)),
      isTrue,
    );
  });

  test('every item that existed before keeps its id', () {
    final before = File(
      'test/fixtures/item_ids_before_one_ending.txt',
    ).readAsLinesSync();
    expect(before, hasLength(666));
    expect(all.map((i) => i.id).toSet(), containsAll(before));
  });
}
