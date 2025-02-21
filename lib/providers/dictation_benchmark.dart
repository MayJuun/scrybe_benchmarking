import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

/// Distinguishes offline-vs-online, but always chunk-feed in near real time.
class DictationBenchmarkState {
  final bool isBenchmarking;
  final String currentModel;
  final String currentFile;
  final double progress; // 0..1
  final String recognizedText;

  /// We store final metrics in a list, one for each (model + file).
  final List<BenchmarkMetrics> metricsList;

  /// The .wav test files discovered.
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

  // 1) Load .wav test files from assets/dictation_test/test_files
  Future<void> loadTestFiles() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    final testFilePaths = manifestMap.keys
        .where((key) => key.startsWith('assets/dictation_test/test_files/'))
        .toList();

    final wavFiles = testFilePaths.where((p) => p.endsWith('.wav')).toList();
    state = state.copyWith(testFiles: wavFiles);
  }

  /// 2) Main run method: we do chunk-based dictation with
  ///    (1) online models, or
  ///    (2) offline models in a "sliding window" or "accumulate + partial decode" approach.
  Future<void> runBenchmark({
    required List<OnlineRecognizerConfig> onlineConfigs,
    required List<OfflineRecognizerConfig> offlineConfigs,
  }) async {
    print('running benchmark');
    state = state.copyWith(
      isBenchmarking: true,
      metricsList: [],
      recognizedText: '',
      progress: 0.0,
    );

    final allMetrics = <BenchmarkMetrics>[];
    final totalFiles = state.testFiles.length;
    if (totalFiles == 0) {
      print('No .wav files found in dictation_test/test_files/. Aborting.');
      state = state.copyWith(isBenchmarking: false);
      return;
    }

    try {
      // 2A) "Online" models => chunk feed in real time
      for (final onlineCfg in onlineConfigs) {
        final recognizer = OnlineRecognizer(onlineCfg);
        for (int i = 0; i < totalFiles; i++) {
          final wavPath = state.testFiles[i];
          final fileName = p.basename(wavPath);
          final fileProgress = i / totalFiles;

          state = state.copyWith(
            currentModel: onlineCfg.modelName,
            currentFile: fileName,
            progress: fileProgress,
            recognizedText: '',
          );

          final m = await _processOneWavOnlineDictation(
            recognizer,
            wavPath,
            onlineCfg.modelName,
          );
          allMetrics.add(m);

          // Show recognized text from that final result
          state = state.copyWith(
            recognizedText: m.transcription,
            metricsList: List.from(allMetrics),
          );
        }
        recognizer.free();
      }

      // 2B) "Offline" models => chunk feed in real time,
      //     but do repeated partial decode or 1 final decode after each chunk
      //     using a rolling accumulation or sliding window approach.
      for (final offlineCfg in offlineConfigs) {
        print('offline model: ${offlineCfg.modelName}');
        final recognizer = OfflineRecognizer(offlineCfg);
        final offlineDictation =
            OfflineDictation(offlineRecognizer: recognizer);
        for (int i = 0; i < totalFiles; i++) {
          final wavPath = state.testFiles[i];
          final fileName = p.basename(wavPath);
          final fileProgress = i / totalFiles;

          state = state.copyWith(
            currentModel: offlineCfg.modelName,
            currentFile: fileName,
            progress: fileProgress,
            recognizedText: '',
          );

          print('processing $wavPath');

          final m = await _processOneWavOfflineForDictation(
            offlineDictation,
            wavPath,
            offlineCfg.modelName,
          );
          allMetrics.add(m);

          state = state.copyWith(
            recognizedText: m.transcription,
            metricsList: List.from(allMetrics),
          );
        }
        recognizer.free();
      }

      // Done all
      state = state.copyWith(progress: 1.0, metricsList: allMetrics);

      // Optionally write CSV/JSON/MD
      final outDir =
          Directory(p.join(Directory.current.path, 'assets', 'derived'));
      if (await outDir.exists()) {
        await outDir.delete(recursive: true);
      }
      await outDir.create(recursive: true);

      final reporter = BenchmarkReportGenerator(
        metricsList: allMetrics,
        outputDir: outDir.path,
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

  // --------------------------------------------------------------------------
  // 3) Online dictation approach: chunk feed
  // --------------------------------------------------------------------------
  Future<BenchmarkMetrics> _processOneWavOnlineDictation(
    OnlineRecognizer recognizer,
    String wavFilePath,
    String modelName,
  ) async {
    final startTime = DateTime.now();
    final stream = recognizer.createStream();

    final pcmBytes = await _loadAndParseWav(wavFilePath);

    // 30 ms chunking
    final chunkMs = 30;
    final chunkSize = _bytesPerChunk(chunkMs);

    for (int offset = 0; offset < pcmBytes.length; offset += chunkSize) {
      final iterationStart = DateTime.now();

      final end = (offset + chunkSize).clamp(0, pcmBytes.length);
      final chunk = pcmBytes.sublist(offset, end);

      final floats = _int16bytesToFloat32(chunk);
      stream.acceptWaveform(samples: floats, sampleRate: 16000);

      while (recognizer.isReady(stream)) {
        recognizer.decode(stream);
      }

      // ensure real-time
      final elapsed = DateTime.now().difference(iterationStart).inMilliseconds;
      final leftover = chunkMs - elapsed;
      if (leftover > 0) {
        await Future.delayed(Duration(milliseconds: leftover));
      }
    }

    // finalize
    stream.inputFinished();
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    final finalText = recognizer.getResult(stream).text.trim();
    stream.free();

    final endTime = DateTime.now();
    final durationMs = endTime.difference(startTime).inMilliseconds;
    final audioMs = _estimateAudioMs(pcmBytes.length);

    final reference = await _loadTranscriptIfAny(wavFilePath);
    return BenchmarkMetrics.create(
      modelName: modelName,
      modelType: 'online',
      wavFile: wavFilePath,
      transcription: finalText,
      reference: reference,
      processingDuration: Duration(milliseconds: durationMs),
      audioLengthMs: audioMs,
    );
  }

  // --------------------------------------------------------------------------
  // 4) Offline dictation approach:
  //    We'll feed chunks in near real time, do repeated partial decode
  //    with a rolling buffer or sliding window, or simpler "accumulate & decode each chunk."
  // --------------------------------------------------------------------------
  Future<BenchmarkMetrics> _processOneWavOfflineForDictation(
    OfflineDictation dictation,
    String wavFilePath,
    String modelName,
  ) async {
    final startTime = DateTime.now();
    final pcmBytes = await _loadAndParseWav(wavFilePath);
    final chunkMs = 30; // feed 30ms at a time
    final chunkSize = _bytesPerChunk(chunkMs);
    List<Uint8List> chunks = [];
    dictation.isRecording = true;
    for (int offset = 0; offset < pcmBytes.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, pcmBytes.length);
      chunks.add(pcmBytes.sublist(offset, end));
    }

    // We'll track recognized text by re-decoding the entire rolling buffer each time.
    String finalTranscription = '';

    for (final chunk in chunks) {
      await Future.delayed(Duration(milliseconds: 30)); // simulate real-time
      dictation.onAudioData(chunk);
    }

    // end
    final endTime = DateTime.now();
    final durationMs = endTime.difference(startTime).inMilliseconds;
    final audioMs = _estimateAudioMs(pcmBytes.length);

    final reference = await _loadTranscriptIfAny(wavFilePath);
    dictation.isRecording = false;
    return BenchmarkMetrics.create(
      modelName: modelName,
      modelType: 'offline',
      wavFile: wavFilePath,
      transcription: finalTranscription.trim(),
      reference: reference,
      processingDuration: Duration(milliseconds: durationMs),
      audioLengthMs: audioMs,
    );
  }

  // --------------------------------------------------------------------------
  // Utility
  // --------------------------------------------------------------------------
  int _bytesPerChunk(int chunkMs) =>
      ((16000 * 2) / 1000 * chunkMs).round(); // ~960

  Future<Uint8List> _loadAndParseWav(String wavPath) async {
    final wavData = await rootBundle.load(wavPath);
    final allBytes = wavData.buffer.asUint8List();
    if (allBytes.length < 44) {
      throw Exception('WAV file too small or invalid header: $wavPath');
    }
    return allBytes.sublist(44); // naive skip
  }

  Float32List _int16bytesToFloat32(Uint8List bytes) {
    final numSamples = bytes.length ~/ 2;
    final floats = Float32List(numSamples);
    final data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);

    for (int i = 0; i < bytes.length; i += 2) {
      final sample = data.getInt16(i, Endian.little);
      floats[i >> 1] = sample / 32768.0;
    }
    return floats;
  }

  int _estimateAudioMs(int numBytes) {
    final sampleCount = numBytes ~/ 2; // 2 bytes per sample
    return (sampleCount * 1000) ~/ 16000;
  }

  Future<String> _loadTranscriptIfAny(String wavFile) async {
    final srtPath = wavFile.replaceAll('.wav', '.srt');
    try {
      final raw = await rootBundle.loadString(srtPath);
      return _stripSrt(raw);
    } catch (_) {
      return '';
    }
  }

  String _stripSrt(String raw) {
    final lines = raw.split('\n');
    final sb = StringBuffer();
    for (final l in lines) {
      final t = l.trim();
      if (t.isEmpty) continue;
      if (RegExp(r'^\d+$').hasMatch(t)) continue;
      if (t.contains('-->')) continue;
      sb.write('$t ');
    }
    return sb.toString().trim();
  }
}

// Provide it
final dictationBenchmarkNotifierProvider =
    NotifierProvider<DictationBenchmarkNotifier, DictationBenchmarkState>(
  DictationBenchmarkNotifier.new,
);
