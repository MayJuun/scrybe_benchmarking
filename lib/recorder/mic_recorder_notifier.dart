import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

// mic_recorder.dart
class MicRecorderNotifier extends BaseRecorderNotifier {
  final Recorder _recorder = Recorder.instance;
  StreamSubscription<AudioDataContainer>? _subscription;

  @override
  Future<void> initialize({int sampleRate = 16000}) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final permissionStatus = await Permission.microphone.request();
        if (!permissionStatus.isGranted) {
          state = state.copyWith(
              status: RecorderStatus.error,
              errorMessage: 'Microphone permission denied');
          return;
        }
      }

      await _recorder.init(sampleRate: sampleRate);
      state = state.copyWith(
          status: RecorderStatus.initialized, isInitialized: true);
    } catch (e) {
      state = state.copyWith(
          status: RecorderStatus.error,
          errorMessage: 'Failed to initialize: $e');
    }
  }

  @override
  Future<void> startRecorder() async {
    if (!state.isInitialized) {
      state = state.copyWith(
          status: RecorderStatus.error,
          errorMessage: 'Recorder not initialized');
      return;
    }

    try {
      _recorder.start();
      state = state.copyWith(status: RecorderStatus.ready, isStarted: true);
    } catch (e) {
      state = state.copyWith(
          status: RecorderStatus.error,
          errorMessage: 'Failed to start recorder: $e');
    }
  }

  @override
  Future<void> startStreaming(void Function(Uint8List) onAudioData) async {
    print('startStreaming');
    if (!state.isStarted) {
      state = state.copyWith(
          status: RecorderStatus.error, errorMessage: 'Recorder not started');
      return;
    }

    try {
      _recorder.startStreamingData();
      _subscription = _recorder.uint8ListStream.listen((audioData) {
        onAudioData(audioData.rawData);
      });

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
      _recorder.stopStreamingData();
      await _subscription?.cancel();
      _subscription = null;

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

      _recorder.stopRecording();
      state =
          state.copyWith(status: RecorderStatus.initialized, isStarted: false);
    } catch (e) {
      state = state.copyWith(
          status: RecorderStatus.error,
          errorMessage: 'Failed to stop recorder: $e');
    }
  }

  @override
  Stream<Uint8List> get audioStream =>
      _recorder.uint8ListStream.map((adc) => adc.rawData);

  @override
  void dispose() async {
    await _subscription?.cancel();
    super.dispose();
  }
}

final recorderProvider =
    StateNotifierProvider<MicRecorderNotifier, RecorderState>((ref) {
  return MicRecorderNotifier();
});
