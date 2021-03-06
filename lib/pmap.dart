import 'dart:async';
import 'dart:isolate';

typedef Mapper<T, U> = U Function(T);

/// This [_Processor] manages the [sendPort] and the [mapper] in the spawned isolates
class _Processor<T, U> {
  final SendPort /*!*/ sendPort;
  final U Function(T input) /*!*/ mapper;

  void process(dynamic input) async {
    MapEntry<int, T> enumeratedInput = input;
    sendPort.send(MapEntry(enumeratedInput.key, mapper(enumeratedInput.value)));
  }

  _Processor(this.mapper, this.sendPort);
}

void _process(_Processor processor) async {
  final receivePort = ReceivePort();
  processor.sendPort.send(receivePort.sendPort);
  await for (dynamic input in receivePort) {
    processor.process(input);
  }
}

class _ProcessorIsolate<T, U> {
  final Isolate isolate;
  final ReceivePort receivePort;
  final completer = Completer();
  SendPort /*?*/ sendPort;

  _ProcessorIsolate({
    this.isolate,
    this.receivePort,
  });

  static Future<_ProcessorIsolate<T, U>> spawn<T, U>(
    Mapper<T, U> mapper,
    ReceivePort receivePort,
  ) async {
    final isolate =
        Isolate.spawn(_process, _Processor(mapper, receivePort.sendPort));
    return _ProcessorIsolate(
      isolate: await isolate,
      receivePort: receivePort,
    );
  }
}

/// Operates like [Iterable.map] except performs the function [mapper] on a
/// background isolate. [parallel] denotes how many background isolates to use.
///
/// This is only useful if the computation time of [mapper] out paces the
/// overhead in coordination.
///
/// If the order of the returned Stream elements is not important, the [inOrder]
/// can be used.
///
/// Note: [mapper] must be a static method or a top-level function.
Stream<U> pmap<T, U>(
  Iterable<T> iterable,
  U Function(T input) mapper, {
  int parallel = 1,
  bool inOrder = true,
}) {
  assert(
    parallel > 0,
    'There need to be at least one worker, but got $parallel',
  );

  final controller = StreamController<U>();
  final it = iterable.iterator;
  var nextPublishIndex = 0;
  var iterableIndex = 0;
  final buffer = <int, U>{};
  final isolates = List.generate(
    parallel,
    (_) async {
      final receivePort = ReceivePort();
      final isolate = await _ProcessorIsolate.spawn(mapper, receivePort);
      isolate.receivePort.listen(
        (dynamic result) {
          if (isolate.sendPort == null) {
            isolate.sendPort = result;
          } else {
            final enumeratedResult = result as MapEntry<int, U>;
            if (inOrder) {
              if (enumeratedResult.key == nextPublishIndex) {
                controller.add(enumeratedResult.value);
                nextPublishIndex++;
                var value = buffer[nextPublishIndex];
                while (value != null) {
                  controller.add(value);
                  buffer.remove(nextPublishIndex);
                  nextPublishIndex++;
                  value = buffer[nextPublishIndex];
                }
              } else {
                buffer[enumeratedResult.key] = enumeratedResult.value;
              }
            } else {
              controller.add(enumeratedResult.value);
            }
          }
          if (it.moveNext()) {
            isolate.sendPort.send(MapEntry(iterableIndex++, it.current));
          } else {
            isolate.completer.complete();
          }
        },
      );
      return isolate;
    },
    growable: false,
  );

  Future.wait(isolates).then((isolatesSync) =>
      Future.wait(isolatesSync.map((isolate) => isolate.completer.future)).then(
        (_) {
          for (final isolate in isolatesSync) {
            isolate.receivePort.close();
            isolate.isolate.kill();
          }
          controller.close();
        },
      ));

  return controller.stream;
}

extension PMapIterable<T> on Iterable<T> {
  /// Operates like [Iterable.map] except performs the function [mapper] on a
  /// background isolate. [parallel] denotes how many background isolates to use.
  ///
  /// This is only useful if the computation time of [mapper] out paces the
  /// overhead in coordination.
  ///
  /// If the order of the returned Stream elements is not important, the [inOrder]
  /// can be used.
  ///
  /// Note: [mapper] must be a static method or a top-level function.
  Stream<U> mapParallel<U>(
    Mapper<T, U> mapper, {
    int parallel,
    bool inOrder,
  }) =>
      pmap(
        this,
        mapper,
        parallel: parallel ?? 1,
        inOrder: inOrder ?? true,
      );
}
