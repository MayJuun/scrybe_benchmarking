import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class TranscriptionBenchmarkState {
  final bool isTranscribing;
  final String currentFile;
  final double progress; // 0..1

  /// Now we store final metrics in a list, instead of a nested map.
  final List<BenchmarkMetrics> metricsList;

  final List<String> testFiles;

  const TranscriptionBenchmarkState({
    this.isTranscribing = false,
    this.currentFile = '',
    this.progress = 0.0,
    this.metricsList = const [],
    this.testFiles = const [],
  });

  TranscriptionBenchmarkState copyWith({
    bool? isTranscribing,
    String? currentFile,
    double? progress,
    List<BenchmarkMetrics>? metricsList,
    List<String>? testFiles,
  }) {
    return TranscriptionBenchmarkState(
      isTranscribing: isTranscribing ?? this.isTranscribing,
      currentFile: currentFile ?? this.currentFile,
      progress: progress ?? this.progress,
      metricsList: metricsList ?? this.metricsList,
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
  // (Here you load from 'assets/curated', but adjust as needed.)
  // --------------------------------------------------------------------------
  Future<void> loadTestFiles() async {
    final curatedDir =
        Directory(p.join(Directory.current.path, 'assets', 'curated'));
    if (!await curatedDir.exists()) {
      print('No curated dir found at: ${curatedDir.path}');
      return;
    }

    final testPaths =
        curatedDir.listSync(recursive: true).map((e) => e.path).toList();
    print('testPaths.length = ${testPaths.length}');
    final wavs = testPaths.where((p) => p.endsWith('.wav')).toList();
    print('wavs = ${wavs}');

    state = state.copyWith(testFiles: wavs);
  }

  // --------------------------------------------------------------------------
  // Main method: runTranscriptionBenchmark (offline)
  // --------------------------------------------------------------------------
  Future<void> runTranscriptionBenchmark({
    required List<OfflineRecognizerModel> offlineRecognizerModels,
  }) async {
    // Reset
    state = state.copyWith(
      isTranscribing: true,
      metricsList: [],
      progress: 0.0,
    );

    final allMetrics = <BenchmarkMetrics>[];
    final totalFiles = state.testFiles.length;
    print(state.testFiles);

    try {
      for (final model in offlineRecognizerModels) {
        final offlineRecognizer = model.recognizer;

        for (int i = 0; i < totalFiles; i++) {
          final wavPath = state.testFiles[i];
          final baseName = p.basename(wavPath);
          final progressVal = i / totalFiles;

          state = state.copyWith(
            currentFile: baseName,
            progress: progressVal,
          );

          // Transcribe
          final metrics = await _transcribeFileOffline(
            wavPath: wavPath,
            offlineRecognizer: offlineRecognizer,
            modelName: model.modelName,
          );
          allMetrics.add(metrics);

          // Update partial state
          state = state.copyWith(metricsList: List.from(allMetrics));
        }

        offlineRecognizer.free();
      }

      // Final
      state = state.copyWith(
        progress: 1.0,
        metricsList: allMetrics,
      );

      // Generate CSV/JSON/MD
      final outputPath =
          Directory(p.join(Directory.current.path, 'assets', 'derived'));
      if (await outputPath.exists()) {
        await outputPath.delete(recursive: true);
      }
      await outputPath.create(recursive: true);

      final reporter = BenchmarkReportGenerator(
        metricsList: allMetrics, // pass the entire list
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

  // --------------------------------------------------------------------------
  // Single-file offline transcription => returns 1 BenchmarkMetrics
  // --------------------------------------------------------------------------
  Future<BenchmarkMetrics> _transcribeFileOffline({
    required String wavPath,
    required OfflineRecognizer offlineRecognizer,
    required String modelName,
  }) async {
    final startTime = DateTime.now();

    // Create a stream from the existing recognizer
    final stream = offlineRecognizer.createStream();

    // Convert wave data to Float32List
    final wavData = await File(wavPath).readAsBytes();
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
    print('Recognized text for $wavPath: "$recognizedText"');

    final endTime = DateTime.now();
    final durationMs = endTime.difference(startTime).inMilliseconds;

    // RTF
    final audioMs = _estimateAudioMs(pcmBytes.length);

    // Load reference
    final reference = await _loadSrtTranscript(wavPath);

    // free the stream
    stream.free();

    // Build a BenchmarkMetrics object
    final metrics = BenchmarkMetrics.create(
      modelName: modelName,
      modelType: 'offline',
      wavFile: wavPath,
      transcription: recognizedText,
      reference: reference,
      processingDuration: Duration(milliseconds: durationMs),
      audioLengthMs: audioMs,
    );

    return metrics;
  }

  bool _hasRiffHeader(Uint8List bytes) {
    if (bytes.length < 44) return false;
    return (bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46); // F
  }

  Float32List _toFloat32List(Uint8List pcmBytes) {
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

  int _estimateAudioMs(int numBytes) {
    // 16-bit => 2 bytes per sample, 16 kHz => 16000 samples/sec
    final sampleCount = numBytes ~/ 2;
    return (sampleCount * 1000) ~/ 16000;
  }

  Future<String> _loadSrtTranscript(String wavPath) async {
    final srtPath = wavPath.replaceAll('.wav', '.srt');
    try {
      final content = await File(srtPath).readAsString();
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
      if (trimmed.isEmpty) continue;
      if (RegExp(r'^\d+$').hasMatch(trimmed)) continue;
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
