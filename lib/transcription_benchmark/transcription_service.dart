// transcription_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

abstract class TranscriptionService {
  // Main transcription method - gets reference text from parameter
  static Future<BenchmarkMetrics> transcribeFile({
    required String audioFilePath,
    required OfflineRecognizer offlineRecognizer,
    required String modelName,
    required String referenceText, // Pass this from AudioTestFiles
  }) async {
    final startTime = DateTime.now();

    // Create a stream from the existing recognizer
    final stream = offlineRecognizer.createStream();

    // Convert wave data to Float32List
    final wavData = await File(audioFilePath).readAsBytes();
    final allBytes = wavData.buffer.asUint8List();

    Uint8List pcmBytes;
    if (_hasRiffHeader(allBytes)) {
      pcmBytes = allBytes.sublist(44);
    } else {
      pcmBytes = allBytes;
    }

    print('Transcription Benchmark pcmBytes length = ${pcmBytes.length}');

    final float32Data = _toFloat32List(pcmBytes);

    // Accept entire waveform
    stream.acceptWaveform(samples: float32Data, sampleRate: 16000);

    // Decode
    offlineRecognizer.decode(stream);

    // Get recognized text
    final result = offlineRecognizer.getResult(stream);
    final recognizedText = result.text.trim();
    print('Recognized text for $audioFilePath: "$recognizedText"');

    final endTime = DateTime.now();
    final durationMs = endTime.difference(startTime).inMilliseconds;

    // Calculate audio length
    final audioMs = _estimateAudioMs(pcmBytes.length);

    // free the stream
    stream.free();

    // Build a BenchmarkMetrics object using provided reference text
    final metrics = BenchmarkMetrics.create(
      modelName: modelName,
      modelType: 'offline',
      wavFile: audioFilePath,
      transcription: recognizedText,
      reference: referenceText,
      processingDuration: Duration(milliseconds: durationMs),
      audioLengthMs: audioMs,
    );

    return metrics;
  }

  // Audio processing helper methods remain here
  static bool _hasRiffHeader(Uint8List bytes) {
    if (bytes.length < 44) return false;
    return (bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46); // F
  }

  static Float32List _toFloat32List(Uint8List pcmBytes) {
    final numSamples = pcmBytes.length ~/ 2;
    final floatData = Float32List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final low = pcmBytes[2 * i];
      final high = pcmBytes[2 * i + 1];
      final sample = (high << 8) | (low & 0xff);

      // Sign-extend if necessary
      int signedVal =
          (sample & 0x8000) != 0 ? (sample | ~0xffff) : sample & 0xffff;

      floatData[i] = signedVal / 32768.0;
    }

    return floatData;
  }

  static int _estimateAudioMs(int numBytes) {
    // 16-bit => 2 bytes per sample, 16 kHz => 16000 samples/sec
    final sampleCount = numBytes ~/ 2;
    return (sampleCount * 1000) ~/ 16000;
  }
}
