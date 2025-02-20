import 'dart:typed_data';
import 'dictation_base.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class OfflineDictation extends DictationBase {
  final sherpa_onnx.OfflineRecognizer offlineRecognizer;
  sherpa_onnx.OfflineStream? _offlineStream;
  final List<Uint8List> _accumulatedChunks = [];

  OfflineDictation({
    required this.offlineRecognizer,
    super.silenceDurationMillis,
    super.sampleRate,
  });

  @override
  Future<void> init() async {
    await super.init();
    // Create one offline stream for the entire utterance
    _offlineStream = offlineRecognizer.createStream();
  }

  @override
  void onAudioData(Uint8List data) {
    if (!isRecording) return;
    // Just accumulate data
    _accumulatedChunks.add(data);
  }

  @override
  void onRecordingStop() {
    super.onRecordingStop();

    // Now that all chunks are in, feed them into the offline stream
    if (_offlineStream == null) {
      print('Offline stream is null, cannot decode.');
      return;
    }

    for (final chunk in _accumulatedChunks) {
      final samples = convertBytesToFloat32(chunk);
      _offlineStream!.acceptWaveform(samples: samples, sampleRate: sampleRate);
    }

    // Done feeding
    offlineRecognizer.decode(_offlineStream!);
    final result = offlineRecognizer.getResult(_offlineStream!);
    if (result.text.trim() != '<unk>') {
      emitRecognizedText(result.text.trim());
    }

    // Free it
    _offlineStream?.free();
    _offlineStream = null;
    _accumulatedChunks.clear();
  }

  @override
  Future<void> dispose() async {
    offlineRecognizer.free();
    await super.dispose();
  }
}
