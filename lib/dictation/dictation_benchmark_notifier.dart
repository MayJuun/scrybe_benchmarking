import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class DictationBenchmarkNotifier
    extends DictationNotifier<DictationBenchmarkState> {
  DictationBenchmarkNotifier({
    required super.ref,
    required super.model,
    super.sampleRate,
  }) : super(state: DictationBenchmarkState());

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
    vad ??= await loadSileroVad();

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

      lastProcessingTime = DateTime.now();
      final recorder = ref.read(fileRecorderProvider.notifier);
      await recorder.setAudioFile(_testFiles!.currentFile);
      await recorder.initialize(sampleRate: sampleRate);
      await recorder.startRecorder();
      await recorder.startStreaming(onAudioData, onComplete: _onFileComplete);

      // Set up timer for offline models
      if (model is! OnlineModel) {
        if (vad == null) {
          processingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
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
      );
      print('Error during dictation start: $e');
    }

    return _processingCompleter!.future;
  }

  @override
  void onAudioData(Uint8List audioData) {
    if (state.status != DictationStatus.recording) return;

    try {
      // For online models, process audio directly with timing
      if (model is OnlineModel) {
        _processingStopwatch = Stopwatch()..start();
        final result = service.processOnlineAudio(audioData, model, sampleRate);
        _processingStopwatch?.stop();
        _accumulatedProcessingTime +=
            _processingStopwatch?.elapsed ?? Duration.zero;
        updateTranscript(result);
        return;
      } else {
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
      final minBytes = 16000 * 2 * 1; // 1 second
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

      // Start timing for benchmark
      _processingStopwatch = Stopwatch()..start();
      String transcriptionResult;

      try {
        transcriptionResult =
            service.processOfflineAudio(audioData, model, sampleRate);
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

      // Stop timing and accumulate
      _processingStopwatch?.stop();
      _accumulatedProcessingTime +=
          _processingStopwatch?.elapsed ?? Duration.zero;

      // Use TranscriptCombiner to combine the text
      final combinedText = service.updateTranscriptByModelType(
        state.fullTranscript,
        transcriptionResult,
        model,
      );

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
    print(state.fullTranscript);

    // Collect metrics
    if (_accumulatedProcessingTime.inMilliseconds > 0 &&
        (_testFiles?.currentFileDuration ?? 0) > 0) {
      final metrics = BenchmarkMetrics.create(
        modelName: model.modelName,
        modelType: model is OnlineModel ? 'online' : 'offline',
        wavFile: _testFiles!.currentFile,
        transcription: state.fullTranscript,
        reference: _testFiles!.currentReferenceTranscript ?? '',
        processingDuration: _accumulatedProcessingTime,
        audioLengthMs:
            _testFiles!.currentFileDuration ?? 1, // Use 1 as a minimum
      );

      _allMetrics.add(metrics);
    } else {
      print('Skipping metrics - invalid timing data');
    }

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
