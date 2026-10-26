import 'package:flutter_test/flutter_test.dart';

import 'support/step_shots.dart';

void main() {
  test('the issue example', () {
    expect(
      stepShotName(
        7,
        'Stadt bauen',
        'Ein Gebäude kaufen',
        'When ich tippe auf "Bauen"',
      ),
      '0007-stadt-bauen-ein-gebaeude-kaufen-ich-tippe-auf-bauen.png',
    );
  });

  test('umlauts and sharp s are transliterated, other characters become -', () {
    expect(
      stepShotName(1, 'Ää', 'Öö', 'Then Üü ß, a/b!'),
      '0001-aeae-oeoe-ueue-ss-a-b.png',
    );
  });

  test('each slug is cut to 40 characters without a trailing dash', () {
    final name = stepShotName(12345, 'f', 'x' * 50, 'And ${'ab ' * 20}');
    expect(name, startsWith('12345-f-${'x' * 40}-'));
    final stepSlug = name.split('-${'x' * 40}-').last.replaceAll('.png', '');
    expect(stepSlug.length, lessThanOrEqualTo(40));
    expect(stepSlug, isNot(endsWith('-')));
  });

  test('a failed step gets the suffix -FAILED', () {
    expect(
      stepShotName(3, 'f', 's', 'Given a', failed: true),
      '0003-f-s-a-FAILED.png',
    );
  });
}
