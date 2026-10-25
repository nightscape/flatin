import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/flutter_i18n_delegate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/locale_provider.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

/// Nothing here is loaded over a network: a read that fails fails again, and
/// Riverpod's default retries would keep the screens in their loading state
/// for a minute instead of showing the learner the error.
Duration? noRetry(int retryCount, Object error) => null;

void main() {
  runApp(ProviderScope(retry: noRetry, child: const LatinPracticeApp()));
}

class LatinPracticeApp extends ConsumerWidget {
  const LatinPracticeApp({super.key, this.home = const HomeScreen()});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateTitle: (context) => FlutterI18n.translate(context, 'app.title'),
      locale: ref.watch(localeOverrideProvider).value,
      supportedLocales: [for (final offered in offeredLocales) offered.locale],
      localeListResolutionCallback: (locales, supported) =>
          resolveLocale(locales),
      theme: romanTheme,
      localizationsDelegates: [
        FlutterI18nDelegate(
          translationLoader: FileTranslationLoader(
            basePath: 'assets/flutter_i18n',
            fallbackFile: 'de',
            useCountryCode: false,
          ),
          missingTranslationHandler: (key, locale) {
            print(
              "--- Missing Key: $key, languageCode: ${locale?.languageCode ?? 'unknown'}",
            );
          },
        ),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: FlutterI18n.rootAppBuilder(),
      home: home,
    );
  }
}
