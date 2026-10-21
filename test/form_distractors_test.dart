import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/diagnosis.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/form_distractors.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/hand_items.dart';

class _SameGerman implements GermanForms {
  final Map<FormKey, String> byKey;
  const _SameGerman(this.byKey);

  @override
  bool covers(PracticeItem item, FormKey key) => true;

  @override
  String render(PracticeItem item, FormKey key) => byKey[key] ?? key;
}

class _CoversOnly extends _SameGerman {
  final Set<FormKey> keys;
  const _CoversOnly(this.keys) : super(const {});

  @override
  bool covers(PracticeItem item, FormKey key) => keys.contains(key);
}

const _target = 'ind.perf.akt.2.pl';

PracticeItem _hand(Map<FormKey, List<String>> forms) => handItem(
  dataFileId: 'verbs',
  lemma: 'vocare',
  axes: fullVerbAxes,
  forms: {
    _target: ['vocavistis', 'vocastis'],
    ...forms,
  },
);

Set<GrammarBundle> _bundles(PracticeItem item) => {
  for (final key in item.formOrder) bundleOf(item, key),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('D1 rule 1: a neighbour differs in exactly one axis', () {
    test(
      'real forms of the same word, or the ending of another type',
      () async {
        final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
        final vocare = verbs.singleWhere((i) => i.id == 'verbs:vocare');
        const key = 'ind.praes.akt.3.sg';
        final asked = vocare.formLabels[vocare.formOrder.indexOf(key)].features;
        for (int seed = 0; seed < 20; seed++) {
          final answer = formChoice(
            vocare,
            key,
            _bundles(vocare),
            const FakeGermanForms(),
            3,
            Random(seed),
          );
          for (final option in answer.options) {
            if (option == answer.right) continue;
            if (option.builtWrongBy != null) continue;
            final features = vocare
                .formLabels[vocare.formOrder.indexOf(option.formKey)]
                .features;
            expect(
              {
                ...asked.keys,
                ...features.keys,
              }.where((axis) => asked[axis] != features[axis]),
              hasLength(1),
              reason: '${option.formKey} next to $key',
            );
          }
        }
      },
    );

    test('a form two axes away is no distractor', () {
      final item = _hand({
        'ind.praes.akt.2.pl': ['vocatis'],
        'ind.fut.pass.2.pl': ['vocabimini'],
      });
      expect(
        () => formChoice(
          item,
          _target,
          _bundles(item),
          const FakeGermanForms(),
          2,
          Random(1),
        ),
        throwsA(isA<CannotBuild>()),
      );
    });
  });

  group('D1 rule 2: only unlocked bundles', () {
    test('a form of a locked bundle is never offered', () {
      final item = _hand({
        'ind.praes.akt.2.pl': ['vocatis'],
        'ind.fut.akt.2.pl': ['vocabitis'],
        'ind.perf.akt.3.pl': ['vocaverunt'],
        'ind.perf.akt.2.sg': ['vocavisti'],
      });
      final unlocked = {bundleOf(item, _target), 'ind.praes'};
      for (int seed = 0; seed < 20; seed++) {
        final answer = formChoice(
          item,
          _target,
          unlocked,
          const FakeGermanForms(),
          3,
          Random(seed),
        );
        expect(answer.options.map((o) => o.text).toSet(), {
          'vocavistis',
          'vocatis',
          'vocaverunt',
          'vocavisti',
        });
      }
    });
  });

  group('D1 rule 3: no option can be taken for the right answer', () {
    final item = _hand({
      'ind.praes.akt.2.pl': ['vocātis'],
      'konj.perf.akt.2.pl': ['vocāstis'],
      'ind.fut.akt.2.pl': ['vocabitis'],
      'ind.perf.akt.3.pl': ['vocaverunt'],
      'ind.perf.akt.2.sg': ['vocavisti'],
    });

    test('an accepted variant of the right answer is not offered', () {
      for (int seed = 0; seed < 30; seed++) {
        final answer = formChoice(
          item,
          _target,
          _bundles(item),
          const FakeGermanForms(),
          3,
          Random(seed),
        );
        expect(
          answer.options.map((o) => norm(o.text)),
          isNot(contains('vocastis')),
        );
      }
    });

    test('two options never share a normalised spelling', () {
      for (int seed = 0; seed < 30; seed++) {
        final answer = formChoice(
          item,
          _target,
          _bundles(item),
          const FakeGermanForms(),
          3,
          Random(seed),
        );
        final spellings = answer.options.map((o) => norm(o.text)).toList();
        expect(spellings.toSet(), hasLength(spellings.length));
      }
    });

    test('syncretic spellings of two neighbours count once', () {
      final twin = _hand({
        'ind.praes.akt.2.pl': ['vocatis'],
        'ind.fut.akt.2.pl': ['vocātis'],
      });
      expect(
        () => formChoice(
          twin,
          _target,
          _bundles(twin),
          const FakeGermanForms(),
          2,
          Random(1),
        ),
        throwsA(isA<CannotBuild>()),
      );
    });

    test(
      'a neighbour with the German text of the right answer is not offered',
      () {
        final german = _SameGerman({
          _target: 'ihr habt gerufen',
          'ind.praes.akt.2.pl': 'ihr habt gerufen',
          'ind.fut.akt.2.pl': 'ihr werdet rufen',
          'ind.perf.akt.3.pl': 'ihr werdet rufen',
        });
        final answer = formChoice(
          item,
          _target,
          _bundles(item),
          german,
          2,
          Random(1),
        );
        expect(
          answer.options.map((o) => o.formKey),
          unorderedEquals([
            _target,
            'ind.perf.akt.2.sg',
            anyOf('ind.fut.akt.2.pl', 'ind.perf.akt.3.pl'),
          ]),
        );
      },
    );
  });

  group('D1 rule 4: every option carries its form', () {
    test('real forms carry their own key, the others the diagnosis', () async {
      final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final amare = verbs.singleWhere((i) => i.id == 'verbs:amare');
      const key = 'ind.praes.akt.3.sg';
      int otherType = 0;
      for (int seed = 0; seed < 20; seed++) {
        final answer = formChoice(
          amare,
          key,
          _bundles(amare),
          const FakeGermanForms(),
          4,
          Random(seed),
        );
        for (final option in answer.options) {
          expect(option.lexemeId, amare.id);
          final built = option.builtWrongBy;
          if (built == null) {
            expect(
              amare.accepts(
                amare.formOrder.indexOf(option.formKey),
                option.text,
              ),
              isTrue,
            );
          } else {
            otherType++;
            expect(built, isA<EndingOfOtherType>());
            expect(option.formKey, key);
          }
        }
      }
      expect(otherType, greaterThan(0));
    });
  });

  group('D2 too few distractors', () {
    test('throws instead of returning a short list', () {
      final item = _hand({
        'ind.praes.akt.2.pl': ['vocatis'],
      });
      expect(
        () => formChoice(
          item,
          _target,
          _bundles(item),
          const FakeGermanForms(),
          2,
          Random(1),
        ),
        throwsA(isA<CannotBuild>()),
      );
    });
  });

  group('D3 German coverage per key', () {
    final item = _hand({
      'ind.praes.akt.2.pl': ['vocatis'],
      'ind.fut.akt.2.pl': ['vocabitis'],
      'ind.perf.akt.3.pl': ['vocaverunt'],
      'ind.perf.akt.2.sg': ['vocavisti'],
    });
    final all = item.formOrder.toSet();

    test('a neighbour without German text is never offered', () {
      final german = _CoversOnly(all.difference({'ind.fut.akt.2.pl'}));
      for (int seed = 0; seed < 20; seed++) {
        final answer = formChoice(
          item,
          _target,
          _bundles(item),
          german,
          3,
          Random(seed),
        );
        expect(answer.options.map((o) => o.text), isNot(contains('vocabitis')));
      }
    });

    test('a target without German text cannot be built', () {
      expect(
        () => formChoice(
          item,
          _target,
          _bundles(item),
          _CoversOnly(all.difference({_target})),
          2,
          Random(1),
        ),
        throwsA(isA<CannotBuild>()),
      );
    });

    test('too few covered neighbours cannot be built', () {
      expect(
        () => formChoice(
          item,
          _target,
          _bundles(item),
          _CoversOnly(all.difference({'ind.fut.akt.2.pl'})),
          4,
          Random(1),
        ),
        throwsA(isA<CannotBuild>()),
      );
    });
  });
}
