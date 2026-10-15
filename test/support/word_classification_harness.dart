import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/services/fsrs_storage.dart';

Widget wrapInApp(Widget home) => ProviderScope(
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

/// Disable the given types and put every card far in the future, so the
/// screens have to take their empty-due fallback.
Future<void> seedNothingDue(Map<String, Set<String>> disabledTypes) async {
  SharedPreferences.setMockInitialValues({
    'practice_settings': jsonEncode({
      'disabledForms': <String, List<String>>{},
      'disabledTypes':
          disabledTypes.map((file, types) => MapEntry(file, types.toList())),
      'inputStrategyIds': <String, String>{},
      'deselectedWords': <String>[],
    }),
  });

  final items = [
    ...await loadPracticeItems('lib/data/latin_nouns.yaml'),
    ...await loadPracticeItems('lib/data/latin_verbs.yaml'),
  ];
  final due = DateTime.now().toUtc().add(const Duration(days: 30));
  await FsrsStorage.saveCards({
    for (final item in items)
      PracticeItemCard.generateItemId(item): PracticeItemCard(
        itemId: PracticeItemCard.generateItemId(item),
        card: fsrs.Card(cardId: PracticeItemCard.generateItemId(item).hashCode),
        due: due,
      ),
  });
}

/// The loading spinner animates forever, so pumpAndSettle would never return.
Future<void> letItLoad(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
