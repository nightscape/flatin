import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The store locale this run makes pictures for, e.g. `de-DE`.
const storeLocale = String.fromEnvironment(
  'STORE_LOCALE',
  defaultValue: 'de-DE',
);

const _width = 1080;
const _height = 1920;
const _pixelRatio = 2.625;

Locale get storeDeviceLocale {
  final [language, country] = storeLocale.split('-');
  return Locale(language, country);
}

/// Headless runs write into `build/store_shots/<locale>/`, where
/// `fastlane store_pictures` collects them; an app on a device has a
/// read-only working directory, so it writes into its temporary directory.
String get _pictureDir => Platform.environment.containsKey('FLUTTER_TEST')
    ? 'build/store_shots/$storeLocale'
    : '${Directory.systemTemp.path}/store_shots/$storeLocale';

/// Renders the screen as a 1080 x 1920 phone picture into
/// `<_pictureDir>/<name>`.
Future<void> saveStorePicture(WidgetTester tester, String name) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);
  // Images decode outside the fake-async zone of the test.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump();

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    assert(
      image.width == _width && image.height == _height,
      'picture is ${image.width} x ${image.height}',
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  });
  File('$_pictureDir/$name')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}
