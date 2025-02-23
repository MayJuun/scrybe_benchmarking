import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

/// Uses an [OfflineModel], which presumably has an [OfflineRecognizer]
/// you can retrieve via [model.recognizer].
class DictationBenchmarkNotifier extends StateNotifier<DictationState> {
  final Ref ref;
  final ModelBase model;
  final int sampleRate;
  late final TranscriptionCombiner _transcriptionCombiner =
      TranscriptionCombiner(config: TranscriptionConfig());

  late final RollingCache _audioCache;
  Timer? _chunkTimer;

  // Add these for managing test files
  final List<String> _testFiles = [];
  int _currentFileIndex = -1;
  Completer<void>? _processingCompleter;

  DictationBenchmarkNotifier({
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

  Future<void> loadTestFiles() async {
    try {
      // This will get the manifest which includes all assets
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifest);

      // Filter for WAV files in your test directory
      _testFiles.addAll(manifestMap.keys
          .where((String key) =>
              key.startsWith('assets/dictation_test/test_files/') &&
              key.endsWith('.wav'))
          .toList());

      _currentFileIndex = 0;
      print('Loaded ${_testFiles.length} test files');
    } catch (e) {
      print('Error loading test files: $e');
      _testFiles.clear();
      _currentFileIndex = -1;
    }
  }

  Future<void> startDictation() async {
    if (state.status == DictationStatus.recording) return;

    // Initialize the completer if this is the first file for the current model
    _processingCompleter ??= Completer<void>();

    // Load files if not already loaded
    if (_testFiles.isEmpty) {
      await loadTestFiles();
    }

    if (_testFiles.isEmpty || _currentFileIndex >= _testFiles.length) {
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'No test files available',
      );
      return;
    }

    try {
      state =
          state.copyWith(status: DictationStatus.recording, fullTranscript: '');
      _audioCache.clear();

      final recorder = ref.read(mockRecorderProvider.notifier);
      await recorder.setAudioFile(_testFiles[_currentFileIndex]);
      await recorder.initialize(sampleRate: sampleRate);
      await recorder.startRecorder();

      // Start streaming and provide the onComplete callback
      await recorder.startStreaming(
        _onAudioData,
        onComplete: _onFileComplete,
      );

      _chunkTimer?.cancel();
      _chunkTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _processChunk();
      });

      print(
          'Processing file ${_currentFileIndex + 1}/${_testFiles.length}: ${_testFiles[_currentFileIndex]}');
    } catch (e) {
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Failed to start: $e',
      );
      print('Error during dictation start: $e');
    }
    return _processingCompleter!.future;
  }

  Future<void> _onFileComplete() async {
    // Stop the current dictation process
    await stopDictation();

    // Move to the next file if available
    if (_currentFileIndex < _testFiles.length - 1) {
      _currentFileIndex++;
      await startDictation();
    } else {
      print('All test files processed.');
      state = state.copyWith(status: DictationStatus.idle);
      // Complete the completer so that the Future returned by startDictation resolves
      _processingCompleter?.complete();
      _processingCompleter = null;
    }
  }

  void _onAudioData(Uint8List audioData) {
    if (state.status != DictationStatus.recording) return;

    try {
      _audioCache.addChunk(audioData);
    } catch (e) {
      print('Error processing audio data chunk: $e');
    }
  }

  void _processChunk() {
    if (_audioCache.isEmpty) return;

    try {
      final audioData = _audioCache.getData();
      final transcriptionResult = model.processAudio(audioData, sampleRate);
      final combinedText = _transcriptionCombiner.combineTranscripts(
          state.fullTranscript, transcriptionResult);

      state = state.copyWith(
        status: DictationStatus.recording,
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

  Future<void> stopDictation() async {
    if (state.status != DictationStatus.recording) return;

    try {
      _chunkTimer?.cancel();
      _chunkTimer = null;

      // Process any remaining audio
      if (_audioCache.isNotEmpty) {
        _processChunk();
      }

      // Stop recorder
      final recorder = ref.read(mockRecorderProvider.notifier);
      await recorder.stopStreaming();
      await recorder.stopRecorder();

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
    _chunkTimer?.cancel();
    _audioCache.clear();
    super.dispose();
  }
}

final dictationBenchmarkProvider = StateNotifierProvider.family<
    DictationBenchmarkNotifier, DictationState, ModelBase>(
  (ref, model) => DictationBenchmarkNotifier(ref: ref, model: model),
);
