// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// Uses an [AsrModel] to process audio from test WAV files, simulating
/// real-life dictation (online) or doing batch decoding (offline).
class DictationNotifier<T extends DictationState> extends StateNotifier<T> {
  DictationNotifier({
    required this.ref,
    required this.model,
    this.sampleRate = 16000,
    DictationState? state,
  })  : service = DictationService(
            model is OfflineRecognizerModel ? model.cacheSize : 20),
        super((state ?? const DictationState()) as T);

  final Ref ref;
  final AsrModel model;
  final int sampleRate;
  final DictationService service;
  Timer? processingTimer;
  VoiceActivityDetector? vad;
  DateTime lastProcessingTime = DateTime.now();
  final minimumProcessingInterval = const Duration(seconds: 2);

  Future<void> startDictation() async {
    if (state.status == DictationStatus.recording) return;

    try {
      state = state.copyWith(
          status: DictationStatus.recording, fullTranscript: '') as T;
      service.clearCache();

      final recorder = ref.read(recorderProvider.notifier);
      await recorder.initialize(sampleRate: sampleRate);
      await recorder.startRecorder();
      await recorder.startStreaming(onAudioData);

      // Set up timer based on model type
      if (model is! OnlineModel) {
        processingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          if (!service.isCacheEmpty()) {
            _processCache();
          }
        });
      }
    } catch (e) {
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Failed to start: $e',
      ) as T;
      print('Error during dictation start: $e');
    }
  }

  void onAudioData(Uint8List audioData) {
    if (state.status != DictationStatus.recording) return;

    try {
      // For online models, process audio directly
      if (model is OnlineModel) {
        final result = service.processOnlineAudio(audioData, model, sampleRate);
        updateTranscript(result);
        return;
      } else {
        // For offline models, add to cache
        service.addToCache(audioData);
      }
    } catch (e) {
      print('Error processing audio data chunk: $e');
    }
  }

  void _processCache() {
    try {
      final audioData = service.getCacheData();
      final transcriptionResult =
          service.processOfflineAudio(audioData, model, sampleRate);

      // Update transcript
      final combinedText = service.updateTranscriptByModelType(
          state.fullTranscript, transcriptionResult, model);

      state = state.copyWith(
        currentChunkText: transcriptionResult,
        fullTranscript: combinedText,
      ) as T;
    } catch (e) {
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Error processing audio chunk: $e',
      ) as T;
    }
  }

  Future<void> stopDictation(
      StateNotifierProvider<BaseRecorderNotifier, RecorderState>
          recorderProvider) async {
    if (state.status != DictationStatus.recording) return;

    try {
      processingTimer?.cancel();
      final recorder = ref.read(recorderProvider.notifier);
      await recorder.stopStreaming();

      // Process remaining audio
      if (model is! OnlineModel) {
        _processCache();
      } else {
        final finalText = service.finalizeTranscription(model, sampleRate);
        if (finalText.trim().isNotEmpty) {
          updateTranscript(finalText);
        }
        service.resetOnlineModel(model);
      }

      await recorder.stopRecorder();
      service.clearCache();

      state = state.copyWith(status: DictationStatus.idle, currentChunkText: '')
          as T;
    } catch (e) {
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Stop error: $e',
      ) as T;
    }
  }

  void updateTranscript(String newText) {
    if (newText.trim().isEmpty) return;
    print('Updating transcript with: $newText');
    print('Current transcript: ${state.fullTranscript}');

    final updatedText = service.updateTranscriptByModelType(
        state.fullTranscript, newText, model);

    print('Updated transcript: $updatedText');
    state = state.copyWith(
      currentChunkText: newText,
      fullTranscript: updatedText,
    ) as T;
  }
}

final dictationProvider =
    StateNotifierProvider.family<DictationNotifier, DictationState, AsrModel>(
  (ref, model) => DictationNotifier(ref: ref, model: model),
);
