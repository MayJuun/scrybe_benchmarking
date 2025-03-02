import 'dart:typed_data';

class RollingCache {
  final List<Uint8List> _chunks = [];
  final List<Uint8List> _oldChunks = [];
  int _totalBytes = 0;
  int _totalOldBytes = 0;

  RollingCache();

  bool get isEmpty => _chunks.isEmpty;
  bool get isNotEmpty => _chunks.isNotEmpty;

  /// Add a new audio chunk to the cache
  void addChunk(Uint8List chunk) {
    _chunks.add(chunk);
    _totalBytes += chunk.length;
  }

  /// Returns all current audio data in one Uint8List
  Uint8List getData() {
    final result = Uint8List(_totalBytes + _totalOldBytes);
    int offset = 0;
    for (final chunk in _oldChunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    for (final chunk in _chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }

  void reset() {
    _oldChunks.clear();

    // Calculate how many bytes we need for 0.5-1 second of audio
    // Assuming 16-bit PCM at 16kHz, 1 second = 32000 bytes (16000 samples × 2 bytes)
    final int bytesNeededForOverlap = 16000 * 2 * 1; // 1 second

    // Transfer chunks from the end, just enough to cover our overlap target
    int bytesToTransfer = 0;
    List<Uint8List> chunksToTransfer = [];

    // Start from the end and work backwards until we have enough for our overlap
    for (int i = _chunks.length - 1; i >= 0; i--) {
      chunksToTransfer.insert(0, _chunks[i]);
      bytesToTransfer += _chunks[i].length;

      if (bytesToTransfer >= bytesNeededForOverlap) {
        break;
      }
    }

    // Only transfer the chunks we need
    _oldChunks.addAll(chunksToTransfer);
    _totalOldBytes = bytesToTransfer;

    _chunks.clear();
    _totalBytes = 0;
  }

  void clear() {
    _oldChunks.clear();
    _totalOldBytes = 0;
    _chunks.clear();
    _totalBytes = 0;
  }
}
