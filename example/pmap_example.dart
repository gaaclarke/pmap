import 'package:pmap/pmap.dart';

int mapper(int x) => x * x;

void main() async {
  final foo = Iterable<int>.generate(100);
  final results = foo.mapParallel(mapper, parallel: 2);
  await results.forEach(print);
}
