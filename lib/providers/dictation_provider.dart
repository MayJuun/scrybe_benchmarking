import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

// First, update the enum
enum DictationStatus {
  idle,
  recording,
  finishing,
  error,
}

class DictationState {
  final DictationStatus status;
  final String currentChunkText;
  final String fullTranscript;
  final String? errorMessage;
  final BenchmarkProgress? currentFileProgress;
  final BenchmarkProgress? benchmarkProgress;
  final bool benchmarkComplete;

  const DictationState({
    this.status = DictationStatus.idle,
    this.currentChunkText = '',
    this.fullTranscript = '',
    this.errorMessage,
    this.currentFileProgress,
    this.benchmarkProgress,
    this.benchmarkComplete = false,
  });

  DictationState copyWith({
    DictationStatus? status,
    String? currentChunkText,
    String? fullTranscript,
    String? errorMessage,
    BenchmarkProgress? currentFileProgress,
    BenchmarkProgress? benchmarkProgress,
    bool? benchmarkComplete,
  }) {
    return DictationState(
      status: status ?? this.status,
      currentChunkText: currentChunkText ?? this.currentChunkText,
      fullTranscript: fullTranscript ?? this.fullTranscript,
      errorMessage: errorMessage ?? this.errorMessage,
      currentFileProgress: currentFileProgress ?? this.currentFileProgress,
      benchmarkProgress: benchmarkProgress ?? this.benchmarkProgress,
      benchmarkComplete: benchmarkComplete ?? this.benchmarkComplete,
    );
  }
}

/// Uses an [ModelBase], which presumably has an [OfflineRecognizer]
/// you can retrieve via [model.recognizer].
class DictationNotifier extends StateNotifier<DictationState> {
  final Ref ref;
  final ModelBase model;
  final int sampleRate;
  late final TranscriptionCombiner _transcriptionCombiner =
      TranscriptionCombiner(config: TranscriptionConfig());

  late final RollingCache _audioCache;
  Timer? _stopTimer;
  Timer? _chunkTimer;

  DictationNotifier({
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
      final recorder = ref.read(recorderProvider.notifier);
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
      _stopTimer = Timer(const Duration(seconds: 20), stopDictation);

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

// Then, the updated stopDictation method
  Future<void> stopDictation() async {
    if (state.status != DictationStatus.recording) return;

    try {
      // Cancel timers first
      _stopTimer?.cancel();
      _stopTimer = null;
      _chunkTimer?.cancel();
      _chunkTimer = null;

      // Stop the recorder before processing final audio
      final recorder = ref.read(mockRecorderProvider.notifier);
      await recorder.stopStreaming();
      await recorder.stopRecorder();

      // Process any remaining audio before clearing
      if (_audioCache.isNotEmpty) {
        print('Processing final audio chunk...');
        final finalAudioData = _audioCache.getData();
        final finalTranscription =
            model.processAudio(finalAudioData, sampleRate);

        // Combine with existing transcript
        final finalText = _transcriptionCombiner.combineTranscripts(
          state.fullTranscript,
          finalTranscription,
        );

        print('Final chunk transcription: $finalTranscription');
        print('Final complete transcript: $finalText');

        state = state.copyWith(
          status: DictationStatus.finishing,
          currentChunkText: finalTranscription,
          fullTranscript: finalText,
        );
      }

      // Clear cache after processing
      _audioCache.clear();

      // Update final state
      state = state.copyWith(
        status: DictationStatus.idle,
        currentChunkText: '', // Clear current chunk text
      );
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

final dictationProvider =
    StateNotifierProvider.family<DictationNotifier, DictationState, ModelBase>(
  (ref, model) => DictationNotifier(ref: ref, model: model),
);
