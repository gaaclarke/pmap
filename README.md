# pmap

## Description

A parallel implementation of `Iterable.map`.  This is a convenient function to
help parallelize expensive operations.

## Example

```dart
import 'package:pmap/pmap.dart';

int square(int x) => x * x;

void main() async {
  List<int> list = [1, 2, 3, 4, 5];
  Stream<int> results = pmap(list, square);
  await for (int value in results) {
    print(value);
  }
}
```
