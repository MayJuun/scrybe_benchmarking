import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

class DictationState {
  final bool isModelLoading;
  final bool isRecording;
  final String recognizedText;
  final String? selectedModelName;

  const DictationState({
    this.isModelLoading = false,
    this.isRecording = false,
    this.recognizedText = '',
    this.selectedModelName,
  });

  DictationState copyWith({
    bool? isModelLoading,
    bool? isRecording,
    String? recognizedText,
    String? selectedModelName,
  }) {
    return DictationState(
      isModelLoading: isModelLoading ?? this.isModelLoading,
      isRecording: isRecording ?? this.isRecording,
      recognizedText: recognizedText ?? this.recognizedText,
      selectedModelName: selectedModelName ?? this.selectedModelName,
    );
  }
}

class DictationNotifier extends Notifier<DictationState> {
  DictationBase? _dictation;

  @override
  DictationState build() {
    // Start with defaults
    return const DictationState();
  }

  /// On mobile (Android/iOS), request microphone permission
  Future<void> requestMicPermission() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // No mic permission needed
      return;
    }
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('Microphone permission not granted');
    }
  }

  /// Initialize a dictation session with either an online or offline config,
  /// based on the provided model name.
  Future<void> initializeDictation({
    required String modelName,
    required List<OnlineRecognizerConfig> onlineModels,
    required List<OfflineRecognizerConfig> offlineModels,
  }) async {
    // If already loading, skip
    if (state.isModelLoading) return;

    // Set loading true
    state = state.copyWith(isModelLoading: true, recognizedText: '');

    // Dispose old instance if any
    await _dictation?.dispose();
    _dictation = null;

    try {
      // Try finding an offline model first
      final offlineModel = offlineModels.firstWhere(
        (m) => m.modelName == modelName,
        orElse: () => throw Exception('Not found in offline'),
      );
      _dictation = OfflineDictation(
        offlineRecognizer: OfflineRecognizer(offlineModel),
      );
      state = state.copyWith(selectedModelName: modelName);
    } catch (_) {
      // If not found offline, fall back to online
      final onlineModel = onlineModels.firstWhere(
        (m) => m.modelName == modelName,
        orElse: () => throw Exception('Model not found in any config'),
      );
      _dictation = OnlineDictation(
        onlineRecognizer: OnlineRecognizer(onlineModel),
      );
      state = state.copyWith(selectedModelName: modelName);
    }

    // Initialize the dictation object
    await _dictation?.init();

    // Subscribe to recognizedTextStream
    _dictation?.recognizedTextStream.listen((partialOrFinalText) {
      // For an online model, we treat the last line as a partial
      if (_dictation is OnlineDictation) {
        final lines = state.recognizedText.split('\n');
        if (lines.isNotEmpty) lines.removeLast();
        lines.add(partialOrFinalText);
        final newText = lines.join('\n');
        state = state.copyWith(recognizedText: newText);
      } else {
        // For offline, just keep appending new lines
        final newText = '${state.recognizedText}\n$partialOrFinalText';
        state = state.copyWith(recognizedText: newText);
      }
    });

    // Done loading
    state = state.copyWith(isModelLoading: false);
  }

  /// Start or stop recording from the mic
  Future<void> toggleRecording() async {
    if (_dictation == null) {
      debugPrint('No dictation instance, cannot toggle');
      return;
    }

    final isCurrentlyRecording = state.isRecording;
    if (isCurrentlyRecording) {
      await _dictation?.stopRecording();
      state = state.copyWith(isRecording: false);
    } else {
      await _dictation?.startRecording();
      state = state.copyWith(isRecording: true);
    }
  }

  Future<void> dispose() async {
    await _dictation?.dispose();
    _dictation = null;
  }
}

// Provider
final dictationNotifierProvider =
    NotifierProvider<DictationNotifier, DictationState>(DictationNotifier.new);
