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
}
