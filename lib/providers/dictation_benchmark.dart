// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// Uses a [ModelBase] (either [OnlineModel] or [OfflineModel]) to process audio
/// from test WAV files, simulating real-life dictation (online) or doing batch
/// decoding (offline).
class DictationBenchmarkNotifier extends StateNotifier<DictationState> {
  final Ref ref;

  // sherpa_onnx objects
  final ModelBase _model;
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
    required ModelBase model,
    this.sampleRate = 16000,
    required TestFiles testFiles,
  })  : _testFiles = testFiles,
        _model = model,
        super(const DictationState()) {
    _rollingCache = RollingCache(
      sampleRate: sampleRate,
      bitDepth: 2,
      durationSeconds: model is OfflineModel ? (model).cacheSize : 10,
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

      // If this is an online model, create a new stream
      if (_model is OnlineModel) {
        if (!(_model).createStream()) {
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

        // Only proceed if we are using an offline model.
        if (_model is OfflineModel) {
          final recognizer = _model.recognizer;
         // Use the recognizer inside the offline model.
          final asrStream = recognizer.createStream();
          asrStream.acceptWaveform(samples: samples, sampleRate: sampleRate);
          recognizer.decode(asrStream);
          final result = recognizer.getResult(asrStream);
          asrStream.free();

          // Merge this segment's transcript with the existing full transcript.
          final combinedText = _transcriptionCombiner.combineTranscripts(
            state.fullTranscript,
            result.text,
          );
          state = state.copyWith(
            currentChunkText: result.text,
            fullTranscript: combinedText,
          );
        }

        // Remove the processed segment from the VAD buffer.
        _vad.pop();
      }
    } catch (e) {
      print('Error processing audio data chunk with VAD: $e');
    }
  }

  /// Only for offline: process the RollingCache audio (e.g., every 1s).
  /// We decode the entire cache, then combine transcripts.
  void _processChunk() {
    if (_model is! OfflineModel) return;
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
    // Flush the VAD to force it to output any pending speech segments.
    _vad.flush();

    // Process any remaining segments from the VAD.
    while (!_vad.isEmpty()) {
      final segment = _vad.front();
      final samples = segment.samples;
      final startTime = segment.start.toDouble() / sampleRate;
      final endTime = startTime + samples.length.toDouble() / sampleRate;

      // Use the recognizer from the OfflineModel to process this segment.
      if (_model is OfflineModel) {
        final offlineModel = _model;
        final asrStream = offlineModel.recognizer.createStream();
        asrStream.acceptWaveform(samples: samples, sampleRate: sampleRate);
        offlineModel.recognizer.decode(asrStream);
        final result = offlineModel.recognizer.getResult(asrStream);
        asrStream.free();

        print('Final VAD segment [$startTime - $endTime]: ${result.text}');

        final updatedTranscript = _transcriptionCombiner.combineTranscripts(
          state.fullTranscript,
          result.text,
        );
        state = state.copyWith(fullTranscript: updatedTranscript);
      } else {
        // If model is not OfflineModel, you may handle it differently.
        print('Model is not offline; skipping VAD segment processing.');
      }

      _vad.pop();
    }

    // Now process any remaining audio in the rolling cache (for offline models).
    if (_model is OfflineModel && _rollingCache.isNotEmpty) {
      final remainingAudio = _rollingCache.getData();
      if (remainingAudio.length >= sampleRate * 2) {
        // At least 1 second.
        print(
            'Final processing on remaining cache: ${remainingAudio.length} bytes');
        _processingStopwatch = Stopwatch()..start();
        final finalTranscription =
            _model.processAudio(remainingAudio, sampleRate);
        _processingStopwatch?.stop();
        _accumulatedProcessingTime +=
            _processingStopwatch?.elapsed ?? Duration.zero;
        final updatedTranscript = _transcriptionCombiner.combineTranscripts(
          state.fullTranscript,
          finalTranscription,
        );
        state = state.copyWith(fullTranscript: updatedTranscript);
        print('Updated final transcript (offline): "${state.fullTranscript}"');
      } else {
        print('Remaining audio cache too small to process.');
      }
    }

    // Collect metrics for this file.
    final currentFile = _testFiles.currentFile;
    final metrics = BenchmarkMetrics.create(
      modelName: _model.modelName,
      modelType: _model is OnlineModel ? 'online' : 'offline',
      wavFile: currentFile,
      transcription: state.fullTranscript,
      reference: _testFiles.currentReferenceTranscript ?? '',
      processingDuration: _accumulatedProcessingTime,
      audioLengthMs: _testFiles.currentFileDuration ?? 0,
    );
    print('Creating metrics with transcript: ${state.fullTranscript}');
    _allMetrics.add(metrics);

    // Stop the current dictation session (stop recorder, clear cache, etc.).
    await stopDictation();

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
      // For offline, process anything left in the cache
      if (_model is OfflineModel && _rollingCache.isNotEmpty) {
        _processChunk();
      }

      // For online, finalize the last chunk of decoding
      if (_model is OnlineModel) {
        final finalText = (_model).finalizeAndGetResult();
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
    DictationBenchmarkNotifier, DictationState, ModelBase>(
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
