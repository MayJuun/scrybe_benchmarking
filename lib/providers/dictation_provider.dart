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

  // Instead of writing to a file, we store chunks in memory
  final List<Uint8List> _audioChunks = [];

  Timer? _stopTimer;

  DictationNotifier({
    required this.ref,
    required this.model,
    this.sampleRate = 16000,
  }) : super(const DictationState());

  Future<void> startDictation() async {
    if (state.status == DictationStatus.recording) return;

    try {
      state = state.copyWith(status: DictationStatus.recording, transcript: '');

      _audioChunks.clear(); // ensure empty at start

      // Start recorder
      final recorder = ref.read(recorderProvider.notifier);
      await recorder.initialize(sampleRate: sampleRate);
      await recorder.startRecorder();
      await recorder.startStreaming(_onAudioData);

      // Auto-stop after 10s (remove if you want manual stop)
      _stopTimer?.cancel();
      _stopTimer = Timer(const Duration(seconds: 10), stopDictation);
    } catch (e) {
      state = state.copyWith(
        status: DictationStatus.error,
        errorMessage: 'Failed to start: $e',
      );
    }
  }

  void _onAudioData(Uint8List audioData) {
    // Collect all raw PCM chunks in memory
    _audioChunks.add(audioData);
  }

  Future<void> stopDictation() async {
    if (state.status != DictationStatus.recording) return;

    try {
      _stopTimer?.cancel();
      _stopTimer = null;

      // Stop recorder
      final recorder = ref.read(recorderProvider.notifier);
      await recorder.stopStreaming();
      await recorder.stopRecorder();

      // Combine all chunks into one Uint8List
      final totalBytes = _audioChunks.fold<int>(0, (sum, c) => sum + c.length);
      final rawBytes = Uint8List(totalBytes);

      int offset = 0;
      for (final chunk in _audioChunks) {
        rawBytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      // Convert 16-bit PCM to float32
      final float32 = _convertBytesToFloat32(rawBytes);

      // Use the OfflineRecognizer from your OfflineModel
      final recognizer = model.recognizer;
      final stream = recognizer.createStream();

      // Feed the in-memory float data
      stream.acceptWaveform(samples: float32, sampleRate: sampleRate);
      recognizer.decode(stream);

      final result = recognizer.getResult(stream);
      stream.free();
      recognizer.free();

      state = state.copyWith(
        status: DictationStatus.idle,
        transcript: result.text,
      );
    } catch (e) {
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
    super.dispose();
  }
}

final dictationProvider =
    StateNotifierProvider.family<DictationNotifier, DictationState, OfflineModel>(
  (ref, model) => DictationNotifier(ref: ref, model: model),
);
