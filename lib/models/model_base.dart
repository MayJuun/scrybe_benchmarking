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


  void dispose();
}
