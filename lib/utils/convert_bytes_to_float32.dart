import 'dart:typed_data';

Float32List convertBytesToFloat32(Uint8List bytes, [endian = Endian.little]) {
  final values = Float32List(bytes.length ~/ 2);

  final data = ByteData.view(bytes.buffer);

  for (var i = 0; i < bytes.length; i += 2) {
    int short = data.getInt16(i, endian);
    values[i ~/ 2] = short / 32678.0;
  }

  return values;
}

Uint8List convertFloat32ToBytes(Float32List float32Values, [endian = Endian.little]) {
  final bytes = Uint8List(float32Values.length * 2);
  final data = ByteData.view(bytes.buffer);
  
  for (var i = 0; i < float32Values.length; i++) {
    // Convert float (-1.0 to 1.0) to 16-bit PCM
    final int value = (float32Values[i] * 32767).round().clamp(-32768, 32767);
    data.setInt16(i * 2, value, endian);
  }
  
  return bytes;
}