import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_recorder/flutter_recorder.dart';

enum DictationStatus { initializing, ready, recording, error }

abstract class DictationBase {
  final _statusController = StreamController<DictationStatus>.broadcast();
  Stream<DictationStatus> get statusStream => _statusController.stream;

  final Recorder _audioRecorder = Recorder.instance;
  StreamSubscription<AudioDataContainer>? _audioSub;

  bool _initialized = false;
  bool get initialized => _initialized;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  final int sampleRate;
  final Duration silenceDuration;

  final _recognizedTextController = StreamController<String>.broadcast();
  Stream<String> get recognizedTextStream => _recognizedTextController.stream;

  DictationBase({
    this.sampleRate = 16000,
    int silenceDurationMillis = 500,
  }) : silenceDuration = Duration(milliseconds: silenceDurationMillis);

  Future<void> init() async {
    if (_initialized) return;
    await _audioRecorder.init(sampleRate: sampleRate);
    _audioRecorder.start();
    _audioSub = _audioRecorder.uint8ListStream.listen((adc) {
      onAudioData(adc.rawData);
    });
    _initialized = true;
  }

  void onAudioData(Uint8List data);

  Future<void> startRecording() async {
    if (_isRecording) return;
    _audioRecorder.startStreamingData();
    _isRecording = true;
    onRecordingStart();
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    _audioRecorder.stopStreamingData();
    _isRecording = false;
    onRecordingStop();
  }

  void onRecordingStart() {}
  void onRecordingStop() {
    // Hook for final decode, if needed
  }

  Float32List convertBytesToFloat32(Uint8List bytes,
      [Endian endian = Endian.little]) {
    final length = bytes.length ~/ 2;
    final floats = Float32List(length);
    final data = ByteData.view(bytes.buffer);
    for (var i = 0; i < bytes.length; i += 2) {
      final sample = data.getInt16(i, endian);
      floats[i ~/ 2] = sample / 32768.0;
    }
    return floats;
  }

  void emitRecognizedText(String text) {
    _recognizedTextController.add(text);
  }

  Future<void> dispose() async {
    await stopRecording();
    await _audioSub?.cancel();
    await _recognizedTextController.close();
  }
}
