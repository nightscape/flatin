import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/widgets/explanation_lines.dart';

import 'key_echo_i18n.dart';

/// [wrapInKeyEchoApp] with an [explainer] and more provider [overrides];
/// the data language is German, as in [wrapInKeyEchoApp].
Widget wrapInKeyEchoAppWith(
  Widget home, {
  Explainer? explainer,
  List<Override> overrides = const [],
}) => ProviderScope(
  retry: noRetry,
  overrides: [
    if (explainer != null) explainerProvider.overrideWithValue(explainer),
    dataLanguageProvider.overrideWith((ref) => 'de'),
    ...overrides,
  ],
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
