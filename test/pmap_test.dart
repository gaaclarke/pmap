import 'package:pmap/pmap.dart';
import 'package:test/test.dart';

int _square(int x) => x * x;

void main() {
  final input = Iterable<int>.generate(1000);

  final mapped = input.map(_square).toList(growable: false);

  Iterable.generate(10, (i) => i + 1).forEach(
    (parallel) {
      test('calculate squares in $parallel isolates', () async {
        final pmapped = await pmap(input, _square, parallel: parallel).toList();
        expect(pmapped, equals(mapped));
      });
    },
  );
}
