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

Stream<U> pmap<T, U>(List<T> list, U Function(T input) mapper,
    {int parallel = 1}) async* {
  ReceivePort receivePort = new ReceivePort();
  Isolate isolate = await Isolate.spawn(_process, receivePort.sendPort);
  SendPort sendPort;
  int count = 0;
  _Processor<T, U> processor = _Processor<T, U>();
  await for (dynamic result in receivePort) {
    if (sendPort == null) {
      sendPort = result;
      sendPort.send(processor);
      sendPort.send(mapper);
      for (dynamic item in list) {
        sendPort.send(item);
        count++;
      }
    } else {
      yield result;
      count--;
      if (count <= 0) {
        break;
      }
    }
  }
  isolate.kill();
}

int mapper(int x) => x * x;

void main() async {
  List<int> foo = [1, 2, 3, 4];
  Stream<int> results = pmap(foo, mapper);
  await for (int value in results) {
    print(value);
  }
}
