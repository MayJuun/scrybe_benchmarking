// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

/// Uses an [AsrModel] to process audio from test WAV files, simulating
/// real-life dictation (online) or doing batch decoding (offline).
class DictationNotifier extends StateNotifier<DictationState> {
  DictationNotifier({
    required this.ref,
    required this.model,
    this.sampleRate = 16000,
  })  : service = DictationService(),
        super(const DictationState());

  final Ref ref;
  final AsrModel model;
  final int sampleRate;
  final DictationService service;
  Timer? processingTimer;

  Future<void> startDictation() async {
    if (state.status == DictationStatus.recording) return;

    try {
      state =
          state.copyWith(status: DictationStatus.recording, fullTranscript: '');
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
      } else {
        service.resetOnlineModel(model);
        processingTimer =
            Timer.periodic(const Duration(milliseconds: 300), (_) {
          // UI update timer - audio processing is done in onAudioData
        });
      }
    } catch (e) {
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Failed to start: $e',
      );
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
      }

      // For offline models, add to cache
      service.addToCache(audioData);
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
      );
    } catch (e) {
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Error processing audio chunk: $e',
      );
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

      state =
          state.copyWith(status: DictationStatus.idle, currentChunkText: '');
    } catch (e) {
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Stop error: $e',
      );
    }
  }

  void updateTranscript(String newText) {
    if (newText.trim().isEmpty) return;

    final updatedText = service.updateTranscriptByModelType(
        state.fullTranscript, newText, model);

    state = state.copyWith(
      currentChunkText: newText,
      fullTranscript: updatedText,
    );
  }
}

final dictationProvider =
    StateNotifierProvider.family<DictationNotifier, DictationState, AsrModel>(
  (ref, model) => DictationNotifier(ref: ref, model: model),
);
