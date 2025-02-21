import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class MockRecorderNotifier extends StateNotifier<RecorderState> {
  String? _audioFilePath;
  Uint8List? _audioData;
  Timer? _audioTimer;
  StreamController<Uint8List>? _audioController;
  final int chunkSize = 960; // 30ms of audio at 16kHz, 16-bit

  MockRecorderNotifier() : super(const RecorderState());

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

  Future<void> initialize({int sampleRate = 16000}) async {
    if (_audioFilePath == null) {
      state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: 'Audio file not set'
      );
      return;
    }

    try {
      // Load the audio data during initialization
      _audioData = await _readWavFile();
      
      state = state.copyWith(
        status: RecorderStatus.initialized,
        isInitialized: true
      );
    } catch (e) {
      state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: 'Failed to initialize mock recorder: $e'
      );
    }
  }

  Future<void> startRecorder() async {
    if (!state.isInitialized || _audioData == null) {
      state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: 'Mock recorder not initialized or no audio data'
      );
      return;
    }

    try {
      _audioController = StreamController<Uint8List>.broadcast();
      
      state = state.copyWith(
        status: RecorderStatus.ready,
        isStarted: true
      );
    } catch (e) {
      state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: 'Failed to start mock recorder: $e'
      );
    }
  }

  Future<void> startStreaming(void Function(Uint8List) onAudioData) async {
    if (!state.isStarted || _audioData == null) {
      state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: 'Mock recorder not started or no audio data'
      );
      return;
    }

    try {
      var position = 0;

      // Stream the audio data in chunks
      _audioTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
        if (position >= _audioData!.length) {
          timer.cancel();
          return;
        }

        final end = (position + chunkSize).clamp(0, _audioData!.length);
        final chunk = _audioData!.sublist(position, end);
        onAudioData(chunk);
        position = end;
      });

      state = state.copyWith(
        status: RecorderStatus.streaming,
        isStreaming: true
      );
    } catch (e) {
      state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: 'Failed to start streaming: $e'
      );
    }
  }

  Future<void> stopStreaming() async {
    if (!state.isStreaming) return;

    try {
      _audioTimer?.cancel();
      await _audioController?.close();
      _audioController = null;
      
      state = state.copyWith(
        status: RecorderStatus.ready,
        isStreaming: false
      );
    } catch (e) {
      state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: 'Failed to stop streaming: $e'
      );
    }
  }

  Future<void> stopRecorder() async {
    if (!state.isStarted) return;

    try {
      if (state.isStreaming) {
        await stopStreaming();
      }
      
      state = state.copyWith(
        status: RecorderStatus.initialized,
        isStarted: false
      );
    } catch (e) {
      state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: 'Failed to stop mock recorder: $e'
      );
    }
  }

  Stream<Uint8List> get audioStream => 
    _audioController?.stream ?? const Stream.empty();

  Future<Uint8List> _readWavFile() async {
    final file = File(_audioFilePath!);
    final allBytes = await file.readAsBytes();
    if (allBytes.length < 44) {
      throw Exception('WAV file too small or invalid header: $_audioFilePath');
    }
    return allBytes.sublist(44); // naive skip
  }

  @override
  void dispose() async {
    _audioTimer?.cancel();
    await _audioController?.close();
    super.dispose();
  }
}

final mockRecorderProvider = StateNotifierProvider<MockRecorderNotifier, RecorderState>((ref) {
  return MockRecorderNotifier();
});