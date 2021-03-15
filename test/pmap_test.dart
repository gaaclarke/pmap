import 'package:pmap/pmap.dart';
import 'package:test/test.dart';

int _square(int x) => x * x;

int? _maybeSquare(int? x) => x != null ? x * x : null;

void main() {
  final input = Iterable<int>.generate(1000);
  final mapped = input.map(_square).toList(growable: false);
  final parallelValues = Iterable.generate(10, (i) => i + 1);

  void squareTests(bool preserveOrder) => group(
        preserveOrder ? 'Ordered' : 'Unordered',
        () => parallelValues.forEach(
          (parallel) {
            test('calculate squares in $parallel isolates', () async {
              final pmapped = await input
                  .mapParallel(_square,
                      parallel: parallel, preserveOrder: preserveOrder)
                  .toList();
              expect(
                pmapped,
                preserveOrder ? equals(mapped) : unorderedEquals(mapped),
              );
            });
          },
        ),
      );
  squareTests(true);
  squareTests(false);

  group('Special cases', () {
    parallelValues.forEach(
      (parallel) => test('Contains null in $parallel isolates', () async {
        final nullInput =
            const <int?>[null].followedBy(input).followedBy(const [null, null]);
        final pmapped = await (nullInput
            .mapParallel(_maybeSquare, parallel: parallel)
            .toList());
        expect(pmapped, equals(nullInput.map(_maybeSquare)));
      }),
    );
  });
}
