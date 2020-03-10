import 'dart:async';
import 'dart:isolate';

class _Enumerated<T> {
  final int index;
  final T value;
  _Enumerated({this.index, this.value});
}

class _Processor<T, U> {
  SendPort sendPort;
  U Function(T input) mapper;
  int sendCount = 0;

  void process(dynamic input) async {
    _Enumerated<T> enumeratedInput = input;
    sendPort.send(_Enumerated(index:enumeratedInput.index, value:mapper(enumeratedInput.value)));
  }
}

void _process(SendPort sendPort) async {
  var receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);
  _Processor processor;
  await for (dynamic input in receivePort) {
    if (processor == null) {
      processor = input;
      processor.sendPort = sendPort;
    } else {
      processor.process(input);
    }
  }
}

class _ProcessorIsolate<T, U> {
  ReceivePort receivePort = new ReceivePort();
  Isolate isolate;
  SendPort sendPort;
  _Processor<T, U> processor = _Processor<T, U>();
  Completer completer = Completer();
  Future<void> spawn() async {
    isolate = await Isolate.spawn(_process, receivePort.sendPort);
  }
}

/// Operates like `Iterable.map` except performs the function `mapper` on a
/// background isolate.  `parallel` denotes how many background isolates to use.
///
/// This is only useful if the computation time of `mapper` out paces the
/// overhead in coordination.
///
/// Note: `mapper` must be a static method or a top-level function.
Stream<U> pmap<T, U>(Iterable<T> list, U Function(T input) mapper,
    {int parallel = 1}) {
  List<_ProcessorIsolate<T, U>> isolates = [];
  StreamController<U> controller = StreamController<U>();
  Iterator<T> it = list.iterator;
  int sendCount = 0;
  int receiveCount = 0;
  List<_Enumerated<U>> buffer = [];
  for (int i = 0; i < parallel; ++i) {
    _ProcessorIsolate<T, U> isolate = _ProcessorIsolate<T, U>();
    isolate.processor.mapper = mapper;
    isolates.add(isolate);
    isolate.spawn().then((x) async {
      isolate.receivePort.listen((dynamic result) {
        if (isolate.sendPort == null) {
          isolate.sendPort = result;
          isolate.sendPort.send(isolate.processor);
          if (it.moveNext()) {
            isolate.sendPort.send(_Enumerated(index:sendCount++, value:it.current));
          } else {
            isolate.completer.complete();
          }
        } else {
          _Enumerated<U> enumeratedResult = result;
          if (enumeratedResult.index == receiveCount) {
            controller.add(enumeratedResult.value);
            receiveCount++;
          } else {
            buffer.add(enumeratedResult);
            int index = buffer.indexWhere((x) => x.index == receiveCount);
            while (index >= 0) {
              controller.add(buffer.elementAt(index).value);
              buffer.removeAt(index);
              receiveCount++;
              index = buffer.indexWhere((x) => x.index == receiveCount);
            }
          }
          if (it.moveNext()) {
            isolate.sendPort.send(_Enumerated(index:sendCount++, value:it.current));
          } else {
            isolate.completer.complete();
          }
        }
      });
    });
  }

  Future.wait(isolates.map((x) => x.completer.future)).then((x) {
    for (_ProcessorIsolate isolate in isolates) {
      isolate.receivePort.close();
      isolate.isolate.kill();
    }
    controller.close();
  });

  return controller.stream;
}
