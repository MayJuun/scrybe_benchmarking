import 'dart:typed_data';

abstract class AsrModel {
  AsrModel({required this.modelName});

  final String modelName;

  void dispose();
}

abstract class OnlineModel extends AsrModel {
  OnlineModel({required super.modelName});

  String processAudio(Uint8List audioData, int sampleRate);

  void finalizeDecoding();

  @override
  void dispose();
}
