import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/lesson_provider.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:latin_practice/screens/settings_screen.dart';

Widget _app(Widget home) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: [
          FlutterI18nDelegate(
            translationLoader: FileTranslationLoader(
              basePath: 'assets/flutter_i18n',
              fallbackFile: 'en',
              useCountryCode: false,
            ),
          ),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: FlutterI18n.rootAppBuilder(),
        home: home,
      ),
    );

void main() {
  testWidgets('a word outside the lessons can be switched off',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final probe = ProviderContainer();
    final outside = await probe.read(wordsOutsideLessonsProvider.future);
    probe.dispose();
    final word = normalizeDiacritics(outside.first);

    await tester.pumpWidget(_app(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Other words'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Tap the expand arrow: the tile body toggles the whole group.
    await tester.tap(find.descendant(
      of: find.byKey(const Key('lesson.other')),
      matching: find.byIcon(Icons.expand_more),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(Key('word.$word')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(Key('word.$word')));
    await tester.pumpAndSettle();

    final reloaded = ProviderContainer();
    final settings = await reloaded.read(settingsProvider.future);
    expect(settings.isWordSelected(word), isFalse);

    final practicable =
        await reloaded.read(practicableItemsByTypeProvider.future);
    final practisedWords = [...practicable['nouns']!, ...practicable['verbs']!]
        .map((item) => normalizeDiacritics(item.baseForm ?? item.word!))
        .toSet();
    expect(practisedWords, isNot(contains(word)));
    reloaded.dispose();
  });
}
