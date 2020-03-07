import 'package:pmap/pmap.dart';

int mapper(int x) => x * x;

Iterable<int> countTo(int x) sync* {
  for( int i = 0; i < x; ++i) {
    yield i;
  }
}

void main() async {
  Iterable<int> foo = countTo(100);
  Stream<int> results = pmap(foo, mapper, parallel: 2);
  await for (int value in results) {
    print(value);
  }
}
