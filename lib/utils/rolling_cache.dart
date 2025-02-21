import 'dart:typed_data';

class RollingCache {
  final int sampleRate;
  final int bitDepth;
  final int durationSeconds;
  final List<Uint8List> _chunks = [];
  int get cacheSize => sampleRate * bitDepth * durationSeconds;
  int _currentSize = 0;

  RollingCache({
    required this.sampleRate,
    required this.bitDepth,
    required this.durationSeconds,
  });

  bool get isEmpty => _chunks.isEmpty;
  bool get isNotEmpty => _chunks.isNotEmpty;

  /// Add a new audio chunk to the cache
  void addChunk(Uint8List chunk) {
    _chunks.add(chunk);
    _currentSize += chunk.length;
    // If the cache exceeds the size limit, remove the oldest chunks
    while (_currentSize > cacheSize) {
      final oldestChunk = _chunks.removeAt(0);
      _currentSize -= oldestChunk.length;
    }
  }

  /// Get the current audio data in the cache as a single combined Uint8List
  Uint8List getData() {
    final result = Uint8List(_currentSize);
    int offset = 0;
    for (var chunk in _chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }

  /// Clears the cache
  void clear() {
    _chunks.clear();
    _currentSize = 0;
  }
}

