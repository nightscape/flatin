import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/languages/language.dart';
import 'package:latin_practice/grammar/schema.dart' show parseGrammarFile;
import 'package:yaml/yaml.dart';

import 'support/gen_exam.dart';
import 'support/latin_course.dart';

const _draws = 3000;

/// Fixed spellings that run through the properties before the drawn ones:
/// the empty text, a combining mark, y with macron, a pair of twins.
const _examples = ['', 'ā', 'ȳ', 'Ȳ', 'hīc', 'hic', 'ē', 'ß', 'Ōā-'];

void main() {
  final y = loadYaml(File(latinCourse.language).readAsStringSync()) as YamlMap;
  final pairs = Map<String, String>.from(y['fold'] as YamlMap);
  final letters = _expand(y['letters'] as String);

  Iterable<String> texts(int seed) sync* {
    yield* _examples;
    final r = Random(seed);
    for (var i = 0; i < _draws; i++) {
      yield spelling(r, pairs);
    }
  }

  test('fold replaces the fold keys of la.yaml and nothing else', () {
    for (final s in texts(1)) {
      final expected = [for (final c in s.split('')) pairs[c] ?? c].join();
      expect(latinLang.fold(s), expected, reason: s);
    }
  });

  test('fold is idempotent and keeps the length in code units', () {
    for (final s in texts(2)) {
      final once = latinLang.fold(s);
      expect(latinLang.fold(once), once, reason: s);
      expect(once.length, s.length, reason: s);
    }
  });

  test('a text has a quantity mark exactly when it holds a fold key', () {
    for (final s in texts(3)) {
      expect(
        latinLang.hasQuantityMark(s),
        s.split('').any(pairs.containsKey),
        reason: s,
      );
    }
  });

  test('letters match the non-empty texts made of the letters of la.yaml', () {
    for (final s in texts(4)) {
      final expected =
          s.isNotEmpty &&
          s
              .split('')
              .every(
                (c) => letters.contains(c) || letters.contains(c.toLowerCase()),
              );
      expect(latinLang.letters.hasMatch(s), expected, reason: s);
    }
  });

  test('a fold value other than one code unit is refused, naming the key', () {
    for (var seed = 0; seed < 200; seed++) {
      final value = invalidFoldValue(Random(seed));
      final source = languageSourceWithFoldKey(
        'ā',
      ).replaceFirst('"ā":"x"', '"ā":${jsonEncode(value)}');
      expect(source, isNot(contains('"ā":"x"')), reason: value);
      expect(
        () => Language.parse(source),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"ā"'),
          ),
        ),
        reason: value,
      );
    }
  });

  test('a fold key of two code units or a regex class character is refused, '
      'naming the key', () {
    for (var seed = 0; seed < 200; seed++) {
      final key = invalidFoldKey(Random(seed));
      expect(
        () => Language.parse(languageSourceWithFoldKey(key)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"$key"'),
          ),
        ),
        reason: key,
      );
    }
  });

  test('two languages in one process each fold and make ids with their own '
      'fold', () {
    final source = File('lib/data/latin_nouns.yaml').readAsStringSync();
    final ofLatin = parseGrammarFile(
      source,
      path: 'lib/data/latin_nouns.yaml',
      lang: latinLang,
    );
    for (var seed = 0; seed < 8; seed++) {
      final drawn = drawnLanguage(Random(seed));
      final ofDrawn = parseGrammarFile(
        source,
        path: 'lib/data/latin_nouns.yaml',
        lang: drawn,
      );
      expect(drawn.id, isNot(latinLang.id));
      expect(identical(ofDrawn.lang, drawn), isTrue);
      expect(identical(ofLatin.lang, latinLang), isTrue);
      expect(ofDrawn.items.length, ofLatin.items.length);
      var marked = 0;
      for (final (i, item) in ofLatin.items.indexed) {
        final lemma = item.parts[ofLatin.lemmaPart ?? ofLatin.givenPart]!.first;
        if (item.id != latinLang.foldLower(lemma)) continue;
        expect(ofDrawn.items[i].id, drawn.foldLower(lemma), reason: lemma);
        if (latinLang.hasQuantityMark(lemma)) marked++;
      }
      expect(marked, greaterThan(0), reason: 'no lemma with a quantity mark');
    }
  });
}

/// The characters of a class body made of ranges `a-z` and single characters.
Set<String> _expand(String body) {
  final out = <String>{};
  final chars = body.split('');
  for (var i = 0; i < chars.length; i++) {
    if (i + 2 < chars.length && chars[i + 1] == '-') {
      for (
        var c = chars[i].codeUnitAt(0);
        c <= chars[i + 2].codeUnitAt(0);
        c++
      ) {
        out.add(String.fromCharCode(c));
      }
      i += 2;
    } else {
      out.add(chars[i]);
    }
  }
  return out;
}
