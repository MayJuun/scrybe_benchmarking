import 'dart:typed_data';

abstract class ModelBase {
  ModelBase({required this.modelName});

  final String modelName;

  // Stream management
  bool createStream() {
    try {
      doCreateStream();
      return true;
    } catch (e) {
      print('Failed to create stream for $modelName: $e');
      return false;
    }
  }

  void doCreateStream();
  void onRecordingStop();

  // Audio processing
  String processAudio(Uint8List audioData, int sampleRate);

  // Utility function for both implementations
  Float32List convertBytesToFloat32(Uint8List bytes) {
    final Float32List float32List = Float32List(bytes.length ~/ 2);
    final ByteData byteData = ByteData.sublistView(bytes);

    for (var i = 0; i < float32List.length; i++) {
      float32List[i] = byteData.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return float32List;
  }

  void dispose();
}
