import 'dart:typed_data';

abstract class AsrModel {
  AsrModel({required this.modelName});

  final String modelName;

  String processAudio(Uint8List audioData, int sampleRate);

  void dispose();

  Float32List convertBytesToFloat32(Uint8List bytes, [endian = Endian.little]) {
    final values = Float32List(bytes.length ~/ 2);

    final data = ByteData.view(bytes.buffer);

    for (var i = 0; i < bytes.length; i += 2) {
      int short = data.getInt16(i, endian);
      values[i ~/ 2] = short / 32678.0;
    }

    return values;
  }
}

abstract class OnlineModel extends AsrModel {
  OnlineModel({required super.modelName});

  @override
  String processAudio(Uint8List audioData, int sampleRate);

  void finalizeDecoding();

  @override
  void dispose();
}
