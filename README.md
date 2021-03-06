# pmap

## Description

A parallel implementation of `Iterable.map`.  This is a convenient function to
help parallelize expensive operations.

## Example

```dart
import 'package:pmap/pmap.dart';

int mapper(int x) => x * x;

void main() async {
  final foo = Iterable<int>.generate(100);
  final results = foo.mapParallel(mapper, parallel: 2);
  await results.forEach(print);
}
```
