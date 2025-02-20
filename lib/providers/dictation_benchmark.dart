import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// State for dictation-based (streaming) benchmark
class DictationBenchmarkState {
  final bool isBenchmarking;
  final String currentModel;
  final String currentFile;
  final double progress; // 0..1
  final String recognizedText;
  final Map<String, Map<String, dynamic>> results;
  final List<String> testFiles;

  const DictationBenchmarkState({
    this.isBenchmarking = false,
    this.currentModel = '',
    this.currentFile = '',
    this.progress = 0.0,
    this.recognizedText = '',
    this.results = const {},
    this.testFiles = const [],
  });

  DictationBenchmarkState copyWith({
    bool? isBenchmarking,
    String? currentModel,
    String? currentFile,
    double? progress,
    String? recognizedText,
    Map<String, Map<String, dynamic>>? results,
    List<String>? testFiles,
  }) {
    return DictationBenchmarkState(
      isBenchmarking: isBenchmarking ?? this.isBenchmarking,
      currentModel: currentModel ?? this.currentModel,
      currentFile: currentFile ?? this.currentFile,
      progress: progress ?? this.progress,
      recognizedText: recognizedText ?? this.recognizedText,
      results: results ?? this.results,
      testFiles: testFiles ?? this.testFiles,
    );
  }
}

class DictationBenchmarkNotifier extends Notifier<DictationBenchmarkState> {
  @override
  DictationBenchmarkState build() {
    return const DictationBenchmarkState();
  }

  // 1) Load .wav test files from assets
  Future<void> loadTestFiles() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    final testFilePaths = manifestMap.keys
        .where((key) => key.startsWith('assets/dictation_test/test_files/'))
        .toList();

    final wavFiles = testFilePaths.where((p) => p.endsWith('.wav')).toList();
    state = state.copyWith(testFiles: wavFiles);
  }

  // 2) Main run method
  Future<void> runBenchmark({
    required List<OnlineRecognizerConfig> onlineConfigs,
    required List<OfflineRecognizerConfig> offlineConfigs,
  }) async {
    state = state.copyWith(
      isBenchmarking: true,
      results: {},
      progress: 0.0,
      recognizedText: '',
    );

    final newResults = <String, Map<String, dynamic>>{};
    final totalFiles = state.testFiles.length;

    try {
      for (int i = 0; i < totalFiles; i++) {
        final wavPath = state.testFiles[i];
        final fileName = p.basename(wavPath);
        final fileProgress = i / totalFiles;

        // Update state for UI
        state = state.copyWith(currentFile: fileName, progress: fileProgress);

        // For each online config
        for (final config in onlineConfigs) {
          final modelName = config.modelName;
          newResults.putIfAbsent(
              modelName,
              () => {
                    'type': 'online',
                    'files': <String, Map<String, dynamic>>{},
                  });
          final fileMap = newResults[modelName]!['files']
              as Map<String, Map<String, dynamic>>;

          final resultMap = await _runSingleWav(
            wavPath: wavPath,
            config: config,
            isOnline: true,
          );
          fileMap[wavPath] = resultMap;
        }

        // For each offline config
        for (final config in offlineConfigs) {
          final modelName = config.modelName;
          newResults.putIfAbsent(
              modelName,
              () => {
                    'type': 'offline',
                    'files': <String, Map<String, dynamic>>{},
                  });
          final fileMap = newResults[modelName]!['files']
              as Map<String, Map<String, dynamic>>;

          final resultMap = await _runSingleWav(
            wavPath: wavPath,
            config: config,
            isOnline: false,
          );
          fileMap[wavPath] = resultMap;
        }

        // Store partial results
        state = state.copyWith(results: newResults);
      }

      final outputPath =
          Directory(p.join(Directory.current.path, 'assets', 'derived'));
      if (await outputPath.exists()) {
        await outputPath.delete(recursive: true);
      }
      await outputPath.create(recursive: true);

      // Optionally generate CSV/JSON
      final reporter = BenchmarkReportGenerator(
        results: newResults,
        outputDir: outputPath.path,
      );
      await reporter.generateReports();
    } catch (e, st) {
      print('DictationBenchmark error: $e\n$st');
    } finally {
      state = state.copyWith(
        isBenchmarking: false,
        currentModel: '',
        currentFile: '',
        progress: 1.0,
      );
    }
  }

  // 3) Helper to run a single .wav => chunk feed
  Future<Map<String, dynamic>> _runSingleWav({
    required String wavPath,
    required dynamic config,
    required bool isOnline,
  }) async {
    final dictation = isOnline
        ? OnlineDictation(onlineRecognizer: OnlineRecognizer(config))
        : OfflineDictation(offlineRecognizer: OfflineRecognizer(config));

    await dictation.init();

    final reference = await _loadReference(wavPath);

    // Collect recognized text
    String recognized = '';
    final sub = dictation.recognizedTextStream.listen((text) {
      if (isOnline) {
        final lines = recognized.split('\n');
        if (lines.isNotEmpty) lines.removeLast();
        lines.add(text);
        recognized = lines.join('\n');
      } else {
        recognized = '$recognized\n$text';
      }

      // Show partial in UI
      state = state.copyWith(recognizedText: recognized);
    });

    final start = DateTime.now();
    await _feedAudioInChunks(wavPath, dictation);
    final durationMs = DateTime.now().difference(start).inMilliseconds;

    await dictation.dispose();
    await sub.cancel();

    // RTF
    final audioData = await rootBundle.load(wavPath);
    final totalBytes = audioData.lengthInBytes;
    final rawBytes = (totalBytes > 44) ? (totalBytes - 44) : totalBytes;
    final samples = rawBytes ~/ 2; // 16-bit => 2 bytes
    final audioMs = (samples * 1000) ~/ 16000;
    final rtf = (audioMs == 0) ? 0.0 : durationMs / audioMs;

    return {
      'text': recognized.trim(),
      'reference': reference,
      'duration_ms': durationMs,
      'real_time_factor': rtf,
    };
  }

  Future<void> _feedAudioInChunks(
      String wavPath, DictationBase dictation) async {
    final wavData = await rootBundle.load(wavPath);
    final allBytes = wavData.buffer.asUint8List();

    // skip 44 if standard
    Uint8List pcm;
    if (allBytes.length >= 44 &&
        allBytes[0] == 0x52 &&
        allBytes[1] == 0x49 &&
        allBytes[2] == 0x46 &&
        allBytes[3] == 0x46) {
      pcm = allBytes.sublist(44);
    } else {
      pcm = allBytes;
    }

    await dictation.startRecording();

    const chunkMs = 30;
    final bytesPerMs = (16000 * 2) ~/ 1000;
    final chunkSize = bytesPerMs * chunkMs; // 960

    for (int i = 0; i < pcm.length; i += chunkSize) {
      final end = (i + chunkSize < pcm.length) ? i + chunkSize : pcm.length;
      final chunk = pcm.sublist(i, end);
      dictation.onAudioData(chunk);

      await Future.delayed(const Duration(milliseconds: chunkMs));
    }

    await dictation.stopRecording();
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<String> _loadReference(String wavFile) async {
    final srtPath = wavFile.replaceAll('.wav', '.srt');
    try {
      final content = await rootBundle.loadString(srtPath);
      return _stripSrt(content);
    } catch (_) {
      return '';
    }
  }

  String _stripSrt(String content) {
    final lines = content.split('\n');
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

// Provider
final dictationBenchmarkNotifierProvider =
    NotifierProvider<DictationBenchmarkNotifier, DictationBenchmarkState>(
  DictationBenchmarkNotifier.new,
);
