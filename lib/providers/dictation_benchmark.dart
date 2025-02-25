// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// Uses an [OfflineModel] to process audio from test WAV files, simulating
/// real-life dictation (online) or doing batch decoding (offline).
class DictationBenchmarkNotifier extends StateNotifier<DictationState> {
  final Ref ref;

  // sherpa_onnx objects
  final OfflineModel _model;
  late final TranscriptionCombiner _transcriptionCombiner =
      TranscriptionCombiner(config: TranscriptionConfig());
  late final VoiceActivityDetector _vad;

  // Used only for offline _models: we accumulate raw audio in small chunks.
  late final RollingCache _rollingCache;
  final TestFiles _testFiles;

  // Timing
  Stopwatch? _processingStopwatch;
  Duration _accumulatedProcessingTime = Duration.zero;
  final int sampleRate;

  // Collect metrics from each file
  final List<BenchmarkMetrics> _allMetrics = [];
  Completer<void>? _processingCompleter;

  DictationBenchmarkNotifier({
    required this.ref,
    required OfflineModel model,
    this.sampleRate = 16000,
    required TestFiles testFiles,
  })  : _testFiles = testFiles,
        _model = model,
        super(const DictationState()) {
    _rollingCache = RollingCache(
      sampleRate: sampleRate,
      bitDepth: 2,
      durationSeconds: model.cacheSize,
    );
  }

  Future<void> init() async {
    if (_testFiles.isEmpty) {
      await _testFiles.loadTestFiles();
    }
    _vad = await loadSileroVad();
  }

  /// Start a dictation “run” for the current file. If called repeatedly,
  /// it processes all files in `_testFiles` in sequence.
  Future<void> startDictation() async {
    if (state.status == DictationStatus.recording) return;
    _processingCompleter ??= Completer<void>();

    if (_testFiles.isEmpty) {
      await _testFiles.loadTestFiles();
    }
    if (_testFiles.isEmpty ||
        _testFiles.currentFileIndex >= _testFiles.length) {
      state = state.copyWith(
          status: DictationStatus.error,
          errorMessage: 'No test files available');
      return;
    }

    try {
      // Clear state, get ready to record
      state =
          state.copyWith(status: DictationStatus.recording, fullTranscript: '');
      _rollingCache.clear();

      // Prepare recorder for the next file
      final recorder = ref.read(mockRecorderProvider.notifier);
      await recorder.setAudioFile(_testFiles.currentFile);
      await recorder.initialize(sampleRate: sampleRate);
      await recorder.startRecorder();

      // Start streaming from our mock recorder
      // We supply `_onAudioData` for chunk callbacks, plus `_onFileComplete`
      await recorder.startStreaming(
        _onAudioData,
        onComplete: _onFileComplete,
      );

      print('Processing file ${_testFiles.currentFileIndex + 1}'
          '/${_testFiles.length}: '
          '${_testFiles.currentFile}');
    } catch (e) {
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Failed to start: $e',
      );
      print('Error during dictation start: $e');
    }

    return _processingCompleter!.future;
  }

  /// This callback fires for **each chunk** of audio from the recorder.
  /// For online models, we decode immediately, producing partial or final text.
  /// For offline models, we just accumulate audio in `_rollingCache`.
  void _onAudioData(Uint8List audioData) {
    if (state.status != DictationStatus.recording) return;

    try {
      // Convert the incoming 16-bit PCM chunk to the expected Float32List format.
      final Float32List floatAudio = convertBytesToFloat32(audioData);
      // Feed the chunk into the VAD.
      _vad.acceptWaveform(floatAudio);
      // Process complete speech segments from the VAD.
      while (!_vad.isEmpty()) {
        final segment = _vad.front();
        final samples = segment.samples;
        _rollingCache.addSegment(samples);
        _vad.pop();
        _processCache();
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
      print(
          'Processing audio chunk of ${audioData.length} bytes (${audioData.length / (2 * sampleRate)} seconds)');

      _processingStopwatch = Stopwatch()..start();
      final transcriptionResult = _model.processAudio(audioData, sampleRate);
      _processingStopwatch?.stop();
      _accumulatedProcessingTime +=
          _processingStopwatch?.elapsed ?? Duration.zero;

      print('Current transcript before combining: "${state.fullTranscript}"');
      print('New transcription result: "$transcriptionResult"');

      final combinedText = _transcriptionCombiner.combineTranscripts(
        state.fullTranscript,
        transcriptionResult,
      );

      print('Combined transcript: "$combinedText"');

      state = state.copyWith(
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

  /// Metrics are stored in `_allMetrics`.
  List<BenchmarkMetrics> get metrics => List.unmodifiable(_allMetrics);

  /// Stop the dictation (stop streaming, do final decode, clean up).
  Future<void> stopDictation() async {
    if (state.status != DictationStatus.recording) return;

    try {
      // Stop the recorder entirely
      final recorder = ref.read(mockRecorderProvider.notifier);
      await recorder.stopStreaming();
      // Flush the VAD to force it to output any pending speech segments.
      _vad.flush();

      // Process any remaining segments from the VAD.
      while (!_vad.isEmpty()) {
        final segment = _vad.front();
        final samples = segment.samples;
        _rollingCache.addSegment(samples);
        _vad.pop();
        _processCache();
      }

      await recorder.stopRecorder();
      // Clear any leftover
      _rollingCache.clear();

      // Go idle
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
    _rollingCache.clear();
    super.dispose();
  }
}

final dictationBenchmarkProvider = StateNotifierProvider.family<
    DictationBenchmarkNotifier, DictationState, OfflineModel>(
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
    return DictationBenchmarkNotifier(
      ref: ref,
      model: model,
      testFiles: testFiles,
    );
  },
);
