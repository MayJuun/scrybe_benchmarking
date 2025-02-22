import 'dart:typed_data';

import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

abstract class ModelBase {
  ModelBase({required this.modelName});

  final String modelName;

  // Audio processing
  TranscriptionResult processAudio(Uint8List audioData, int sampleRate);

  void dispose();
}
