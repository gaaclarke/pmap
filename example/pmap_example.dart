import 'package:pmap/pmap.dart';

int square(int x) => x * x;

void main() async {
  final foo = Iterable<int>.generate(100);
  final results = foo.mapParallel(square, parallel: 2);
  await results.forEach(print);
}
