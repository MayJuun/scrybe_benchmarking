import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RecorderStatus { uninitialized, initialized, ready, streaming, error }

class RecorderState {
  final RecorderStatus status;
  final String? errorMessage;
  final bool isInitialized;
  final bool isStarted;
  final bool isStreaming;

  const RecorderState({
    this.status = RecorderStatus.uninitialized,
    this.errorMessage,
    this.isInitialized = false,
    this.isStarted = false,
    this.isStreaming = false,
  });

  RecorderState copyWith({
    RecorderStatus? status,
    String? errorMessage,
    bool? isInitialized,
    bool? isStarted,
    bool? isStreaming,
  }) {
    return RecorderState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isInitialized: isInitialized ?? this.isInitialized,
      isStarted: isStarted ?? this.isStarted,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

// recorder_base.dart
abstract class BaseRecorderNotifier extends StateNotifier<RecorderState> {
  BaseRecorderNotifier() : super(const RecorderState());

  Future<void> initialize({int sampleRate = 16000});
  Future<void> startRecorder();
  Future<void> startStreaming(void Function(Uint8List) onAudioData);
  Future<void> stopStreaming();
  Future<void> stopRecorder();
  Stream<Uint8List> get audioStream;
}
