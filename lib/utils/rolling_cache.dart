import 'dart:typed_data';

class RollingCache {
  final List<Uint8List> _chunks = [];
  int _totalBytes = 0;
  final int cacheSize;

  RollingCache(this.cacheSize);

  bool get isEmpty => _chunks.isEmpty;
  bool get isNotEmpty => _chunks.isNotEmpty;

  /// Add a new audio chunk to the cache
  void addChunk(Uint8List chunk) {
    _chunks.add(chunk);
    _totalBytes += chunk.length;

    // Keep a maximum that you set for normal usage (e.g., 20 seconds).
    // Or you can let trimToLastMs do the final culling.
    final maxBytes = 16000 * 2 * cacheSize;
    while (_totalBytes > maxBytes && _chunks.isNotEmpty) {
      final oldest = _chunks.removeAt(0);
      _totalBytes -= oldest.length;
    }
  }

  /// Returns all current audio data in one Uint8List
  Uint8List getData() {
    final result = Uint8List(_totalBytes);
    int offset = 0;
    for (final chunk in _chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }

  void clear() {
    _chunks.clear();
    _totalBytes = 0;
  }

  /// Keep only the last [ms] of audio
  void trimToLastMs(int ms, int sampleRate) {
    final bytesToKeep = sampleRate * 2 * ms ~/ 1000;
    if (_totalBytes <= bytesToKeep) {
      // We already have less than that. Nothing to do.
      return;
    }

    // Combine all chunks into one array to simplify slicing
    final combined = getData();
    final startIndex = combined.length - bytesToKeep;
    final tail = combined.sublist(startIndex); // last N ms worth of bytes

    // Now reset and store only that tail
    _chunks.clear();
    _chunks.add(tail);
    _totalBytes = tail.length;
  }
}
