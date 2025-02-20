import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; // for Float32List
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart'; // if needed for WER, etc.

class TranscriptionBenchmarkState {
  final bool isTranscribing;
  final String currentFile;
  final double progress; // 0..1
  final Map<String, Map<String, dynamic>> results;
  final List<String> testFiles;

  const TranscriptionBenchmarkState({
    this.isTranscribing = false,
    this.currentFile = '',
    this.progress = 0.0,
    this.results = const {},
    this.testFiles = const [],
  });

  TranscriptionBenchmarkState copyWith({
    bool? isTranscribing,
    String? currentFile,
    double? progress,
    Map<String, Map<String, dynamic>>? results,
    List<String>? testFiles,
  }) {
    return TranscriptionBenchmarkState(
      isTranscribing: isTranscribing ?? this.isTranscribing,
      currentFile: currentFile ?? this.currentFile,
      progress: progress ?? this.progress,
      results: results ?? this.results,
      testFiles: testFiles ?? this.testFiles,
    );
  }
}

class TranscriptionBenchmarkNotifier
    extends Notifier<TranscriptionBenchmarkState> {
  @override
  TranscriptionBenchmarkState build() {
    return const TranscriptionBenchmarkState();
  }

  // --------------------------------------------------------------------------
  // Load test .wav files from assets
  // --------------------------------------------------------------------------
  Future<void> loadTestFiles() async {
    final curatedDir =
        Directory(p.join(Directory.current.path, 'assets', 'curated'));
    final testPaths =
        curatedDir.listSync(recursive: true).map((e) => e.path).toList();
    final wavs = testPaths.where((p) => p.endsWith('.wav')).toList();

    state = state.copyWith(testFiles: wavs);
  }

  // --------------------------------------------------------------------------
  // Main method: runTranscriptionBenchmark
  // --------------------------------------------------------------------------

  Future<void> runTranscriptionBenchmark({
    required List<OfflineRecognizerConfig> offlineConfigs,
  }) async {
    // Clear old results, mark isTranscribing
    state = state.copyWith(
      isTranscribing: true,
      results: {},
      progress: 0.0,
    );

    final newResults = <String, Map<String, dynamic>>{};
    final totalFiles = state.testFiles.length;

    try {
      // 1) For each offline config
      for (final offlineCfg in offlineConfigs) {
        final modelName = offlineCfg.modelName;
        newResults.putIfAbsent(
            modelName,
            () => {
                  'type': 'offline',
                  'files': <String, Map<String, dynamic>>{},
                });
        final fileMap = newResults[modelName]!['files']
            as Map<String, Map<String, dynamic>>;

        // Initialize model once per config
        final offline = OfflineRecognizer(offlineCfg);

        // Then process each file with this model
        for (int i = 0; i < totalFiles; i++) {
          final wavPath = state.testFiles[i];
          final baseName = p.basename(wavPath);
          final newProgress = i / totalFiles;

          // Update state for UI
          state = state.copyWith(
            currentFile: baseName,
            progress: newProgress,
          );

          final result = await _transcribeFileOffline(
            wavPath: wavPath,
            offlineRecognizer: offline, // Pass the initialized recognizer
          );
          fileMap[wavPath] = result;

          state = state.copyWith(results: newResults);
        }

        // Free the recognizer after processing all files with it
        offline.free();
      }

      final outputPath =
          Directory(p.join(Directory.current.path, 'assets', 'derived'));
      if (await outputPath.exists()) {
        await outputPath.delete(recursive: true);
      }
      await outputPath.create(recursive: true);

      // Optionally create a final CSV/JSON/MD
      final reporter = BenchmarkReportGenerator(
        results: newResults,
        outputDir: outputPath.path,
      );
      await reporter.generateReports();
    } catch (e, st) {
      print('TranscriptionBenchmark error: $e\n$st');
    } finally {
      state = state.copyWith(
        isTranscribing: false,
        currentFile: '',
        progress: 1.0,
      );
    }
  }

  Future<Map<String, dynamic>> _transcribeFileOffline({
    required String wavPath,
    required OfflineRecognizer
        offlineRecognizer, // Changed to take initialized recognizer
  }) async {
    final reference = await _loadSrtTranscript(wavPath);
    final startTime = DateTime.now();

    // Create a stream from the existing recognizer
    final stream = offlineRecognizer.createStream();

    // Convert the wave data to Float32List
    final waveData = await rootBundle.load(wavPath);
    final allBytes = waveData.buffer.asUint8List();

    Uint8List pcmBytes;
    if (_hasRiffHeader(allBytes)) {
      pcmBytes = allBytes.sublist(44);
    } else {
      pcmBytes = allBytes;
    }

    final float32Data = _toFloat32List(pcmBytes);

    // Accept entire waveform
    stream.acceptWaveform(samples: float32Data, sampleRate: 16000);

    // Decode
    offlineRecognizer.decode(stream);

    // Get the final recognized text
    final result = offlineRecognizer.getResult(stream);
    final recognizedText = result.text;

    final durationMs = DateTime.now().difference(startTime).inMilliseconds;

    // Compute RTF
    final audioMs = _estimateAudioMs(pcmBytes.length);
    final rtf = (audioMs == 0) ? 0.0 : durationMs / audioMs;

    // free only the stream, not the recognizer
    stream.free();

    return {
      'text': recognizedText.trim(),
      'reference': reference,
      'duration_ms': durationMs,
      'real_time_factor': rtf,
    };
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------
  bool _hasRiffHeader(Uint8List bytes) {
    // Enough length for standard header, and starts with "RIFF"
    if (bytes.length < 44) return false;
    return (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46);
  }

  /// Convert raw 16-bit PCM bytes to Float32List in range [-1.0, 1.0]
  Float32List _toFloat32List(Uint8List pcmBytes) {
    // For 16-bit little endian, we read 2 bytes per sample
    // e.g., short int in C. Then scale by (1.0 / 32768.0)
    final numSamples = pcmBytes.length ~/ 2;
    final floatData = Float32List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final low = pcmBytes[2 * i];
      final high = pcmBytes[2 * i + 1];
      // Combine
      final sample = (high << 8) | (low & 0xff);
      // If sign bit set, convert to negative
      int signedVal = (sample & 0x8000) != 0 ? sample | ~0xffff : sample;
      floatData[i] = signedVal / 32768.0;
    }

    return floatData;
  }

  /// Estimate audio length in ms from # of (16-bit) bytes
  int _estimateAudioMs(int numBytes) {
    // sampleCount = numBytes / 2
    // audioMs = (sampleCount * 1000) / 16000
    final sampleCount = numBytes ~/ 2;
    return (sampleCount * 1000) ~/ 16000;
  }

  Future<String> _loadSrtTranscript(String wavPath) async {
    final srtPath = wavPath.replaceAll('.wav', '.srt');
    try {
      final content = await rootBundle.loadString(srtPath);
      return _stripSrt(content);
    } catch (_) {
      return '';
    }
  }

  String _stripSrt(String text) {
    final lines = text.split('\n');
    final sb = StringBuffer();
    for (final l in lines) {
      final trimmed = l.trim();
      // skip empty
      if (trimmed.isEmpty) continue;
      // skip numeric lines
      if (RegExp(r'^\d+$').hasMatch(trimmed)) continue;
      // skip lines with --> timestamps
      if (trimmed.contains('-->')) continue;
      sb.write('$trimmed ');
    }
    return sb.toString().trim();
  }
}

// The provider
final transcriptionBenchmarkNotifierProvider = NotifierProvider<
    TranscriptionBenchmarkNotifier, TranscriptionBenchmarkState>(
  TranscriptionBenchmarkNotifier.new,
);
