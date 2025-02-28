import 'dart:typed_data';

import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

class KeywordSpotterModel extends OnlineModel {
  final KeywordSpotter recognizer;
  OnlineStream? _stream;

  KeywordSpotterModel({required KeywordSpotterConfig config})
      : recognizer = KeywordSpotter(config),
        super(
            modelName:
                (config.model.tokens.split('/')..removeLast()).removeLast());

  @override
  String processAudio(Uint8List audioData, int sampleRate) {
    _stream ??= recognizer.createStream();
    final samples = convertBytesToFloat32(audioData);
    _stream!.acceptWaveform(samples: samples, sampleRate: sampleRate);

    // Loop until there's no more immediate data to decode
    while (recognizer.isReady(_stream!)) {
      recognizer.decode(_stream!);
      final result = recognizer.getResult(_stream!);
      if (result.keyword != '') {
        // Keyword detected: reset stream and return the keyword.
        recognizer.reset(_stream!);
        return '${DateTime.now()} ${result.keyword}';
      }
    }

    // Return empty string if no keyword was detected.
    return '';
  }

  @override
  // In the KeywordSpotter class
  void finalizeDecoding() {
    // For some models, there's a specific API for this
    if (_stream != null) {
      // Add small silence to flush any buffered audio
      final silenceBuffer = Float32List(1600); // 0.1 second at 16kHz
      _stream!.acceptWaveform(samples: silenceBuffer, sampleRate: 16000);

      // Force all decoding of buffered audio
      while (recognizer.isReady(_stream!)) {
        recognizer.decode(_stream!);
      }
    }
  }

  void resetStream() {
    if (_stream != null) {
      _stream!.free();
      _stream = recognizer.createStream();
    }
  }

  @override
  void dispose() {
    _stream?.free();
    recognizer.free();
  }
}
