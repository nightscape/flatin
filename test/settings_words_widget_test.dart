import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latin_practice/providers/lesson_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the settings screen has no words outside the lessons to show',
      () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();

    expect(await container.read(wordsOutsideLessonsProvider.future), isEmpty);
    container.dispose();
  });
}
