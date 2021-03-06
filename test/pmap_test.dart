import 'package:pmap/pmap.dart';
import 'package:test/test.dart';

int _square(int x) => x * x;

void main() {
  final input = Iterable<int>.generate(1000);

  final mapped = input.map(_square).toList(growable: false);

  void squareTests(bool inOrder) => group(
        inOrder ? 'Ordered' : 'Unordered',
        () => Iterable.generate(10, (i) => i + 1).forEach(
          (parallel) {
            test('calculate squares in $parallel isolates', () async {
              final pmapped = await input
                  .mapParallel(_square, parallel: parallel, inOrder: inOrder)
                  .toList();
              expect(pmapped, unorderedEquals(mapped));
            });
          },
        ),
      );
  squareTests(true);
  squareTests(false);
}
