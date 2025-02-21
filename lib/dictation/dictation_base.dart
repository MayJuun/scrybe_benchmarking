import 'dart:async';
import 'dart:typed_data';

abstract class DictationBase {
  bool isRecording = false;
  final int sampleRate;
  final Duration silenceDuration;
  final _recognizedTextController = StreamController<String>.broadcast();
  Stream<String> get recognizedTextStream => _recognizedTextController.stream;

  DictationBase({
    this.sampleRate = 16000,
    int silenceDurationMillis = 500,
  }) : silenceDuration = Duration(milliseconds: silenceDurationMillis);

  void onAudioData(Uint8List data);

  void onRecordingStart() {}
  void onRecordingStop() {}

  Float32List convertBytesToFloat32(Uint8List bytes, [Endian endian = Endian.little]) {
    final length = bytes.length ~/ 2;
    final floats = Float32List(length);
    final data = ByteData.view(bytes.buffer);
    for (var i = 0; i < bytes.length; i += 2) {
      final sample = data.getInt16(i, endian);
      floats[i ~/ 2] = sample / 32768.0;
    }
    return floats;
  }

  void emitRecognizedText(String text) {
    _recognizedTextController.add(text);
  }

  Future<void> dispose() async {
    await _recognizedTextController.close();
  }
}
