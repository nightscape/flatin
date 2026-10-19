import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/main.dart';

/// Runs the real app with the device reporting [deviceLocale].
Future<void> pumpAppOnDevice(
  WidgetTester tester,
  Locale deviceLocale, {
  ProviderContainer? container,
}) async {
  tester.platformDispatcher.localesTestValue = <Locale>[deviceLocale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container ?? freshContainer(),
      child: const LatinPracticeApp(),
    ),
  );
  await settle(tester);
}

/// A container with no provider state, as after an app restart.
ProviderContainer freshContainer() => ProviderContainer(retry: noRetry);

/// The loading spinner animates forever, so pumpAndSettle would never return.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String titleOf(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('app.title'))).data!;
