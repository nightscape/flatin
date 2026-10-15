/// Expands the Collatinus inflection data into "morph number -> spellings".
///
/// Collatinus builds a form the same way our types do: a radical plus an
/// ending. `modeles.la` holds the models (`pere:` inheritance, `R:` radical
/// definitions, `des:` endings, `$` ending macros, `abs:` absent morphs),
/// `lemmes.la` the lemmas with up to two explicit radicals, `irregs.la` the
/// irregular forms and `morphos.en` the feature text of morph numbers 1-416.
///
/// Facts that are not obvious from the file format and that the tests pin
/// (`oracle_test.dart`, "expander goldens"):
/// - `abs:` removes inherited endings only; endings the model defines itself
///   stay.
/// - A repeated `des:` for the same morph inside one model is additive.
/// - Fields 3 and 4 of a `lemmes.la` line are radicals 1 and 2; each may be a
///   comma-separated list of variants.
/// - Trailing digits in an ending are homonym markers and are stripped.
/// - An ending list shorter than its morph range repeats its last entry.
/// - `suf`/`sufd` (suffixed variants such as `huiusce`) are not expanded.
library;

import 'dart:io';

/// The directory `tool/oracle/fetch_collatinus.sh` writes.
const collatinusDir = '.dart_tool/oracle/collatinus';

final _combining = RegExp('[̀-ͯ]');

/// Splits [text] into letters, keeping a combining mark with its base letter.
List<String> letters(String text) {
  final out = <String>[];
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (_combining.hasMatch(char) && out.isNotEmpty) {
      out[out.length - 1] += char;
    } else {
      out.add(char);
    }
  }
  return out;
}

/// How a model builds one radical from the canonical lemma spelling.
final class RadicalSpec {
  /// `K` (the lemma itself), `-` (only from the lemma line) or `cut`.
  final String kind;
  final int cut;
  final String add;

  RadicalSpec(this.kind, [this.cut = 0, this.add = '']);
}

final class CollatinusModel {
  final String name;
  final Map<int, RadicalSpec> radicals = {};

  /// Morph number -> (radical number, ending).
  final Map<int, List<(int, String)>> endings = {};

  CollatinusModel(this.name);
}

/// "121-126,139" -> [121, …, 126, 139].
List<int> parseMorphRange(String text) => [
  for (final part in text.split(','))
    if (part.contains('-'))
      for (
        var i = int.parse(part.split('-')[0]);
        i <= int.parse(part.split('-')[1]);
        i++
      )
        i
    else
      int.parse(part),
];

class Collatinus {
  final Map<String, CollatinusModel> models = {};

  /// Lemma key -> the fields of its `lemmes.la` line.
  final Map<String, List<String>> lemmaLines = {};

  /// (form, lemma, morphs, exclusive) of `irregs.la`; an exclusive form
  /// replaces the model's endings for its morphs.
  final List<(String, String, List<int>, bool)> irregulars = [];

  /// Morph number -> its feature text in `morphos.en`.
  final Map<int, String> morphs = {};

  Collatinus(String directory) {
    File file(String name) {
      final data = File('$directory/$name');
      if (!data.existsSync()) {
        throw StateError(
          'Collatinus data missing: ${data.path}. '
          'Run tool/oracle/fetch_collatinus.sh.',
        );
      }
      return data;
    }

    _loadModels(file('modeles.la').readAsLinesSync());
    for (final line in file('lemmes.la').readAsLinesSync()) {
      if (line.startsWith('!') || line.trim().isEmpty) continue;
      final fields = line.split('|');
      lemmaLines[fields[0].split('=')[0]] = fields;
    }
    for (final line in file('irregs.la').readAsLinesSync()) {
      if (line.startsWith('!') || !line.contains(':')) continue;
      final fields = line.split(':');
      final exclusive = fields[0].endsWith('*');
      irregulars.add((
        exclusive ? fields[0].substring(0, fields[0].length - 1) : fields[0],
        fields[1],
        parseMorphRange(fields[2]),
        exclusive,
      ));
    }
    for (final line in file('morphos.en').readAsLinesSync()) {
      final match = RegExp(r'^(\d+):(.*)$').firstMatch(line);
      if (match != null) morphs[int.parse(match[1]!)] = match[2]!.trim();
    }
  }

  void _loadModels(List<String> lines) {
    final macros = <String, String>{};
    CollatinusModel? current;
    var own = <int>{};
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('!')) continue;
      if (line.startsWith(r'$')) {
        final split = line.indexOf('=');
        macros[line.substring(1, split)] = line.substring(split + 1);
        continue;
      }
      final split = line.indexOf(':');
      final key = line.substring(0, split), value = line.substring(split + 1);
      switch (key) {
        case 'modele':
          current = models[value] = CollatinusModel(value);
          own = {};
        case 'pere':
          final parent = models[value]!;
          current!.radicals.addAll(parent.radicals);
          parent.endings.forEach((m, e) => current!.endings[m] = [...e]);
        case 'R':
          final [number, spec] = value.split(':');
          current!.radicals[int.parse(number)] = switch (spec) {
            'K' => RadicalSpec('K'),
            '-' => RadicalSpec('-'),
            _ => RadicalSpec(
              'cut',
              int.parse(spec.split(',')[0]),
              spec.contains(',') && spec.split(',')[1] != '0'
                  ? spec.split(',')[1]
                  : '',
            ),
          };
        case 'des' || 'des+':
          final [range, radical, list] = value.split(':');
          final morphNumbers = parseMorphRange(range);
          final endings = _expandEndings(list, macros);
          for (var i = 0; i < morphNumbers.length; i++) {
            final morph = morphNumbers[i];
            final ending = endings[i < endings.length ? i : endings.length - 1];
            // The first `des` of this model replaces what `pere` brought; a
            // second one for the same morph adds to it.
            if (key == 'des' && own.add(morph)) current!.endings[morph] = [];
            current!.endings.putIfAbsent(morph, () => []);
            for (final variant in ending.split(',')) {
              current.endings[morph]!.add((
                int.parse(radical),
                variant.replaceAll(RegExp(r'\d'), '').replaceAll('-', ''),
              ));
            }
          }
        case 'abs':
          for (final morph in parseMorphRange(value)) {
            if (!own.contains(morph)) current!.endings.remove(morph);
          }
        default: // pos, suf, sufd
      }
    }
  }

  List<String> _expandEndings(String list, Map<String, String> macros) {
    final out = <String>[];
    for (final piece in list.split(';')) {
      final marker = piece.indexOf(r'$');
      if (marker < 0) {
        out.add(piece);
        continue;
      }
      final prefix = piece.substring(0, marker);
      final macro = macros[piece.substring(marker + 1)]!;
      out.addAll(
        macro
            .split(';')
            .map((e) => e.split(',').map((v) => '$prefix$v').join(',')),
      );
    }
    return out;
  }

  /// Morph number -> spellings, with the Collatinus quantity marks.
  Map<int, List<String>> inflect(String lemmaKey) {
    final fields = lemmaLines[lemmaKey];
    if (fields == null) throw ArgumentError('no Collatinus lemma "$lemmaKey"');
    final canonical = (fields[0].contains('=')
            ? fields[0].split('=')[1]
            : fields[0])
        .replaceAll(RegExp(r'\d'), '');
    final model = models[fields[1]]!;

    final radicals = <int, List<String>>{};
    model.radicals.forEach((number, spec) {
      if (spec.kind == 'K') radicals[number] = [canonical];
      if (spec.kind == 'cut') {
        final chars = letters(canonical);
        radicals[number] = [
          chars.sublist(0, chars.length - spec.cut).join() + spec.add,
        ];
      }
    });
    if (fields[2].isNotEmpty) radicals[1] = fields[2].split(',');
    if (fields[3].isNotEmpty) radicals[2] = fields[3].split(',');

    final out = <int, List<String>>{};
    model.endings.forEach((morph, list) {
      for (final (number, ending) in list) {
        for (final radical in radicals[number] ?? const <String>[]) {
          (out[morph] ??= []).add(radical + ending);
        }
      }
    });

    final bare = canonical.replaceAll(_combining, '');
    for (final (form, lemma, morphNumbers, exclusive) in irregulars) {
      if (_plain(lemma) != _plain(bare) && lemma != lemmaKey) continue;
      for (final morph in morphNumbers) {
        if (exclusive || !out.containsKey(morph)) out[morph] = [];
        out[morph]!.add(form);
      }
    }
    return out;
  }

  /// The model name of [lemmaKey], e.g. `amo` for `ămo`.
  String modelOf(String lemmaKey) {
    final fields = lemmaLines[lemmaKey];
    if (fields == null) throw ArgumentError('no Collatinus lemma "$lemmaKey"');
    return fields[1];
  }
}

const _long = 'āēīōūȳăĕĭŏŭ', _plainVowels = 'aeiouyaeiou';

/// Letters only: no case, no quantity marks, `v`/`j` as `u`/`i`. `irregs.la`
/// spells a lemma `uulgus` where `lemmes.la` has `vulgus`.
String _plain(String text) => text
    .toLowerCase()
    .replaceAll(_combining, '')
    .replaceAllMapped(
      RegExp('[$_long]'),
      (m) => _plainVowels[_long.indexOf(m[0]!)],
    )
    .replaceAll('v', 'u')
    .replaceAll('j', 'i');
