import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class DictationBenchmarkNotifier extends DictationNotifier {
  DictationBenchmarkNotifier({
    required super.ref,
    required super.model,
    super.sampleRate,
  });

  // Benchmark-specific fields
  AudioTestFiles? _testFiles;
  final List<BenchmarkMetrics> _allMetrics = [];
  Stopwatch? _processingStopwatch;
  Duration _accumulatedProcessingTime = Duration.zero;
  Completer<void>? _processingCompleter;

  /// Metrics are stored in `_allMetrics`.
  List<BenchmarkMetrics> get metrics => List.unmodifiable(_allMetrics);

  void setTestFiles(AudioTestFiles files) {
    _testFiles = files;
  }

  @override
  Future<void> startDictation() async {
    if (_testFiles == null) {
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Test files not set',
      );
      return;
    }
    if (state.status == DictationStatus.recording) return;

    _processingCompleter ??= Completer<void>();
    if (_testFiles!.isEmpty ||
        _testFiles!.currentFileIndex >= _testFiles!.length) {
      state = state.copyWith(
          status: DictationStatus.error,
          errorMessage: 'No test files available');
      return;
    }

    try {
      state =
          state.copyWith(status: DictationStatus.recording, fullTranscript: '');
      service.clearCache();

      final recorder = ref.read(fileRecorderProvider.notifier);
      await recorder.setAudioFile(_testFiles!.currentFile);
      await recorder.initialize(sampleRate: sampleRate);
      await recorder.startRecorder();
      await recorder.startStreaming(onAudioData, onComplete: _onFileComplete);

      // Set up timer for offline models
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

    return _processingCompleter!.future;
  }

  void _processCache() {
    try {
      final audioData = service.getCacheData();

      // Start timing for benchmark
      _processingStopwatch = Stopwatch()..start();

      final transcriptionResult =
          service.processOfflineAudio(audioData, model, sampleRate);

      // Stop timing and accumulate
      _processingStopwatch?.stop();
      _accumulatedProcessingTime +=
          _processingStopwatch?.elapsed ?? Duration.zero;

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

  Future<void> _onFileComplete() async {
    if (_testFiles == null) {
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Test files not set',
      );
      return;
    }
    await stopDictation(fileRecorderProvider);

    // Collect metrics
    final metrics = BenchmarkMetrics.create(
      modelName: model.modelName,
      modelType: model is OnlineModel ? 'online' : 'offline',
      wavFile: _testFiles!.currentFile,
      transcription: state.fullTranscript,
      reference: _testFiles!.currentReferenceTranscript ?? '',
      processingDuration: _accumulatedProcessingTime,
      audioLengthMs: _testFiles!.currentFileDuration ?? 0,
    );

    _allMetrics.add(metrics);

    // Reset timing
    _accumulatedProcessingTime = Duration.zero;
    _processingStopwatch = null;

    // Move to next file or complete
    if (_testFiles!.currentFileIndex < _testFiles!.length - 1) {
      _testFiles!.currentFileIndex++;
      await startDictation();
    } else {
      state = state.copyWith(status: DictationStatus.idle);
      _processingCompleter?.complete();
      _processingCompleter = null;
    }
  }
}

final dictationBenchmarkProvider = StateNotifierProvider.family<
    DictationBenchmarkNotifier, DictationBenchmarkState, AsrModel>(
  (ref, model) => DictationBenchmarkNotifier(ref: ref, model: model),
);
