import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_provider.g.dart';

/// A language the app ships a translation file for.
class OfferedLocale {
  const OfferedLocale(this.code, this.endonym, this.englishName, this.flag);

  final String code;
  final String endonym;
  final String englishName;
  final String flag;

  Locale get locale => Locale(code);

  /// "🇩🇪 Deutsch (German)", shortened where both names agree.
  String get label => endonym == englishName
      ? '$flag $endonym'
      : '$flag $endonym ($englishName)';

  bool matches(String query) {
    final needle = foldForSearch(query.trim());
    return needle.isEmpty ||
        foldForSearch(endonym).contains(needle) ||
        foldForSearch(englishName).contains(needle) ||
        code.contains(needle);
  }
}

/// One line per language: `supportedLocales` and the language picker both
/// read this list. A language is listed only when every string on screen
/// exists in it.
const offeredLocales = <OfferedLocale>[
  OfferedLocale('de', 'Deutsch', 'German', '🇩🇪'),
];

/// The course language: what a device the app has no translation for gets.
const courseLocale = Locale('de');

/// The device language when the app offers it, else the course language.
Locale resolveLocale(List<Locale>? preferred) {
  for (final wanted in preferred ?? const <Locale>[]) {
    for (final offered in offeredLocales) {
      if (offered.code == wanted.languageCode) return offered.locale;
    }
  }
  return courseLocale;
}

/// The language the learner picked, or null while they follow the device.
@riverpod
class LocaleOverride extends _$LocaleOverride {
  static const String _key = 'app_locale';

  @override
  Future<Locale?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code == null) return null;
    if (offeredLocales.every((offered) => offered.code != code)) {
      await prefs.remove(_key);
      return null;
    }
    return Locale(code);
  }

  /// A null [locale] hands the choice back to the device language.
  Future<void> select(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
    state = AsyncData(locale);
  }
}

/// Lowercases and strips the accents a learner may not type.
String foldForSearch(String text) {
  final folded = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    folded.write(_withoutAccent[char] ?? char);
  }
  return folded.toString();
}

const _withoutAccent = <String, String>{
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ç': 'c', 'č': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ı': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ō': 'o', 'ø': 'o',
  'š': 's', 'ß': 'ss',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
  'ý': 'y', 'ÿ': 'y',
  'ž': 'z',
};
