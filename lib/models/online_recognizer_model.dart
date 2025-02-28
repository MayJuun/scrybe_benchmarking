import 'dart:typed_data';

import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

class OnlineRecognizerModel extends OnlineModel {
  final OnlineRecognizer recognizer;
  OnlineStream? _stream;

  OnlineRecognizerModel({required OnlineRecognizerConfig config})
      : recognizer = OnlineRecognizer(config),
        super(
            modelName:
                (config.model.tokens.split('/')..removeLast()).removeLast());

  @override
  String processAudio(Uint8List audioData, int sampleRate) {
    // Create a stream if we don't have one
    _stream ??= recognizer.createStream();

    // Convert audio data to samples
    final samples = convertBytesToFloat32(audioData);

    // Process the audio
    _stream!.acceptWaveform(samples: samples, sampleRate: sampleRate);

    // Decode while there's data to process
    while (recognizer.isReady(_stream!)) {
      recognizer.decode(_stream!);
    }

    // Get the result text
    final result = recognizer.getResult(_stream!);

    return result.text;
  }

  @override
  void finalizeDecoding() {
    if (_stream != null) {
      // Add more silence to flush any buffered audio (increase from 0.1s to 1s)
      final silenceBuffer = Float32List(16000); // 1 second at 16kHz
      _stream!.acceptWaveform(samples: silenceBuffer, sampleRate: 16000);

      // Force all decoding of buffered audio
      while (recognizer.isReady(_stream!)) {
        recognizer.decode(_stream!);
      }

      // Get any final results after adding silence
      // We don't reset here to ensure we capture everything
    }
  }

  // Add a method to get final results
  String getFinalResults() {
    if (_stream == null) return "";
    return recognizer.getResult(_stream!).text;
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
