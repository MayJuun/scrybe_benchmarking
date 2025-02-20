import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class AudioBufferManager {
  static const int SAMPLE_RATE = 16000;
  static const int BYTES_PER_SAMPLE = 2;
  static const int CHUNK_DURATION_SECONDS = 8;
  static const int MIN_CHUNK_DURATION_SECONDS = 2;
  static const int CHUNK_SIZE =
      SAMPLE_RATE * CHUNK_DURATION_SECONDS * BYTES_PER_SAMPLE;
  static const int MIN_CHUNK_SIZE =
      SAMPLE_RATE * MIN_CHUNK_DURATION_SECONDS * BYTES_PER_SAMPLE;
  static const int OVERLAP_DURATION_SECONDS = 1;
  static const int OVERLAP_SIZE =
      SAMPLE_RATE * OVERLAP_DURATION_SECONDS * BYTES_PER_SAMPLE;

  final List<int> _buffer = [];
  bool _isProcessing = false;
  DateTime? _silenceStartTime;

  final void Function(Uint8List chunk) onChunkReady;
  final Duration silenceDuration;

  AudioBufferManager({
    required this.onChunkReady,
    this.silenceDuration = const Duration(milliseconds: 500),
  });

  void addAudio(Uint8List data, bool isSilent) {
    _buffer.addAll(data);

    if (isSilent) {
      _silenceStartTime ??= DateTime.now();
      final silenceLength = DateTime.now().difference(_silenceStartTime!);
      if (!_isProcessing &&
          silenceLength > silenceDuration &&
          _buffer.length >= MIN_CHUNK_SIZE) {
        _processBuffer();
        _silenceStartTime = null;
      }
    } else {
      _silenceStartTime = null;
    }

    if (_buffer.length >= CHUNK_SIZE && !_isProcessing) {
      _processBuffer();
    }
  }

  void _processBuffer() {
    if (_isProcessing || _buffer.isEmpty) return;
    _isProcessing = true;

    try {
      if (_buffer.length < CHUNK_SIZE) {
        final chunk = Uint8List.fromList(_buffer);
        onChunkReady(chunk);
        _buffer.clear();
        return;
      }

      final chunkData = _buffer.sublist(0, CHUNK_SIZE);
      final chunk = Uint8List.fromList(chunkData);
      onChunkReady(chunk);

      // Keep overlap data
      _buffer.removeRange(0, CHUNK_SIZE - OVERLAP_SIZE);
    } finally {
      _isProcessing = false;
    }
  }

  Uint8List drainBuffer() {
    final leftover = Uint8List.fromList(_buffer);
    _buffer.clear();
    return leftover;
  }

  void reset() {
    _buffer.clear();
    _isProcessing = false;
    _silenceStartTime = null;
  }
}
