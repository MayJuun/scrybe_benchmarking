import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

enum DictationStatus { idle, recording, error }

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
  final OfflineModel model;
  final int sampleRate;

  late final RollingCache _audioCache;
  OfflineStream? _currentStream;
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

      // Create a single stream at the start
      _currentStream = model.recognizer.createStream();
      if (_currentStream == null) {
        throw Exception('Failed to create recognition stream');
      }

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
      // Clean up stream if creation failed
      _currentStream?.free();
      _currentStream = null;

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
      print('Received audio data chunk of size: ${audioData.length}');
      _audioCache.addChunk(audioData);
    } catch (e) {
      print('Error processing audio data chunk: $e');
    }
  }

  void _processChunk() {
    if (_audioCache.isEmpty) return;

    try {
      final audioData = _audioCache.getData();
      print('Processing chunk of size: ${audioData.length} bytes');

      final samples = convertBytesToFloat32(audioData);
      final newStream = model.recognizer.createStream();

      newStream.acceptWaveform(samples: samples, sampleRate: sampleRate);
      model.recognizer.decode(newStream);

      final result = model.recognizer.getResult(newStream);
      final newText = result.text;
      print('Processed chunk: $newText');

      // Naive text combination - could be improved
      final combinedText = _combineTranscripts(state.fullTranscript, newText);

      state = state.copyWith(
        status: DictationStatus.recording,
        currentChunkText: newText,
        fullTranscript: combinedText,
      );

      newStream.free();
    } catch (e) {
      print('Error during chunk processing: $e');
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Error processing audio chunk: $e',
      );
    }
  }

  String _combineTranscripts(String existing, String newText) {
    if (existing.isEmpty) return newText;

    // Split into words for comparison
    final existingWords = existing.split(' ');
    final newWords = newText.split(' ');

    // Look for overlap at the end of existing and start of new
    for (int overlapLength = min(existingWords.length, newWords.length);
        overlapLength > 0;
        overlapLength--) {
      final existingEnd =
          existingWords.sublist(existingWords.length - overlapLength);
      final newStart = newWords.sublist(0, overlapLength);

      if (listEquals(existingEnd, newStart)) {
        // Found overlap, combine without duplicating
        final remainingNewWords = newWords.sublist(overlapLength);
        return '$existing ${remainingNewWords.join(' ')}';
      }
    }

    // No overlap found, just append with separator
    return '$existing | $newText';
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
      final recorder = ref.read(recorderProvider.notifier);
      await recorder.stopStreaming();
      await recorder.stopRecorder();

      // Clean up
      _currentStream?.free();
      _currentStream = null;
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
    _currentStream?.free();
    _audioCache.clear();
    super.dispose();
  }
}

final dictationProvider = StateNotifierProvider.family<DictationNotifier,
    DictationState, OfflineModel>(
  (ref, model) => DictationNotifier(ref: ref, model: model),
);
