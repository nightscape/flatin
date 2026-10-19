import 'dart:convert';

import 'package:flutter/services.dart';

/// Reads an asset as text.
///
/// `rootBundle.loadString` hands an asset of 50 KiB or more to a background
/// isolate, whose answer never arrives inside a widget test's fake time.
Future<String> loadAssetText(String path) async =>
    _decode(await rootBundle.load(path));

String _decode(ByteData data) => utf8.decode(
  data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
);
