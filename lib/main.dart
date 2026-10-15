import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/flutter_i18n_delegate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';

/// Nothing here is loaded over a network: a read that fails fails again, and
/// Riverpod's default retries would keep the screens in their loading state
/// for a minute instead of showing the learner the error.
Duration? noRetry(int retryCount, Object error) => null;

void main() {
  runApp(ProviderScope(retry: noRetry, child: const LatinPracticeApp()));
}

class LatinPracticeApp extends StatelessWidget {
  const LatinPracticeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Latin Practice',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        useMaterial3: true,
      ),
      localizationsDelegates: [
        FlutterI18nDelegate(
          translationLoader: FileTranslationLoader(
            basePath: 'assets/flutter_i18n',
            fallbackFile: 'en',
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
      ],
      builder: FlutterI18n.rootAppBuilder(),
      home: const HomeScreen(),
    );
  }
}
