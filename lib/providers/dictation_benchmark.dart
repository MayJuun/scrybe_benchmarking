import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

/// State for dictation-based (streaming) benchmark
class DictationBenchmarkState {
  final bool isBenchmarking;
  final String currentModel;
  final String currentFile;
  final double progress; // 0..1
  final String recognizedText;

  /// We now store final metrics in a list.
  final List<BenchmarkMetrics> metricsList;

  /// All .wav test files discovered.
  final List<String> testFiles;

  const DictationBenchmarkState({
    this.isBenchmarking = false,
    this.currentModel = '',
    this.currentFile = '',
    this.progress = 0.0,
    this.recognizedText = '',
    this.metricsList = const [],
    this.testFiles = const [],
  });

  DictationBenchmarkState copyWith({
    bool? isBenchmarking,
    String? currentModel,
    String? currentFile,
    double? progress,
    String? recognizedText,
    List<BenchmarkMetrics>? metricsList,
    List<String>? testFiles,
  }) {
    return DictationBenchmarkState(
      isBenchmarking: isBenchmarking ?? this.isBenchmarking,
      currentModel: currentModel ?? this.currentModel,
      currentFile: currentFile ?? this.currentFile,
      progress: progress ?? this.progress,
      recognizedText: recognizedText ?? this.recognizedText,
      metricsList: metricsList ?? this.metricsList,
      testFiles: testFiles ?? this.testFiles,
    );
  }
}

class DictationBenchmarkNotifier extends Notifier<DictationBenchmarkState> {
  @override
  DictationBenchmarkState build() {
    return const DictationBenchmarkState();
  }

  // --------------------------------------------------------------------------
  // 1) Load .wav test files from assets
  // --------------------------------------------------------------------------
  Future<void> loadTestFiles() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    final testFilePaths = manifestMap.keys
        .where((key) => key.startsWith('assets/dictation_test/test_files/'))
        .toList();

    final wavFiles = testFilePaths.where((p) => p.endsWith('.wav')).toList();
    state = state.copyWith(testFiles: wavFiles);
  }

  // --------------------------------------------------------------------------
  // 2) Main run method (benchmark each model on each WAV file)
  // --------------------------------------------------------------------------
  Future<void> runBenchmark({
    required List<OnlineRecognizerConfig> onlineConfigs,
    required List<OfflineRecognizerConfig> offlineConfigs,
  }) async {
    // Reset state
    state = state.copyWith(
      isBenchmarking: true,
      metricsList: [],
      recognizedText: '',
      progress: 0.0,
    );

    final allMetrics = <BenchmarkMetrics>[];
    final totalFiles = state.testFiles.length;

    if (totalFiles == 0) {
      print('No .wav files found in assets/dictation_test/test_files/');
      state = state.copyWith(isBenchmarking: false);
      return;
    }

    try {
      // For each WAV file...
      for (int i = 0; i < totalFiles; i++) {
        final wavPath = state.testFiles[i];
        final fileName = p.basename(wavPath);

        final fileProgress = i / totalFiles;
        state = state.copyWith(
          currentFile: fileName,
          progress: fileProgress,
          recognizedText: '',
        );

        // For each Online Config
        for (final config in onlineConfigs) {
          final metrics = await _runSingleWav(
            wavPath: wavPath,
            config: config,
            isOnline: true,
          );
          allMetrics.add(metrics);

          // Update UI with final recognized text (for that run)
          state = state.copyWith(
            recognizedText: metrics.transcription,
            currentModel: config.modelName,
          );
        }

        // For each Offline Config
        for (final config in offlineConfigs) {
          final metrics = await _runSingleWav(
            wavPath: wavPath,
            config: config,
            isOnline: false,
          );
          allMetrics.add(metrics);

          // Update UI with final recognized text
          state = state.copyWith(
            recognizedText: metrics.transcription,
            currentModel: config.modelName,
          );
        }
      }

      // Done all files
      state = state.copyWith(progress: 1.0, metricsList: allMetrics);

      // Generate final reports
      final outputPath =
          Directory(p.join(Directory.current.path, 'assets', 'derived'));
      if (await outputPath.exists()) {
        await outputPath.delete(recursive: true);
      }
      await outputPath.create(recursive: true);

      final reporter = BenchmarkReportGenerator(
        metricsList: allMetrics,  // pass the entire list
        outputDir: outputPath.path,
      );
      await reporter.generateReports();
    } catch (e, st) {
      print('DictationBenchmark error: $e\n$st');
    } finally {
      // Mark done
      state = state.copyWith(
        isBenchmarking: false,
        currentModel: '',
        currentFile: '',
        progress: 1.0,
      );
    }
  }

  // --------------------------------------------------------------------------
  // 3) Helper to run a single .wav => chunk feed => return BenchmarkMetrics
  // --------------------------------------------------------------------------
  Future<BenchmarkMetrics> _runSingleWav({
    required String wavPath,
    required dynamic config,
    required bool isOnline,
  }) async {
    // 1) Instantiate dictation
    final startTime = DateTime.now();
    String modelName;
    String modelType;
    DictationBase dictation;

    if (isOnline) {
      final c = config as OnlineRecognizerConfig;
      final onlineRecognizer = OnlineRecognizer(c);
      modelName = c.modelName;
      modelType = 'online';
      dictation = OnlineDictation(onlineRecognizer: onlineRecognizer);
    } else {
      final c = config as OfflineRecognizerConfig;
      final offlineRecognizer = OfflineRecognizer(c);
      modelName = c.modelName;
      modelType = 'offline';
      dictation = OfflineDictation(offlineRecognizer: offlineRecognizer);
    }

    await dictation.init();

    // 2) Load reference transcript
    final reference = await _loadReference(wavPath);

    // 3) Collect recognized text
    String recognized = '';
    final sub = dictation.recognizedTextStream.listen((text) {
      if (dictation is OnlineDictation) {
        // For partial
        final lines = recognized.split('\n');
        if (lines.isNotEmpty) lines.removeLast();
        lines.add(text);
        recognized = lines.join('\n');
      } else {
        recognized = '$recognized\n$text';
      }
    });

    // 4) Simulate mic input
    final wavData = await rootBundle.load(wavPath);
    final rawBytes = wavData.buffer.asUint8List();

    Uint8List pcmBytes;
    if (_hasRiffHeader(rawBytes)) {
      pcmBytes = rawBytes.sublist(44);
    } else {
      pcmBytes = rawBytes;
    }

    await dictation.startRecording();

    const chunkMs = 30;
    final bytesPerMs = (16000 * 2) ~/ 1000; // 32 bytes per ms for 16k mono 16-bit
    final chunkSize = bytesPerMs * chunkMs; // 960

    int offset = 0;
    while (offset < pcmBytes.length) {
      final end = (offset + chunkSize).clamp(0, pcmBytes.length);
      final chunk = pcmBytes.sublist(offset, end);
      offset = end;

      dictation.onAudioData(chunk);

      // Wait to mimic real-time
      await Future.delayed(const Duration(milliseconds: chunkMs));
    }

    // Stop, small flush delay
    await dictation.stopRecording();
    await Future.delayed(const Duration(milliseconds: 500));

    final endTime = DateTime.now();
    final durationMs = endTime.difference(startTime).inMilliseconds;

    // Dispose resources
    await dictation.dispose();
    await sub.cancel();

    // 5) Build final metrics
    final audioMs = _estimateAudioMs(pcmBytes.length);

    final metrics = BenchmarkMetrics.create(
      modelName: modelName,
      modelType: modelType,
      wavFile: wavPath,
      transcription: recognized.trim(),
      reference: reference,
      processingDuration: Duration(milliseconds: durationMs),
      audioLengthMs: audioMs,
    );

    return metrics;
  }

  bool _hasRiffHeader(Uint8List bytes) {
    if (bytes.length < 44) return false;
    return (bytes[0] == 0x52 && // R
        bytes[1] == 0x49 &&    // I
        bytes[2] == 0x46 &&    // F
        bytes[3] == 0x46);     // F
  }

  int _estimateAudioMs(int numBytes) {
    // 16-bit => 2 bytes/sample, 16k => 16000 samples/sec
    // sampleCount = numBytes / 2
    // audioMs = (sampleCount * 1000) / 16000
    final sampleCount = numBytes ~/ 2;
    return (sampleCount * 1000) ~/ 16000;
  }

  Future<String> _loadReference(String wavPath) async {
    final srtFile = wavPath.replaceAll('.wav', '.srt');
    try {
      final content = await rootBundle.loadString(srtFile);
      return _stripSrt(content);
    } catch (_) {
      return '';
    }
  }

  String _stripSrt(String text) {
    final lines = text.split('\n');
    final sb = StringBuffer();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (RegExp(r'^\d+$').hasMatch(trimmed)) continue;
      if (trimmed.contains('-->')) continue;
      sb.write('$trimmed ');
    }
    return sb.toString().trim();
  }
}

// Riverpod provider
final dictationBenchmarkNotifierProvider =
    NotifierProvider<DictationBenchmarkNotifier, DictationBenchmarkState>(
  DictationBenchmarkNotifier.new,
);
