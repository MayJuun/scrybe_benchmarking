// benchmark_service.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

class BenchmarkService {
  final List<OnlineRecognizerConfig> onlineConfigs;
  final List<OfflineRecognizerConfig> offlineConfigs;

  BenchmarkService({
    required this.onlineConfigs,
    required this.offlineConfigs,
  });

  /// Run benchmarks for a list of WAV files, returning a single list of all results.
  Future<List<BenchmarkMetrics>> runAllBenchmarks(List<String> wavFiles) async {
    final allResults = <BenchmarkMetrics>[];

    for (final wavFile in wavFiles) {
      final metricsForThisFile = await benchmarkModel(wavFile);
      allResults.addAll(metricsForThisFile);
    }

    return allResults;
  }

  /// Benchmarks **all** online & offline configs on one WAV file.
  /// Returns a list of BenchmarkMetrics (one per model).
  Future<List<BenchmarkMetrics>> benchmarkModel(String wavFile) async {
    final results = <BenchmarkMetrics>[];

    // Load the WAV file once so we can get both its bytes and length
    final wavData = await rootBundle.load(wavFile);
    final audioBytes = wavData.buffer.asUint8List();
    // Calculate audio length in ms => (#samples / sample_rate)*1000
    // For 16-bit, 16 kHz, mono => each sample = 2 bytes
    final audioLengthMs =
        (audioBytes.length / (16000 * 2) * 1000).floor();

    // Load the reference transcript if available
    final reference = await _loadReferenceTranscript(wavFile);

    // Test each online model
    for (final config in onlineConfigs) {
      final metrics = await _testConfiguration(
        config: config,
        wavBytes: audioBytes,
        audioLengthMs: audioLengthMs,
        wavFile: wavFile,
        reference: reference,
        isOnline: true,
      );
      results.add(metrics);
    }

    // Test each offline model
    for (final config in offlineConfigs) {
      final metrics = await _testConfiguration(
        config: config,
        wavBytes: audioBytes,
        audioLengthMs: audioLengthMs,
        wavFile: wavFile,
        reference: reference,
        isOnline: false,
      );
      results.add(metrics);
    }

    return results;
  }

  Future<BenchmarkMetrics> _testConfiguration({
    required dynamic config,
    required Uint8List wavBytes,
    required int audioLengthMs,
    required String wavFile,
    required String reference,
    required bool isOnline,
  }) async {
    final modelName = isOnline
        ? (config as OnlineRecognizerConfig).modelName
        : (config as OfflineRecognizerConfig).modelName;

    DictationBase dictation;
    if (isOnline) {
      dictation = OnlineDictation(
        onlineRecognizer: OnlineRecognizer(config as OnlineRecognizerConfig),
      );
    } else {
      dictation = OfflineDictation(
        offlineRecognizer: OfflineRecognizer(config as OfflineRecognizerConfig),
      );
    }

    // Initialize the ASR
    await dictation.init();

    // Collect recognized text
    String transcription = '';
    dictation.recognizedTextStream.listen((text) {
      // For online, you might accumulate partial transcripts line by line
      // For offline, it's typically one final chunk
      if (dictation is OnlineDictation) {
        final lines = transcription.split('\n');
        if (lines.isNotEmpty) {
          lines.removeLast();
        }
        lines.add(text);
        transcription = lines.join('\n');
      } else {
        transcription = '$transcription\n$text';
      }
    });

    // Start timing
    final startTime = DateTime.now();

    // Simulate streaming from the WAV bytes
    await _processAudioBytes(wavBytes, dictation);

    // Measure total decode time
    final duration = DateTime.now().difference(startTime);

    // Dispose the dictation resources
    await dictation.dispose();

    // Create metrics
    return BenchmarkMetrics.create(
      modelName: modelName,
      modelType: isOnline ? 'online' : 'offline',
      wavFile: wavFile,
      transcription: transcription.trim(),
      reference: reference,
      processingDuration: duration,
      audioLengthMs: audioLengthMs,
    );
  }

  /// Simulates the mic by sending ~30ms chunks of audio data
  Future<void> _processAudioBytes(Uint8List bytes, DictationBase dictation) async {
    await dictation.startRecording();

    // For 30ms of audio at 16kHz, 16-bit mono => chunkSize = 960 bytes
    const int chunkSize = 960;
    const Duration chunkDuration = Duration(milliseconds: 30);

    int offset = 0;
    while (offset < bytes.length) {
      final end = (offset + chunkSize).clamp(0, bytes.length);
      final chunk = bytes.sublist(offset, end);
      offset = end;
      // Send to dictation
      dictation.onAudioData(chunk);
      // Wait to mimic real-time streaming
      await Future.delayed(chunkDuration);
    }

    // Stop recording
    await dictation.stopRecording();
    // A small delay to let final processing settle
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<String> _loadReferenceTranscript(String wavFile) async {
    final txtFile = wavFile.replaceAll('.wav', '.srt');
    try {
      return await rootBundle.loadString(txtFile);
    } catch (e) {
      print('No reference transcript found for $wavFile');
      return '';
    }
  }
}
