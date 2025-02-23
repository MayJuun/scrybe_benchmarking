import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

/// Uses an [ModelBase], which presumably has an [OfflineRecognizer]
/// you can retrieve via [model.recognizer].
class DictationBenchmarkNotifier extends StateNotifier<DictationState> {
  final Ref ref;
  final ModelBase model;
  final int sampleRate;
  late final TranscriptionCombiner _transcriptionCombiner =
      TranscriptionCombiner(config: TranscriptionConfig());

  late final RollingCache _audioCache;
  Timer? _chunkTimer;

  // File management
  final List<String> _testFiles = [];
  final Map<String, String> _referenceTranscripts = {}; // Add this
  final Map<String, int> _fileDurations = {}; // Add this
  int _currentFileIndex = -1;
  Completer<void>? _processingCompleter;

  // Benchmark tracking
  Stopwatch? processingStopwatch;
  Duration _accumulatedProcessingTime = Duration.zero;

  DictationBenchmarkNotifier({
    required this.ref,
    required this.model,
    this.sampleRate = 16000,
  }) : super(const DictationState()) {
    _audioCache = RollingCache(
      sampleRate: sampleRate,
      bitDepth: 2,
      durationSeconds: 10,
    );
  }

  Future<void> loadTestFiles() async {
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifest);
      _testFiles.addAll(manifestMap.keys
          .where((String key) =>
              key.startsWith('assets/dictation_test/test_files/') &&
              key.endsWith('.wav'))
          .toList());

      for (final wavFile in _testFiles) {
        final srtFile = wavFile.replaceAll('.wav', '.srt');
        try {
          final srtContent = await rootBundle.loadString(srtFile);
          _referenceTranscripts[wavFile] = _stripSrt(srtContent);
        } catch (e) {
          print('Warning: No reference transcript found for $wavFile');
          _referenceTranscripts[wavFile] = '';
        }

        final recorder = ref.read(mockRecorderProvider.notifier);
        await recorder.setAudioFile(wavFile);
        await recorder.initialize(sampleRate: sampleRate);
        _fileDurations[wavFile] = recorder.getAudioDuration();
      }

      _currentFileIndex = 0;
      print(
          'Loaded ${_testFiles.length} test files with ${_referenceTranscripts.length} transcripts');
    } catch (e) {
      print('Error loading test files: $e');
      _testFiles.clear();
      _currentFileIndex = -1;
    }
  }

  String _stripSrt(String text) {
    final lines = text.split('\n');
    final sb = StringBuffer();
    for (final l in lines) {
      final trimmed = l.trim();
      if (trimmed.isEmpty) continue;
      if (RegExp(r'^\d+$').hasMatch(trimmed)) continue;
      if (trimmed.contains('-->')) continue;
      sb.write('$trimmed ');
    }
    return sb.toString().trim();
  }

  Future<void> startDictation() async {
    if (state.status == DictationStatus.recording) return;
    _processingCompleter ??= Completer<void>();

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

      // For online models, initialize their stream immediately.
      if (model is OnlineModel) {
        if (!(model as OnlineModel).createStream()) {
          state = state.copyWith(
            status: DictationStatus.error,
            errorMessage: 'Failed to create online stream',
          );
          return;
        }
      }

      // Start streaming and pass the onComplete callback.
      await recorder.startStreaming(
        _onAudioData,
        onComplete: _onFileComplete,
      );

      // For offline models, set up a periodic timer to process accumulated audio.
      if (model is OfflineModel) {
        _chunkTimer?.cancel();
        _chunkTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          _processChunk();
        });
      }

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

  // For each incoming chunk, process it immediately if online,
  // otherwise accumulate it.
  void _onAudioData(Uint8List audioData) {
    if (state.status != DictationStatus.recording) return;
    try {
      if (model is OnlineModel) {
        // Process the chunk right away.
        processingStopwatch = Stopwatch()..start();
        final transcriptionResult = model.processAudio(audioData, sampleRate);
        processingStopwatch?.stop();
        _accumulatedProcessingTime +=
            processingStopwatch?.elapsed ?? Duration.zero;

        if (transcriptionResult.isNotEmpty) {
          state = state.copyWith(
            currentChunkText: transcriptionResult,
            fullTranscript: transcriptionResult,
          );
        }
      } else {
        // Offline: accumulate in the rolling cache.
        _audioCache.addChunk(audioData);
      }
    } catch (e) {
      print('Error processing audio data chunk: $e');
    }
  }

  // Only used for offline models.
  void _processChunk() {
    if (model is! OfflineModel) return;
    if (_audioCache.isEmpty) return;

    try {
      final audioData = _audioCache.getData();

      processingStopwatch = Stopwatch()..start();
      final transcriptionResult = model.processAudio(audioData, sampleRate);
      processingStopwatch?.stop();
      _accumulatedProcessingTime +=
          processingStopwatch?.elapsed ?? Duration.zero;

      final combinedText = _transcriptionCombiner.combineTranscripts(
          state.fullTranscript, transcriptionResult);

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
    final currentFile = _testFiles[_currentFileIndex];
    
    final metrics = BenchmarkMetrics.create(
      modelName: model.modelName,
      modelType: model is OnlineModel ? 'online' : 'offline',
      wavFile: currentFile,
      transcription: state.fullTranscript,
      reference:
          _referenceTranscripts[currentFile] ?? '', // Use stored reference
      processingDuration: _accumulatedProcessingTime,
      audioLengthMs: _fileDurations[currentFile] ?? 0, // Use stored duration
    );

    print('File complete metrics:\n$metrics');

    // Stop the current dictation session
    await stopDictation();

    // Reset timing for next file
    _accumulatedProcessingTime = Duration.zero;
    processingStopwatch = null;

    // Move to next file if available
    if (_currentFileIndex < _testFiles.length - 1) {
      _currentFileIndex++;
      await startDictation();
    } else {
      print('All test files processed.');
      state = state.copyWith(status: DictationStatus.idle);
      _processingCompleter?.complete();
      _processingCompleter = null;
    }
  }

  Future<void> stopDictation() async {
    if (state.status != DictationStatus.recording) return;
    try {
      _chunkTimer?.cancel();
      _chunkTimer = null;

      // For offline models, process any remaining audio.
      if (model is OfflineModel && _audioCache.isNotEmpty) {
        _processChunk();
      }
      // For online models, finalize the stream.
      if (model is OnlineModel) {
        (model as OnlineModel).onRecordingStop();
      }

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
