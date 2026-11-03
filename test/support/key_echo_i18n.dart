import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/providers/locale_provider.dart';

/// Loads the real translation file but turns every text into its own key, so
/// a widget test finds and asserts texts by key, not by wording.
class KeyEchoTranslationLoader extends FileTranslationLoader {
  KeyEchoTranslationLoader() : super(forcedLocale: const Locale('en'));

  @override
  Future<Map> load() async => _echo(await super.load(), '');

  static Map _echo(Map tree, String prefix) => {
    for (final MapEntry(:key, :value) in tree.entries)
      key: value is Map ? _echo(value, '$prefix$key.') : '$prefix$key',
  };
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
