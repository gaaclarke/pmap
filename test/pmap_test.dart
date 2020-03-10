import 'package:pmap/pmap.dart';
import 'package:test/test.dart';

int _square(int x) => x * x;

Iterable<int> _countTo(int x) sync* {
  for( int i = 0; i < x; ++i) {
    yield i;
  }
}

void main() {
  test('square parallel 1', () async {
    List<int> input = _countTo(1000).toList();
    List<int> mapped = input.map(_square).toList();
    List<int> pmapped = await pmap(input, _square).toList();
    expect(pmapped, equals(mapped));
  });

  test('square parallel 2', () async {
    List<int> input = _countTo(1000).toList();
    List<int> mapped = input.map(_square).toList();
    List<int> pmapped = await pmap(input, _square, parallel: 2).toList();
    expect(pmapped, equals(mapped));
  });
}
