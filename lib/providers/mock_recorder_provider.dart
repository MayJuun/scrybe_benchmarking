import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class MockRecorderNotifier extends RecorderNotifier {
  String? _audioFilePath;
  Uint8List? _audioData;
  Timer? _audioTimer;
  StreamController<Uint8List>? _audioController;

  final int chunkSize = 960; // 30ms of audio at 16kHz, 16-bit
  final int bytesPerSample = 2; // 16-bit audio = 2 bytes per sample
  final Duration frameInterval =
      const Duration(milliseconds: 30); // Standard frame size
  int? _durationMs;

  MockRecorderNotifier();

  Future<void> setAudioFile(String path, {int sampleRate = 16000}) async {
    // Cancel any ongoing operations
    await stopRecorder();
    _audioTimer?.cancel();
    await _audioController?.close();

    // Reset state
    _audioFilePath = path;
    _audioData = null;
    state = const RecorderState();
  }

  @override
  Future<void> initialize({int sampleRate = 16000}) async {
    if (_audioFilePath == null) {
      state = state.copyWith(
          status: RecorderStatus.error, errorMessage: 'Audio file not set');
      return;
    }

    try {
      // Load the audio data during initialization
      _audioData = await _readWavFile();

      state = state.copyWith(
          status: RecorderStatus.initialized, isInitialized: true);
    } catch (e) {
      state = state.copyWith(
          status: RecorderStatus.error,
          errorMessage: 'Failed to initialize mock recorder: $e');
    }
  }

  @override
  Future<void> startRecorder() async {
    if (!state.isInitialized || _audioData == null) {
      state = state.copyWith(
          status: RecorderStatus.error,
          errorMessage: 'Mock recorder not initialized or no audio data');
      return;
    }

    try {
      _audioController = StreamController<Uint8List>.broadcast();

      state = state.copyWith(status: RecorderStatus.ready, isStarted: true);
    } catch (e) {
      state = state.copyWith(
          status: RecorderStatus.error,
          errorMessage: 'Failed to start mock recorder: $e');
    }
  }

  @override
  Future<void> startStreaming(
    void Function(Uint8List) onAudioData, {
    void Function()? onComplete,
  }) async {
    if (!state.isStarted || _audioData == null) {
      state = state.copyWith(
          status: RecorderStatus.error,
          errorMessage: 'Mock recorder not started or no audio data');
      return;
    }

    try {
      int position = 0;
      DateTime lastChunkTime = DateTime.now();

      void processChunk(Timer timer) {
        if (position >= _audioData!.length) {
          timer.cancel();
          // Notify that the file is complete.
          if (onComplete != null) onComplete();
          return;
        }

        // Calculate timing drift
        final now = DateTime.now();
        final actualInterval = now.difference(lastChunkTime);
        final drift =
            frameInterval.inMicroseconds - actualInterval.inMicroseconds;

        if (drift.abs() > 1000) {
          timer.cancel();
          _audioTimer = Timer.periodic(
            frameInterval + Duration(microseconds: drift ~/ 2),
            processChunk,
          );
        }

        final end = (position + chunkSize).clamp(0, _audioData!.length);
        final chunk = _audioData!.sublist(position, end);
        onAudioData(chunk);

        position = end;
        lastChunkTime = now;
      }

      _audioTimer = Timer.periodic(frameInterval, processChunk);

      state =
          state.copyWith(status: RecorderStatus.streaming, isStreaming: true);
    } catch (e) {
      state = state.copyWith(
          status: RecorderStatus.error,
          errorMessage: 'Failed to start streaming: $e');
    }
  }

  @override
  Future<void> stopStreaming() async {
    if (!state.isStreaming) return;

    try {
      _audioTimer?.cancel();
      await _audioController?.close();
      _audioController = null;

      state = state.copyWith(status: RecorderStatus.ready, isStreaming: false);
    } catch (e) {
      state = state.copyWith(
          status: RecorderStatus.error,
          errorMessage: 'Failed to stop streaming: $e');
    }
  }

  @override
  Future<void> stopRecorder() async {
    if (!state.isStarted) return;

    try {
      if (state.isStreaming) {
        await stopStreaming();
      }

      state =
          state.copyWith(status: RecorderStatus.initialized, isStarted: false);
    } catch (e) {
      state = state.copyWith(
          status: RecorderStatus.error,
          errorMessage: 'Failed to stop mock recorder: $e');
    }
  }

  @override
  Stream<Uint8List> get audioStream =>
      _audioController?.stream ?? const Stream.empty();

  Future<Uint8List> _readWavFile() async {
    print('Loading WAV file from asset: $_audioFilePath');
    final data = await rootBundle.load(_audioFilePath!);
    final allBytes = data.buffer.asUint8List();
    if (allBytes.length < 44) {
      throw Exception('WAV file too small or invalid header: $_audioFilePath');
    }
    final pcmBytes = allBytes.sublist(44); // Skip WAV header
    _durationMs = _estimateAudioMs(pcmBytes.length);
    return pcmBytes;
  }

  int _estimateAudioMs(int numBytes) {
    // 16-bit => 2 bytes per sample, 16 kHz => 16000 samples/sec
    final sampleCount = numBytes ~/ 2;
    return (sampleCount * 1000) ~/ 16000;
  }

  // Simple getter for the duration
  int getAudioDuration() => _durationMs ?? 0;

  @override
  void dispose() async {
    _audioTimer?.cancel();
    await _audioController?.close();
    super.dispose();
  }
}

final mockRecorderProvider =
    StateNotifierProvider<MockRecorderNotifier, RecorderState>((ref) {
  return MockRecorderNotifier();
});
