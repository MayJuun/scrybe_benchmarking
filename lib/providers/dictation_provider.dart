import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

enum DictationStatus { idle, recording, error }

class DictationState {
  final DictationStatus status;
  final String? errorMessage;
  final String transcript;

  const DictationState({
    this.status = DictationStatus.idle,
    this.errorMessage,
    this.transcript = '',
  });

  DictationState copyWith({
    DictationStatus? status,
    String? errorMessage,
    String? transcript,
  }) {
    return DictationState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      transcript: transcript ?? this.transcript,
    );
  }
}

/// Uses an [OfflineModel], which presumably has an [OfflineRecognizer]
/// you can retrieve via [model.recognizer].
class DictationNotifier extends StateNotifier<DictationState> {
  final Ref ref;
  final OfflineModel model;
  final int sampleRate;

  final List<Uint8List> _audioChunks = [];
  OfflineStream? _currentStream;

  Timer? _stopTimer;
  Timer? _chunkTimer;

  DictationNotifier({
    required this.ref,
    required this.model,
    this.sampleRate = 16000,
  }) : super(const DictationState());

  Future<void> startDictation() async {
    if (state.status == DictationStatus.recording) return;

    try {
      state = state.copyWith(status: DictationStatus.recording, transcript: '');
      _audioChunks.clear();

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
      _stopTimer = Timer(const Duration(seconds: 10), stopDictation);

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
      _audioChunks.add(audioData);
    } catch (e) {
      print('Error processing audio data chunk: $e');
    }
  }

  void _processChunk() {
    if (_currentStream == null || _audioChunks.isEmpty) return;

    try {
      // Combine chunks into one
      final totalBytes = _audioChunks.fold<int>(0, (sum, c) => sum + c.length);
      final rawBytes = Uint8List(totalBytes);

      int offset = 0;
      for (final chunk in _audioChunks) {
        rawBytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      print('Processing chunk of size: ${rawBytes.length} bytes');

      // Convert to float32 and process
      final float32 = _convertBytesToFloat32(rawBytes);
      _currentStream!.acceptWaveform(samples: float32, sampleRate: sampleRate);
      model.recognizer.decode(_currentStream!);

      final result = model.recognizer.getResult(_currentStream!);
      print('Processed chunk: ${result.text}');

      state = state.copyWith(
        status: DictationStatus.recording,
        transcript: result.text,
      );

      _audioChunks.clear();
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
      _stopTimer?.cancel();
      _stopTimer = null;
      _chunkTimer?.cancel();
      _chunkTimer = null;

      // Process any remaining audio
      if (_audioChunks.isNotEmpty) {
        _processChunk();
      }

      // Stop recorder
      final recorder = ref.read(recorderProvider.notifier);
      await recorder.stopStreaming();
      await recorder.stopRecorder();

      // Clean up stream
      _currentStream?.free();
      _currentStream = null;

      state = state.copyWith(status: DictationStatus.idle);
    } catch (e) {
      print('Error stopping dictation: $e');
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Stop error: $e',
      );
    }
  }

  /// Convert raw 16-bit mono PCM bytes to Float32List in [-1..1]
  Float32List _convertBytesToFloat32(Uint8List bytes) {
    final length = bytes.length ~/ 2;
    final data = ByteData.sublistView(bytes);

    final floats = Float32List(length);
    for (int i = 0; i < length; i++) {
      final sample = data.getInt16(i * 2, Endian.little);
      floats[i] = sample / 32768.0;
    }
    return floats;
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _chunkTimer?.cancel();
    _currentStream?.free();
    super.dispose();
  }
}

final dictationProvider = StateNotifierProvider.family<DictationNotifier,
    DictationState, OfflineModel>(
  (ref, model) => DictationNotifier(ref: ref, model: model),
);
