import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_i18n/utils/simple_translator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/i18n_keys.dart';
import 'support/key_echo_i18n.dart';

const _cases = 300;
const _valueLetters = 'abz09 ä,=-.:"\'';

final _placeholder = RegExp(r'\{(\w+)\}');

Map<String, String> _texts(String code) {
  final json =
      jsonDecode(File('assets/flutter_i18n/$code.json').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final key in translationKeys(code))
      key: key.split('.').fold<dynamic>(json, (node, k) => node[k]) as String,
  };
}

String _value(Random rng) => String.fromCharCodes([
  for (var i = 0; i < 1 + rng.nextInt(6); i++)
    _valueLetters.codeUnitAt(rng.nextInt(_valueLetters.length)),
]);

/// What the app renders for [key]: the loader's text, filled the way
/// FlutterI18n.translate fills it.
String _render(Map decoded, String key, Map<String, String> args) =>
    SimpleTranslator(
      decoded,
      key,
      '.',
      translationParams: args,
      missingKeyTranslationHandler: (key) => fail('missing key $key'),
    ).translate();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final code in ['de', 'en']) {
    test('[E] $code: every key renders as keyEcho of its placeholders and '
        'drawn values', () async {
      final decoded = await KeyEchoTranslationLoader(code: code).load();
      final texts = _texts(code);
      // Fixed examples as explicit (key, args) states, run before the draws.
      final fixed = <(String, Map<String, String>)>[
        ('exam.screen.points', {'n': '3', 'total': '12'}),
        ('settings.lesson', {'n': '21'}),
        ('settings.outsideRange', {}),
      ];
      final keys = texts.keys.toList();
      final rng = Random(397);
      final draws = [
        ...fixed,
        for (var i = 0; i < _cases; i++) (keys[rng.nextInt(keys.length)], null),
      ];
      for (final (key, given) in draws) {
        final names = {
          for (final m in _placeholder.allMatches(texts[key]!)) m[1]!,
        };
        final args = given ?? {for (final n in names) n: _value(rng)};
        expect(args.keys.toSet(), names, reason: '$code $key: fixed args');
        expect(
          _render(decoded, key, args),
          keyEcho(key, args),
          reason: '$code $key $args',
        );
        if (names.isEmpty) {
          expect(_render(decoded, key, {}), key, reason: '$code $key');
        }
      }
    });
  }

  test('[E] a placeholder repeated in a text is one argument', () {
    final echoed = KeyEchoTranslationLoader.echo({
      't': 'a {x} b {x} c {w}',
    }, '');
    expect(
      _render(echoed, 't', {'x': '1', 'w': 'q'}),
      keyEcho('t', {'x': '1', 'w': 'q'}),
    );
  });

  test('[E] keyEcho sorts the arguments by name', () {
    expect(
      keyEcho('settings.kursstand.fromLesson', {'z': 1, 'n': 3}),
      'settings.kursstand.fromLesson{n=3,z=1}',
    );
  });
}
