import 'dart:async';
import 'dart:isolate';

class _Processor<T, U> {
  SendPort sendPort;
  U Function(T input) mapper;

  void process(dynamic input) async {
    if (mapper == null) {
      mapper = input;
    } else {
      sendPort.send(mapper(input));
    }
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

Stream<U> pmap<T, U>(Iterable<T> list, U Function(T input) mapper,
    {int parallel = 1}) {
  List<_ProcessorIsolate<T, U>> isolates = [];
  StreamController<U> controller = StreamController<U>();
  Iterator<T> it = list.iterator;
  for (int i = 0; i < parallel; ++i) {
    _ProcessorIsolate<T, U> isolate = _ProcessorIsolate<T, U>();
    isolates.add(isolate);
    isolate.spawn().then((x) async {
      isolate.receivePort.listen((dynamic result) {
        if (isolate.sendPort == null) {
          isolate.sendPort = result;
          isolate.sendPort.send(isolate.processor);
          isolate.sendPort.send(mapper);
          if (it.moveNext()) {
            isolate.sendPort.send(it.current);
          } else {
            isolate.completer.complete();
          }
        } else {
          controller.add(result);
          if (it.moveNext()) {
            isolate.sendPort.send(it.current);
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