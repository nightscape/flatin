import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/flutter_i18n_delegate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: LatinPracticeApp()));
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
