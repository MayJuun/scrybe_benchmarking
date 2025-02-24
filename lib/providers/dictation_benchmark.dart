import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

/// Uses a [ModelBase] (either [OnlineModel] or [OfflineModel]) to process audio
/// from test WAV files, simulating real-life dictation (online) or doing batch
/// decoding (offline).
class DictationBenchmarkNotifier extends StateNotifier<DictationState> {
  final Ref ref;
  final ModelBase model;
  final int sampleRate;
  late final TranscriptionCombiner _transcriptionCombiner =
      TranscriptionCombiner(config: TranscriptionConfig());

  // Used only for offline models: we accumulate raw audio in small chunks.
  late final RollingCache _audioCache;
  Timer? _chunkTimer;

  // File management
  final List<String> _testFiles = [];
  final Map<String, String> _referenceTranscripts = {};
  final Map<String, int> _fileDurations = {};
  int _currentFileIndex = -1;
  Completer<void>? _processingCompleter;

  // Timing
  Stopwatch? processingStopwatch;
  Duration _accumulatedProcessingTime = Duration.zero;

  // Collect metrics from each file
  final List<BenchmarkMetrics> _allMetrics = [];

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

  /// Load test WAV + SRT transcripts from assets, store them in memory
  /// so we can run one after another.
  Future<void> loadTestFiles() async {
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifest);

      // Filter for `assets/dictation_test/test_files/*.wav`
      _testFiles.addAll(
        manifestMap.keys
            .where((String key) =>
                key.startsWith('assets/dictation_test/test_files/') &&
                key.endsWith('.wav'))
            .toList(),
      );

      // Load transcripts (SRT files) and measure WAV durations
      for (final wavFile in _testFiles) {
        final srtFile = wavFile.replaceAll('.wav', '.srt');
        try {
          final srtContent = await rootBundle.loadString(srtFile);
          _referenceTranscripts[wavFile] = _stripSrt(srtContent);
        } catch (e) {
          // If no SRT file, store empty reference
          _referenceTranscripts[wavFile] = '';
        }

        // Prepare the mock recorder so we can measure the file length
        final recorder = ref.read(mockRecorderProvider.notifier);
        await recorder.setAudioFile(wavFile);
        await recorder.initialize(sampleRate: sampleRate);
        _fileDurations[wavFile] = recorder.getAudioDuration();
      }

      _currentFileIndex = 0;
      print('Loaded ${_testFiles.length} test files with '
          '${_referenceTranscripts.length} transcripts');
    } catch (e) {
      print('Error loading test files: $e');
      _testFiles.clear();
      _currentFileIndex = -1;
    }
  }

  /// Convert SRT text to a simple raw transcript (remove timestamps, indexes).
  String _stripSrt(String text) {
    final lines = text.split('\n');
    final sb = StringBuffer();
    for (final l in lines) {
      final trimmed = l.trim();
      if (trimmed.isEmpty) continue;
      // Skip lines that are just numbers or contain `-->`
      if (RegExp(r'^\d+$').hasMatch(trimmed)) continue;
      if (trimmed.contains('-->')) continue;
      sb.write('$trimmed ');
    }
    return sb.toString().trim();
  }

  /// Start a dictation “run” for the current file. If called repeatedly,
  /// it processes all files in `_testFiles` in sequence.
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
      // Clear state, get ready to record
      state =
          state.copyWith(status: DictationStatus.recording, fullTranscript: '');
      _audioCache.clear();

      final recorder = ref.read(mockRecorderProvider.notifier);

      // Prepare recorder for the next file
      await recorder.setAudioFile(_testFiles[_currentFileIndex]);
      await recorder.initialize(sampleRate: sampleRate);
      await recorder.startRecorder();

      // If this is an online model, create a new stream
      if (model is OnlineModel) {
        if (!(model as OnlineModel).createStream()) {
          state = state.copyWith(
            status: DictationStatus.error,
            errorMessage: 'Failed to create online stream',
          );
          return;
        }
      }

      // Start streaming from our mock recorder
      // We supply `_onAudioData` for chunk callbacks, plus `_onFileComplete`
      await recorder.startStreaming(
        _onAudioData,
        onComplete: _onFileComplete,
      );

      // If offline, set up a periodic timer to batch decode
      if (model is OfflineModel) {
        _chunkTimer?.cancel();
        _chunkTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          _processChunk(); // decode 1-second chunks
        });
      }

      print('Processing file ${_currentFileIndex + 1}/${_testFiles.length}: '
          '${_testFiles[_currentFileIndex]}');
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
  /// For offline models, we just accumulate audio in `_audioCache`.
  void _onAudioData(Uint8List audioData) {
    if (state.status != DictationStatus.recording) return;

    try {
      if (model is OnlineModel) {
        // Online: decode right away
        processingStopwatch = Stopwatch()..start();
        final recognizedText = model.processAudio(audioData, sampleRate);
        processingStopwatch?.stop();
        _accumulatedProcessingTime +=
            processingStopwatch?.elapsed ?? Duration.zero;

        if (recognizedText.isNotEmpty) {
          // We must check if the model signaled an endpoint (final) or just partial
          final onlineModel = (model as OnlineModel);
          final isEndpoint =
              onlineModel.recognizer.isEndpoint(onlineModel.stream!);

          if (isEndpoint) {
            // This recognizedText is final for that “segment”
            // Append it to the full transcript
            final oldTranscript = state.fullTranscript;
            final newTranscript = oldTranscript.isEmpty
                ? recognizedText
                : '$oldTranscript $recognizedText';

            state = state.copyWith(
              currentChunkText: recognizedText,
              fullTranscript: newTranscript,
            );
          } else {
            // Just a partial. Update UI with the partial text, do not overwrite final
            state = state.copyWith(currentChunkText: recognizedText);
          }
        }
      } else {
        // Offline model: accumulate raw data
        _audioCache.addChunk(audioData);
      }
    } catch (e) {
      print('Error processing audio data chunk: $e');
    }
  }

  /// Only for offline: process the RollingCache audio (e.g., every 1s).
  /// We decode the entire cache, then combine transcripts.
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
        state.fullTranscript,
        transcriptionResult,
      );
      // print('Partial text: $combinedText');

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

  /// Called automatically once the WAV file finishes streaming to the model.
  Future<void> _onFileComplete() async {
    final currentFile = _testFiles[_currentFileIndex];

    // For online, get final text before stopping
    if (model is OnlineModel) {
      final finalText = (model as OnlineModel).finalizeAndGetResult();
      if (finalText.isNotEmpty) {
        state = state.copyWith(fullTranscript: finalText);
        print('Updated final transcript: $finalText');
      }
    }

    // Gather metrics for this file
    final metrics = BenchmarkMetrics.create(
      modelName: model.modelName,
      modelType: model is OnlineModel ? 'online' : 'offline',
      wavFile: currentFile,
      transcription: state.fullTranscript,
      reference: _referenceTranscripts[currentFile] ?? '',
      processingDuration: _accumulatedProcessingTime,
      audioLengthMs: _fileDurations[currentFile] ?? 0,
    );

    print('Creating metrics with transcript: ${state.fullTranscript}');
    _allMetrics.add(metrics);

    await stopDictation();

    // Reset timing
    _accumulatedProcessingTime = Duration.zero;
    processingStopwatch = null;

    // Move on to next file
    if (_currentFileIndex < _testFiles.length - 1) {
      _currentFileIndex++;
      await startDictation();
    } else {
      print('All test files processed for ${model.modelName}');
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
      // Stop periodic chunk processing
      _chunkTimer?.cancel();
      _chunkTimer = null;

      // For offline, process anything left in the cache
      if (model is OfflineModel && _audioCache.isNotEmpty) {
        _processChunk();
      }

      // For online, finalize the last chunk of decoding
      if (model is OnlineModel) {
        final finalText = (model as OnlineModel).finalizeAndGetResult();
        if (finalText.isNotEmpty) {
          // Append to full transcript in case we missed leftover partial
          final oldTranscript = state.fullTranscript;
          final newTranscript =
              oldTranscript.isEmpty ? finalText : '$oldTranscript $finalText';

          // print('Final text: $finalText');

          state = state.copyWith(fullTranscript: newTranscript);
        }
      }

      // Stop the recorder entirely
      final recorder = ref.read(mockRecorderProvider.notifier);
      await recorder.stopStreaming();
      await recorder.stopRecorder();

      // Clear any leftover
      _audioCache.clear();

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
    _chunkTimer?.cancel();
    _audioCache.clear();
    super.dispose();
  }
}

final dictationBenchmarkProvider = StateNotifierProvider.family<
    DictationBenchmarkNotifier, DictationState, ModelBase>(
  (ref, model) => DictationBenchmarkNotifier(ref: ref, model: model),
);
