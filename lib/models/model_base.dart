import 'dart:typed_data';

abstract class ModelBase {
  ModelBase({required this.modelName});

  final String modelName;

  // Audio processing
  String processAudio(Uint8List audioData, int sampleRate);

  void dispose();
}
