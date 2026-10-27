import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

/// The German translations, loaded before any widget is pumped, so the first
/// frame already holds translated text and no test has to wait for it.
Future<LocalizationsDelegate<FlutterI18n>> preloadedI18n() async {
  final i18n = FlutterI18n(
    FileTranslationLoader(
      basePath: 'assets/flutter_i18n',
      fallbackFile: 'en',
      forcedLocale: const Locale('de'),
      useCountryCode: false,
    ),
    '.',
  );
  await i18n.load();
  return _Preloaded(i18n);
}

class _Preloaded extends LocalizationsDelegate<FlutterI18n> {
  const _Preloaded(this.i18n);

  final FlutterI18n i18n;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<FlutterI18n> load(Locale locale) => SynchronousFuture(i18n);

  @override
  bool shouldReload(_Preloaded old) => false;
}
