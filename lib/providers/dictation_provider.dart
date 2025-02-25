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
  final String? errorMessage;
  final String currentChunkText; // Text from current processing
  final String fullTranscript; // Accumulated transcript

  const DictationState({
    this.status = DictationStatus.idle,
    this.errorMessage,
    this.currentChunkText = '',
    this.fullTranscript = '',
  });

  DictationState copyWith({
    DictationStatus? status,
    String? errorMessage,
    String? currentChunkText,
    String? fullTranscript,
  }) {
    return DictationState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      currentChunkText: currentChunkText ?? this.currentChunkText,
      fullTranscript: fullTranscript ?? this.fullTranscript,
    );
  }
}

/// Uses an [OfflineModel], which presumably has an [OfflineRecognizer]
/// you can retrieve via [model.recognizer].
class DictationNotifier extends StateNotifier<DictationState> {
  final Ref ref;

  // sherpa_onnx objects
  final OfflineModel _model;
  final int sampleRate;
  final RollingCache _rollingCache = RollingCache();
  Timer? _processingTimer;

  DictationNotifier({
    required this.ref,
    required OfflineModel model,
    this.sampleRate = 16000,
  })  : _model = model,
        super(const DictationState());

  Future<void> startDictation() async {
    if (state.status == DictationStatus.recording) return;

    try {
      state =
          state.copyWith(status: DictationStatus.recording, fullTranscript: '');
      _rollingCache.clear();
      // Start recorder
      final recorder = ref.read(recorderProvider.notifier);
      await recorder.initialize(sampleRate: sampleRate);
      await recorder.startRecorder();
      await recorder.startStreaming(_onAudioData);

      _processingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _processCache();
      });

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
      _rollingCache.addChunk(audioData);
    } catch (e) {
      print('Error processing audio data chunk: $e');
    }
  }

  void _processCache() {
    if (_rollingCache.isEmpty) return;

    try {
      final audioData = _rollingCache.getData();
      final transcriptionResult = _model.processAudio(audioData, sampleRate);

      final combinedText = '${state.fullTranscript} $transcriptionResult';

      print('Combined transcript: "$combinedText"');
      state = state.copyWith(
        status: DictationStatus.recording,
        currentChunkText: transcriptionResult,
        fullTranscript: combinedText,
      );
      _rollingCache.clear();
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
      _processingTimer?.cancel();
      final recorder = ref.read(mockRecorderProvider.notifier);
      await recorder.stopStreaming();
      _processCache();
      await recorder.stopRecorder();
      _rollingCache.clear();

      // Update final state
      state =
          state.copyWith(status: DictationStatus.idle, currentChunkText: '');
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
    _rollingCache.clear();
    super.dispose();
  }
}

final dictationProvider = StateNotifierProvider.family<DictationNotifier,
    DictationState, OfflineModel>(
  (ref, model) => DictationNotifier(ref: ref, model: model),
);
