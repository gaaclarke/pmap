import 'dart:isolate';

void _process(SendPort sendPort) async {
  var receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);
  dynamic Function(dynamic input) mapper;
  await for (dynamic input in receivePort) {
    if (mapper == null) {
      mapper = input;
    } else {
      sendPort.send(mapper(input));
    }
  }
}

Stream<dynamic> pmap(List list, dynamic Function(dynamic input) mapper, {int parallel = 1}) async* {
  ReceivePort receivePort = new ReceivePort();
  Isolate isolate = await Isolate.spawn(_process, receivePort.sendPort);
  SendPort sendPort;
  int count = 0;
  await for (dynamic result in receivePort) {
    if (sendPort == null) {
      sendPort = result;
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

dynamic mapper(dynamic x) => x * x;

void main() async {
  List<int> foo = [1, 2, 3, 4];
  Stream<dynamic> results = pmap(foo, mapper);
  await for (int value in results) {
    print(value);
  }
}