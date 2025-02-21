import 'dart:typed_data';
import 'package:circular_buffer/circular_buffer.dart';
import 'dictation_base.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class OfflineDictation extends DictationBase {
  final sherpa_onnx.OfflineRecognizer offlineRecognizer;
  final int maxWindowMs = 10000;
  final int chunkMs = 30;
  late final CircularBuffer<int> _rollingBuffer;

  bool isBufferBeingModified = false; // Safety flag

  OfflineDictation({
    required this.offlineRecognizer,
    super.silenceDurationMillis = 500,
    super.sampleRate = 16000,
  }) {
    final maxBytes = _bytesNeededForMs(maxWindowMs);
    _rollingBuffer = CircularBuffer(maxBytes);
  }

  int volume = 0;

  @override
  void onAudioData(Uint8List data) {
    print('Received audio data of length: ${data.length} $isRecording');
    if (!isRecording) return;

    // Prevent concurrent buffer modification
    if (isBufferBeingModified) {
      print('Buffer modification in progress, skipping data...');
      return;
    }

    // Set flag before adding data to prevent concurrent modification
    isBufferBeingModified = true;
    _rollingBuffer.addAll(data.toList());
    volume += data.length;

    // Only start processing once we have enough data
    if (volume > 32000) {
      _decodeBuffer();
    }

    // Reset flag after modification
    isBufferBeingModified = false;
  }

  void _decodeBuffer() {
    final bufferList = List<int>.from(_rollingBuffer);
    final bytes = Uint8List.fromList(bufferList);
    final floatSamples = convertBytesToFloat32(bytes);
    final stream = offlineRecognizer.createStream();

    stream.acceptWaveform(samples: floatSamples, sampleRate: sampleRate);
    offlineRecognizer.decode(stream);
    final newText = offlineRecognizer.getResult(stream).text.trim();
    stream.free();
    volume = 0;
    emitRecognizedText(newText);
  }

  int _bytesNeededForMs(int ms) {
    return 32 * ms;
  }

  @override
  void onRecordingStop() {
    super.onRecordingStop();
    if (_rollingBuffer.isNotEmpty) {
      _decodeBuffer();
    }
    _rollingBuffer.clear();
  }

  @override
  Future<void> dispose() async {
    _rollingBuffer.clear();
    offlineRecognizer.free();
    await super.dispose();
  }
}
