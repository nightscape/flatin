import 'dart:io';
import 'dart:typed_data' show ByteData;

import 'package:flutter/services.dart' show FontLoader;

/// The test font Ahem draws every glyph as a box. Roboto and the Material
/// icons come from the Flutter SDK, Cinzel from the app assets.
Future<void> loadAppFonts() async {
  final sdkFonts =
      '${Platform.environment['FLUTTER_ROOT']}'
      '/bin/cache/artifacts/material_fonts';
  await _load('Roboto', [
    for (final weight in ['Regular', 'Medium', 'Bold'])
      '$sdkFonts/Roboto-$weight.ttf',
  ]);
  await _load('MaterialIcons', ['$sdkFonts/MaterialIcons-Regular.otf']);
  await _load('Cinzel', ['assets/fonts/Cinzel.ttf']);
}

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = await File(file).readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}
