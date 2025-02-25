import 'dart:typed_data';

class RollingCache {
  final int sampleRate;
  final int bitDepth;
  final int durationSeconds;
  final List<Float32List> _chunks = [];
  int _totalSamples = 0;
  int get maxSamples => sampleRate * durationSeconds;

  RollingCache({
    required this.sampleRate,
    required this.bitDepth,
    required this.durationSeconds,
  });

  bool get isEmpty => _chunks.isEmpty;
  bool get isNotEmpty => _chunks.isNotEmpty;

  /// Add a new speech segment to the cache
  void addSegment(Float32List segment) {
    _chunks.add(segment);
    _totalSamples += segment.length;
    // If the cache exceeds the size limit, remove the oldest chunks
    while (_totalSamples > maxSamples && _chunks.isNotEmpty) {
      final oldestChunk = _chunks.removeAt(0);
      _totalSamples -= oldestChunk.length;
    }
  }

  /// Get the current audio data in the cache as a single combined Float32List
  Float32List getFloatData() {
    final result = Float32List(_totalSamples);
    int offset = 0;
    for (var chunk in _chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }
  
  /// Convert and get the data as Uint8List (16-bit PCM)
  Uint8List getData() {
    final floatData = getFloatData();
    final result = Uint8List(floatData.length * 2);
    final buffer = ByteData.view(result.buffer);
    
    for (int i = 0; i < floatData.length; i++) {
      // Convert float (-1.0 to 1.0) to 16-bit PCM
      final int value = (floatData[i] * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(i * 2, value, Endian.little);
    }
    
    return result;
  }

  /// Clears the cache
  void clear() {
    _chunks.clear();
    _totalSamples = 0;
  }
}