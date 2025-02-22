import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

/// Uses an [OfflineModel], which presumably has an [OfflineRecognizer]
/// you can retrieve via [model.recognizer].
class DictationBenchmarkNotifier extends StateNotifier<DictationState> {
  final Ref ref;
  final OfflineModel model;
  final int sampleRate;
  late final NGramTranscriptionCombiner _transcriptionCombiner =
      NGramTranscriptionCombiner(
          config: NGramTranscriptionConfig(
              ngramSize: 3,
              similarityThreshold: 0.85,
              debug: true // Set to true to see matching details
              ));

  late final RollingCache _audioCache;
  Timer? _stopTimer;
  Timer? _chunkTimer;

  DictationBenchmarkNotifier({
    required this.ref,
    required this.model,
    this.sampleRate = 16000,
  }) : super(const DictationState()) {
    _audioCache = RollingCache(
      sampleRate: sampleRate,
      bitDepth: 2, // 16-bit audio = 2 bytes
      durationSeconds: 10,
    );
  }

  Future<void> startDictation() async {
    if (state.status == DictationStatus.recording) return;

    try {
      state =
          state.copyWith(status: DictationStatus.recording, fullTranscript: '');
      _audioCache.clear();

      // Start recorder
      final recorder = ref.read(mockRecorderProvider.notifier);
      await recorder.setAudioFile(
          '/home/grey/dev/scrybe_benchmarking/assets/dictation_test/test_files/002.wav');
      await recorder.initialize(sampleRate: sampleRate);
      await recorder.startRecorder();
      await recorder.startStreaming(_onAudioData);

      // Set a timer to process small chunks
      _chunkTimer?.cancel();
      _chunkTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _processChunk();
      });

      // Auto-stop after 10s
      _stopTimer?.cancel();
      _stopTimer = Timer(const Duration(seconds: 80), stopDictation);

      print('Dictation started successfully');
    } catch (e) {
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Failed to start: $e',
      );
      print('Error during dictation start: $e');
    }
  }

  void _onAudioData(Uint8List audioData) {
    if (state.status != DictationStatus.recording) return;

    try {
      _audioCache.addChunk(audioData);
    } catch (e) {
      print('Error processing audio data chunk: $e');
    }
  }

  void _processChunk() {
    if (_audioCache.isEmpty) return;

    try {
      final audioData = _audioCache.getData();
      final transcriptionResult = model.processAudio(audioData, sampleRate);
      final combinedText = _transcriptionCombiner.combineTranscripts(
          state.fullTranscript, transcriptionResult);

      state = state.copyWith(
        status: DictationStatus.recording,
        currentChunkText: transcriptionResult,
        fullTranscript: combinedText,
      );
    } catch (e) {
      print('Error during chunk processing: $e');
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Error processing audio chunk: $e',
      );
    }
  }

  Future<void> stopDictation() async {
    if (state.status != DictationStatus.recording) return;

    try {
      _stopTimer?.cancel();
      _stopTimer = null;
      _chunkTimer?.cancel();
      _chunkTimer = null;

      // Process any remaining audio
      if (_audioCache.isNotEmpty) {
        _processChunk();
      }

      // Stop recorder
      final recorder = ref.read(mockRecorderProvider.notifier);
      await recorder.stopStreaming();
      await recorder.stopRecorder();

      _audioCache.clear();

      state = state.copyWith(status: DictationStatus.idle);
    } catch (e) {
      print('Error stopping dictation: $e');
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Stop error: $e',
      );
    }
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _chunkTimer?.cancel();
    _audioCache.clear();
    super.dispose();
  }
}

final dictationBenchmarkProvider = StateNotifierProvider.family<
    DictationBenchmarkNotifier, DictationState, OfflineModel>(
  (ref, model) => DictationBenchmarkNotifier(ref: ref, model: model),
);
