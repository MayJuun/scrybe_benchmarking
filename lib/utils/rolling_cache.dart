import 'dart:typed_data';

class RollingCache {
  final List<Uint8List> _chunks = [];
  int _totalBytes = 0;

  RollingCache();

  bool get isEmpty => _chunks.isEmpty;
  bool get isNotEmpty => _chunks.isNotEmpty;

  /// Add a new audio chunk to the cache
  void addChunk(Uint8List chunk) {
    _chunks.add(chunk);
    _totalBytes += chunk.length;

    // Limit cache to approximately 20 seconds (assuming 16kHz, 16-bit audio)
    final maxBytes = 16000 * 2 * 20; // 20 seconds of audio
    while (_totalBytes > maxBytes && _chunks.isNotEmpty) {
      final oldestChunk = _chunks.removeAt(0);
      _totalBytes -= oldestChunk.length;
    }
  }

  /// Get the current audio data in the cache as a single combined Uint8List
  Uint8List getData() {
    final result = Uint8List(_totalBytes);
    int offset = 0;
    for (var chunk in _chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }

  int getTotalBytes() {
    return _totalBytes;
  }

  /// Calculate total duration in seconds based on sample rate
  double getTotalDuration(int sampleRate) {
    // Each sample is 2 bytes for 16-bit audio
    return _totalBytes / (2 * sampleRate);
  }

  /// Clears the cache
  void clear() {
    _chunks.clear();
    _totalBytes = 0;
  }
}
