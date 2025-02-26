// ignore_for_file: avoid_print

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

/// Uses an [AsrModel] to process audio from test WAV files, simulating
/// real-life dictation (online) or doing batch decoding (offline).
class DictationNotifier extends StateNotifier<DictationState> {
  DictationNotifier({
    required this.ref,
    required AsrModel model,
    this.sampleRate = 16000,
    required TestFiles testFiles,
  })  : _testFiles = testFiles,
        _model = model,
        super(const DictationState());

  final Ref ref;

  // sherpa_onnx objects
  final AsrModel _model;
  final int sampleRate;
  final RollingCache _rollingCache = RollingCache();
  Timer? _processingTimer;
  VoiceActivityDetector? _vad;

  // Timing
  Stopwatch? _processingStopwatch;
  Duration _accumulatedProcessingTime = Duration.zero;

  // Collect metrics from each file
  final TestFiles _testFiles;
  final List<BenchmarkMetrics> _allMetrics = [];
  Completer<void>? _processingCompleter;

  bool isTest = false;

  /// Metrics are stored in `_allMetrics`.
  List<BenchmarkMetrics> get metrics => List.unmodifiable(_allMetrics);

  Future<void> prepareForBenchmark() async {
    isTest = true;
    if (_testFiles.isEmpty) {
      await _testFiles.loadTestFiles();
    }
  }

  /// Start a dictation “run” for the current file. If called repeatedly,
  /// it processes all files in `_testFiles` in sequence.
  Future<void> startDictation() async {
    if (state.status == DictationStatus.recording) return;
    _vad ??= await loadSileroVad();

    if (isTest) {
      _processingCompleter ??= Completer<void>();
      if (_testFiles.isEmpty ||
          _testFiles.currentFileIndex >= _testFiles.length) {
        state = state.copyWith(
            status: DictationStatus.error,
            errorMessage: 'No test files available');
        return;
      }
    }

    try {
      // Clear state, get ready to record
      state =
          state.copyWith(status: DictationStatus.recording, fullTranscript: '');
      _rollingCache.clear();

      if (isTest) {
        final recorder = ref.read(mockRecorderProvider.notifier);
        await recorder.setAudioFile(_testFiles.currentFile);
        await recorder.initialize(sampleRate: sampleRate);
        await recorder.startRecorder();
        await recorder.startStreaming(
          _onAudioData,
          onComplete: _onFileComplete,
        );
        print('Processing file ${_testFiles.currentFileIndex + 1}'
            '/${_testFiles.length}: '
            '${_testFiles.currentFile}');
      } else {
        final recorder = ref.read(recorderProvider.notifier);
        await recorder.initialize(sampleRate: sampleRate);
        await recorder.startRecorder();

        // For streaming audio directly
        await recorder.startStreaming(_onAudioData);

        // Only use the timer for offline models or for UI updates with online models
        if (_model is! OnlineModel) {
          _processingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
            // Only process if we have data and no VAD or VAD is not being used
            if (_rollingCache.isNotEmpty && _vad == null) {
              _processCache();
            }
          });
        } else {
          _resetOnlineModel();
          // For online models, we might still want a timer for UI updates
          // but at a much higher frequency
          _processingTimer =
              Timer.periodic(const Duration(milliseconds: 300), (_) {
            // We could update UI here if needed, but audio processing
            // is handled directly in _onAudioData
          });
        }
      }
    } catch (e) {
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Failed to start: $e',
      );
      print('Error during dictation start: $e');
    }

    if (isTest) return _processingCompleter!.future;
  }

  void _onAudioData(Uint8List audioData) {
    if (state.status != DictationStatus.recording) return;

    try {
      final Float32List floatAudio = convertBytesToFloat32(audioData);
      if (_vad != null) {
        _vad!.acceptWaveform(floatAudio);
        while (!_vad!.isEmpty()) {
          final segment = _vad!.front();
          final samples = segment.samples;
          final segmentAudio = convertFloat32ToBytes(samples);

          // For online models, process directly here rather than accumulating
          if (_model is OnlineModel) {
            final result = _model.processAudio(segmentAudio, sampleRate);
            _updateTranscript(result);
          } else {
            // For offline models, continue using the rolling cache
            _rollingCache.addChunk(segmentAudio);
            _processCache();
          }

          _vad!.pop();
        }
      } else if (_model is OnlineModel) {
        final result = _model.processAudio(audioData, sampleRate);
        _updateTranscript(result);
      } else {
        _rollingCache.addChunk(audioData);
      }
    } catch (e) {
      print('Error processing audio data chunk with VAD: $e');
    }
  }

  /// Only for offline: process the RollingCache audio (e.g., every 1s).
  /// We decode the entire cache, then combine transcripts.
  void _processCache() {
    if (_rollingCache.isEmpty) return;

    try {
      final audioData = _rollingCache.getData();
      if (isTest) {
        print(
            'Processing audio chunk of ${audioData.length} bytes (${audioData.length / (2 * sampleRate)} seconds)');

        _processingStopwatch = Stopwatch()..start();
      }
      final transcriptionResult = _model is OfflineModel
          ? _model.processAudio(audioData, sampleRate)
          : '';
      if (isTest) {
        _processingStopwatch?.stop();
        _accumulatedProcessingTime +=
            _processingStopwatch?.elapsed ?? Duration.zero;
      }
      print('Current transcript before combining: "${state.fullTranscript}"');
      print('New transcription result: "$transcriptionResult"');

      final combinedText =
          '${state.fullTranscript} $transcriptionResult'.trim();

      print('Combined transcript: "$combinedText"');

      state = state.copyWith(
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

  Future<void> _onFileComplete() async {
    // Stop the current dictation session (stop recorder, clear cache, etc.).
    await stopDictation();

    // Collect metrics for this file.
    final currentFile = _testFiles.currentFile;
    final metrics = BenchmarkMetrics.create(
      modelName: _model.modelName,
      modelType: 'offline',
      wavFile: currentFile,
      transcription: state.fullTranscript,
      reference: _testFiles.currentReferenceTranscript ?? '',
      processingDuration: _accumulatedProcessingTime,
      audioLengthMs: _testFiles.currentFileDuration ?? 0,
    );
    print('Creating metrics with transcript: ${state.fullTranscript}');
    _allMetrics.add(metrics);

    // Reset timing.
    _accumulatedProcessingTime = Duration.zero;
    _processingStopwatch = null;

    // If there are more files, move on to the next one.
    if (_testFiles.currentFileIndex < _testFiles.length - 1) {
      _testFiles.currentFileIndex++;
      await startDictation();
    } else {
      print('All test files processed for ${_model.modelName}');
      state = state.copyWith(status: DictationStatus.idle);
      _processingCompleter?.complete();
      _processingCompleter = null;
    }
  }

  void _resetOnlineModel() {
    if (_model is OnlineModel) {
      _model.resetStream();
    }
  }

  Future<void> stopDictation() async {
    if (state.status != DictationStatus.recording) return;

    try {
      _processingTimer?.cancel();
      final recorder = isTest
          ? ref.read(mockRecorderProvider.notifier)
          : ref.read(recorderProvider.notifier);
      await recorder.stopStreaming();

      _vad?.flush();
      if (_vad != null) {
        while (!_vad!.isEmpty()) {
          final segment = _vad!.front();
          final samples = segment.samples;
          final audioData = convertFloat32ToBytes(samples);

          // Handle differently based on model type
          if (_model is OnlineModel) {
            final result = _model.processAudio(audioData, sampleRate);
            _updateTranscript(result);
          } else {
            _rollingCache.addChunk(audioData);
          }

          _vad!.pop();
        }
      }

      // For offline models, we need to process any remaining audio in the cache
      if (_model is! OnlineModel) {
        _processCache();
      } else {
        // For online models, finalize any pending transcription
        // This might involve sending a final chunk of silence or
        // checking if the model has any pending text
        final onlineModel = _model;
        // Optional: send a small silence buffer to finalize any pending transcription
        final silenceBuffer = Float32List(sampleRate ~/ 4); // ~250ms of silence
        final result = onlineModel.processAudio(
            convertFloat32ToBytes(silenceBuffer), sampleRate);
        if (result.trim().isNotEmpty) {
          _updateTranscript(result);
        }
        onlineModel.finalizeDecoding();
        _resetOnlineModel();
      }

      await recorder.stopRecorder();
      _rollingCache.clear();

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

  void _updateTranscript(String newText) {
    if (newText.trim().isEmpty) return;

    if (_model is OnlineModel) {
      // For online models, replace the transcript since they return the full text
      state = state.copyWith(
        currentChunkText: newText,
        fullTranscript: newText.trim(),
      );
    } else {
      // For offline models, append as before
      final combinedText = '${state.fullTranscript} $newText'.trim();
      state = state.copyWith(
        currentChunkText: newText,
        fullTranscript: combinedText,
      );
    }
  }

  @override
  void dispose() {
    _rollingCache.clear();
    _vad?.free();
    super.dispose();
  }
}

final dictationBenchmarkProvider =
    StateNotifierProvider.family<DictationNotifier, DictationState, AsrModel>(
  (ref, model) {
    // Inject the dependency via a callback.
    final testFiles = TestFiles(
      getFileDuration: (wavFile, sampleRate) async {
        final recorder = ref.read(mockRecorderProvider.notifier);
        await recorder.setAudioFile(wavFile);
        await recorder.initialize(sampleRate: sampleRate);
        return recorder.getAudioDuration();
      },
    );
    return DictationNotifier(
      ref: ref,
      model: model,
      testFiles: testFiles,
    );
  },
);

final dictationProvider =
    StateNotifierProvider.family<DictationNotifier, DictationState, AsrModel>(
  (ref, model) =>
      DictationNotifier(ref: ref, model: model, testFiles: TestFiles()),
);
