import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/providers/locale_provider.dart';

/// The text a key-echo app renders for [key] filled with [args]:
/// `key{a=1,b=x}`, args sorted by name; no args render the plain key.
String keyEcho(String key, [Map<String, Object> args = const {}]) {
  if (args.isEmpty) return key;
  final names = args.keys.toList()..sort();
  return '$key{${[for (final n in names) '$n=${args[n]}'].join(',')}}';
}

final _placeholder = RegExp(r'\{(\w+)\}');
final _pluralKey = RegExp(r'-\d+$');

/// Loads the real translation file but turns every text into its own key plus
/// the values of its placeholders (see [keyEcho]), so a widget test finds and
/// asserts texts and their arguments by key, not by wording. [code] picks the
/// real file whose placeholder names are kept.
class KeyEchoTranslationLoader extends FileTranslationLoader {
  KeyEchoTranslationLoader({String code = 'en'})
    : super(forcedLocale: Locale(code));

  @override
  Future<Map> load() async => echo(await super.load(), '');

  static Map echo(Map tree, String prefix) => {
    for (final MapEntry(:key, :value) in tree.entries)
      key: value is Map
          ? echo(value, '$prefix$key.')
          : _text('$prefix$key', value),
  };

  static String _text(String key, Object? value) {
    assert(
      !_pluralKey.hasMatch(key),
      '$key is a flutter_i18n plural key: key-echo does not render plurals',
    );
    final template = value is String ? value : '';
    assert(
      !template.replaceAll(_placeholder, '').contains(RegExp('[{}]')),
      '$key has a brace that is no {name} placeholder: "$template"',
    );
    final names = {for (final m in _placeholder.allMatches(template)) m[1]!};
    return keyEcho(key, {for (final n in names) n: '{$n}'});
  }
}

/// [home] in an app whose i18n texts are their keys.
Widget wrapInKeyEchoApp(Widget home) => ProviderScope(
  retry: noRetry,
  overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
  child: MaterialApp(
    localizationsDelegates: [
      FlutterI18nDelegate(translationLoader: KeyEchoTranslationLoader()),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    builder: FlutterI18n.rootAppBuilder(),
    home: home,
  ),
);
