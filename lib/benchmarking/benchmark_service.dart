// benchmark_service.dart
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

  Future<List<BenchmarkMetrics>> benchmarkModel(String wavFile) async {
    final results = <BenchmarkMetrics>[];
    final reference = await _loadReferenceTranscript(wavFile);

    // Test each online model
    for (final config in onlineConfigs) {
      results.add(await _testConfiguration(
        config: config,
        wavFile: wavFile,
        reference: reference,
        isOnline: true,
      ));
    }

    // Test each offline model
    for (final config in offlineConfigs) {
      results.add(await _testConfiguration(
        config: config,
        wavFile: wavFile,
        reference: reference,
        isOnline: false,
      ));
    }

    return results;
  }

  Future<BenchmarkMetrics> _testConfiguration({
    required dynamic config,
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
          onlineRecognizer: OnlineRecognizer(config as OnlineRecognizerConfig));
    } else {
      dictation = OfflineDictation(
          offlineRecognizer:
              OfflineRecognizer(config as OfflineRecognizerConfig));
    }

    await dictation.init();

    String transcription = '';
    dictation.recognizedTextStream.listen((text) {
      if (dictation is OnlineDictation) {
        final lines = transcription.split('\n');
        if (lines.isNotEmpty) lines.removeLast();
        lines.add(text);
        transcription = lines.join('\n');
      } else {
        transcription = '$transcription\n$text';
      }
    });

    final startTime = DateTime.now();
    await _processAudioFile(wavFile, dictation);
    final duration = DateTime.now().difference(startTime);

    // Use the factory method to create metrics
    final metrics = await BenchmarkMetrics.create(
      modelName: modelName,
      modelType: isOnline ? 'online' : 'offline',
      wavFile: wavFile,
      transcription: transcription.trim(),
      reference: reference,
      processingDuration: duration,
    );

    await dictation.dispose();
    return metrics;
  }

  Future<void> _processAudioFile(
      String filePath, DictationBase dictation) async {
    // Load the WAV file as Uint8List from assets
    final bytes = await loadWavFile(filePath);

    // Start the dictation system.
    await dictation.startRecording();

    // For 30ms of audio at 16kHz, 16-bit mono:
    // 16,000 samples/sec * 0.03 sec = 480 samples. 
    // Since each sample is 2 bytes, chunkSize = 480 * 2 = 960 bytes.
    const int chunkSize = 960;
    const Duration chunkDuration = Duration(milliseconds: 30);

    // Create a simulated microphone stream from the WAV file
    final micStream = simulateMicStream(bytes, chunkSize, chunkDuration);

    // Listen to the simulated stream and feed chunks to the dictation handler.
    await for (final chunk in micStream) {
      dictation.onAudioData(chunk);
    }

    await dictation.stopRecording();
    // Optionally wait a moment for any final processing.
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Helper to load a WAV file from assets
  Future<Uint8List> loadWavFile(String path) async {
    return await rootBundle
        .load(path)
        .then((data) => data.buffer.asUint8List());
  }

  // Helper to simulate a microphone stream by chunking the audio data
  Stream<Uint8List> simulateMicStream(
      Uint8List audioData, int chunkSize, Duration chunkDuration) async* {
    int offset = 0;
    while (offset < audioData.length) {
      int end = offset + chunkSize;
      if (end > audioData.length) {
        end = audioData.length;
      }
      yield audioData.sublist(offset, end);
      offset = end;
      await Future.delayed(chunkDuration); // simulate real-time delay
    }
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
