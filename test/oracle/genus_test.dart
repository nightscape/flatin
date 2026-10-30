import 'package:flutter_test/flutter_test.dart';

import 'sample.dart';

void main() {
  group('the genus of a noun line', () {
    test('a letter after a comma, without a period', () {
      expect(genusOf('ei, f'), {'f'});
      expect(genusOf('is, m'), {'m'});
    });

    test('two letters', () {
      expect(genusOf('m. f.'), {'m', 'f'});
      expect(genusOf('m. et f.'), {'m', 'f'});
      expect(genusOf('m, f'), {'m', 'f'});
    });

    test('a letter followed by more description', () {
      expect(genusOf('f. sing.'), {'f'});
      expect(genusOf('f. (nom. sg. inusité)'), {'f'});
    });

    test('a field without a genus letter has none', () {
      expect(genusOf(''), isEmpty);
      expect(genusOf('i, pl. tantum'), isEmpty);
    });

    test('a letter inside a word is not a genus', () {
      expect(genusOf('mf. nm. fn'), isEmpty);
      expect(genusOf('ēī, nf.'), isEmpty);
    });
  });
}
