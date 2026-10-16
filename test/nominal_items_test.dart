import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';

/// The item ids of the nouns file before the volume-2 nominals were added.
/// Adding vocabulary must not rename an item: the id is the card identity, so
/// a changed id throws away the review history of that card.
const _idsOfVolumeOne = [
  'nouns:adversarius', 'nouns:aedificium', 'nouns:amicus',
  'nouns:amphitheatrum', 'nouns:animal', 'nouns:ara', 'nouns:arena',
  'nouns:basilica', 'nouns:bestia', 'nouns:capitolium', 'nouns:cibus',
  'nouns:consilium', 'nouns:corpus', 'nouns:curia', 'nouns:dea', 'nouns:deus',
  'nouns:dies', 'nouns:domina', 'nouns:dominus', 'nouns:donum', 'nouns:duo',
  'nouns:ego', 'nouns:equus', 'nouns:familia', 'nouns:femina', 'nouns:filia',
  'nouns:filius', 'nouns:forum', 'nouns:frumentum', 'nouns:hic',
  'nouns:hortus', 'nouns:hostia', 'nouns:idem', 'nouns:ille',
  'nouns:incendium', 'nouns:ipse', 'nouns:is', 'nouns:iste', 'nouns:ludus',
  'nouns:manus', 'nouns:mare', 'nouns:milia', 'nouns:monstrum',
  'nouns:monumentum', 'nouns:negotium', 'nouns:nos', 'nouns:pars',
  'nouns:periculum', 'nouns:populus', 'nouns:porta', 'nouns:puella',
  'nouns:qui', 'nouns:quis', 'nouns:rex', 'nouns:romanus', 'nouns:rosa',
  'nouns:sacrificium', 'nouns:sapientia', 'nouns:serva', 'nouns:servus',
  'nouns:simulacrum', 'nouns:spectaculum', 'nouns:statua', 'nouns:taberna',
  'nouns:tabula', 'nouns:tartarus', 'nouns:templum', 'nouns:toga',
  'nouns:tres', 'nouns:tu', 'nouns:turba', 'nouns:umbra', 'nouns:unus',
  'nouns:urbs', 'nouns:uxor', 'nouns:verbum', 'nouns:villa', 'nouns:vinum',
  'nouns:vos',
];

/// One volume-2 item per type the volume brings, including every adjective
/// type. The type decides the whole paradigm, so a wrong one is a silent
/// vocabulary error.
const _oneItemPerType = {
  'nouns:amicitia': 'A-Deklination',
  'nouns:acerbus': 'Adjektiv-a-o',
  'nouns:asper': 'Adjektiv-a-o-er',
  'nouns:celer': 'Adjektiv-dreiendig',
  'nouns:crudelis': 'Adjektiv-zweiendig',
  'nouns:acies': 'E-Deklination',
  'nouns:aedis': 'Konsonantische-Deklination-i-mf',
  'nouns:aetas': 'Konsonantische-Deklination-mf',
  'nouns:caput': 'Konsonantische-Deklination-n',
  'nouns:digitus': 'O-Deklination-maskulinum',
  'nouns:aurum': 'O-Deklination-neutrum',
  'nouns:adventus': 'U-Deklination',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<PracticeItem> nouns;

  setUpAll(() async {
    nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
  });

  test('every nominal generates a paradigm without a gap', () {
    for (final item in nouns) {
      expect(item.formOrder, isNotEmpty, reason: item.id);
      expect(item.forms, hasLength(item.formOrder.length), reason: item.id);
      for (var i = 0; i < item.forms.length; i++) {
        expect(item.forms[i], isNotEmpty,
            reason: '${item.id} ${item.formOrder[i]}');
      }
    }
  });

  test('the volume-2 nominals carry the type of their class', () {
    final byId = {for (final item in nouns) item.id: item.type};
    for (final entry in _oneItemPerType.entries) {
      expect(byId, containsPair(entry.key, entry.value));
    }
  });

  test('the items of volume 1 keep their id', () {
    expect(nouns.map((i) => i.id).toSet(), containsAll(_idsOfVolumeOne));
  });
}
