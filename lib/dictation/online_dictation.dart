import 'dart:typed_data';
import 'dictation_base.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class OnlineDictation extends DictationBase {
  final sherpa_onnx.OnlineRecognizer onlineRecognizer;
  final sherpa_onnx.OnlineStream _onlineStream;
  String _partialTextBuffer = '';
  final bool continuous;

  OnlineDictation({
    required this.onlineRecognizer,
    this.continuous = true,
    super.sampleRate,
    super.silenceDurationMillis,
  }) : _onlineStream = onlineRecognizer.createStream();

  @override
  void onAudioData(Uint8List data) {
    if (!isRecording) return;

    final samplesFloat32 = convertBytesToFloat32(data);
    _onlineStream
        .acceptWaveform(samples: samplesFloat32, sampleRate: sampleRate);

    while (onlineRecognizer.isReady(_onlineStream)) {
      onlineRecognizer.decode(_onlineStream);
      final text = onlineRecognizer.getResult(_onlineStream).text;
      if (text.trim().isNotEmpty) {
        _partialTextBuffer = text;
        emitRecognizedText(_partialTextBuffer);
      }
    }

    if (!continuous && onlineRecognizer.isEndpoint(_onlineStream)) {
      _finalizeUtterance();
      onlineRecognizer.reset(_onlineStream);
      _partialTextBuffer = '';
    }
  }

  void _finalizeUtterance() {
    while (onlineRecognizer.isReady(_onlineStream)) {
      onlineRecognizer.decode(_onlineStream);
    }
    final finalText = onlineRecognizer.getResult(_onlineStream).text.trim();
    if (finalText.isNotEmpty) {
      emitRecognizedText(finalText);
    }
  }

  @override
  void onRecordingStop() {
    super.onRecordingStop();
    _onlineStream.inputFinished();
    _finalizeUtterance();
    _onlineStream.free();
  }

  @override
  Future<void> dispose() async {
    _onlineStream.free();
    onlineRecognizer.free();
    await super.dispose();
  }
}
