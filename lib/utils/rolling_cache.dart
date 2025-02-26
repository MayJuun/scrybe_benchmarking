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

  /// Clears the cache
  void clear() {
    _chunks.clear();
    _totalBytes = 0;
  }
}
