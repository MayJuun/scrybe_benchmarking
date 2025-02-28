import 'dart:convert';
import 'dart:typed_data';

import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

class OfflineRecognizerModel extends AsrModel {
  final OfflineRecognizer recognizer;
  final int cacheSize;

  OfflineRecognizerModel(
      {required OfflineRecognizerConfig config, this.cacheSize = 10})
      : recognizer = OfflineRecognizer(config),
        super(
            modelName:
                (config.model.tokens.split('/')..removeLast()).removeLast());

  /// Returns a pretty printed JSON string.
  final JsonEncoder jsonEncoder = JsonEncoder.withIndent('    ');

  /// Returns a pretty printed JSON string.
  String prettyPrintJson(Map<String, dynamic> map) => jsonEncoder.convert(map);

  @override
  String processAudio(Uint8List audioData, int sampleRate) {
    // print('Processing audio data ${audioData.length} bytes');
    final stream = recognizer.createStream();

    // Convert audio data to samples
    final samples = convertBytesToFloat32(audioData);

    // Process waveform with recognizer stream
    stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
    recognizer.decode(stream);

    // Get the result from the recognizer
    final result = recognizer.getResult(stream);
    // print(prettyPrintJson(result.toJson()));

    // Clean up stream after use
    stream.free();

    return result.text;
  }

  @override
  void dispose() {
    recognizer.free();
  }
}
