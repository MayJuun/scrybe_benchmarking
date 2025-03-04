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
    vad ??= await loadSileroVad();
    if (state.status == DictationStatus.recording) return;

    try {
      state = state.copyWith(
          status: DictationStatus.recording, fullTranscript: '') as T;
      service.clearCache();
      lastProcessingTime = DateTime.now();
      final recorder = ref.read(recorderProvider.notifier);
      await recorder.initialize(sampleRate: sampleRate);
      await recorder.startRecorder();
      await recorder.startStreaming(onAudioData);

      // Set up timer based on model type
      if (model is! OnlineModel) {
        if (vad == null) {
          processingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
            if (!service.isCacheEmpty()) {
              _processCache();
            }
          });
        }
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
        if (vad != null) {
          if (vad != null) {
            // Convert audioData to Float32List as required by Silero VAD
            // Assuming audioData is 16-bit PCM
            final float32Data = model.convertBytesToFloat32(audioData);

            // Feed audio to VAD
            vad!.acceptWaveform(float32Data);
            final now = DateTime.now();
            final timeSinceLastProcessing = now.difference(lastProcessingTime);

            // Check if VAD detected end of speech segment
            if (vad!.isDetected() &&
                timeSinceLastProcessing > minimumProcessingInterval &&
                !service.isCacheEmpty()) {
              // Process the cached audio when silence is detected
              _processCache();

              lastProcessingTime = now;

              // Get any remaining speech segments from VAD
              while (!vad!.isEmpty()) {
                // We're not using the segments directly as we've already
                // added all audio to the cache, but we need to clear
                // the VAD buffer
                vad!.pop();
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error processing audio data chunk: $e');
    }
  }

  void _processCache() {
    try {
      var audioData = service.getCacheData();

      // Check minimum audio length
      final minBytes = 16000 * 2 * 2; // 1 second
      if (audioData.length < minBytes) {
        print('Audio chunk too short (${audioData.length} bytes), skipping');
        return;
      }

      // Limit maximum audio length if needed
      final maxBytes = 16000 * 2 * 10; // 10 seconds maximum
      if (audioData.length > maxBytes) {
        print(
            'Audio chunk too large (${audioData.length} bytes), trimming to ${maxBytes} bytes');
        audioData =
            Uint8List.fromList(audioData.sublist(audioData.length - maxBytes));
      }

      String transcriptionResult;

      try {
        transcriptionResult =
            service.processOfflineAudio(audioData, model, sampleRate);
        // service.resetCache();
      } catch (e) {
        if (e.toString().contains('invalid expand shape')) {
          print('Caught Whisper shape error, likely audio chunk too small');
          return; // Skip this chunk
        }
        rethrow; // Re-throw other errors
      }

      // Skip if empty result
      if (transcriptionResult.trim().isEmpty) {
        return;
      }

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

    final updatedText = service.updateTranscriptByModelType(
        state.fullTranscript, newText, model);

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
