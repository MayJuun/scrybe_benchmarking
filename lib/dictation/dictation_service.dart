import 'dart:typed_data';

import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class DictationService {
  DictationService();
  final RollingCache rollingCache = RollingCache();
  final TranscriptCombiner _transcriptionCombiner = TranscriptCombiner();

  // Process audio for an offline model
  String processOfflineAudio(
      Uint8List audioData, AsrModel model, int sampleRate) {
    if (model is OfflineRecognizerModel) {
      return model.processAudio(audioData, sampleRate);
    }
    return '';
  }

  // Process audio for an online model
  String processOnlineAudio(
      Uint8List audioData, AsrModel model, int sampleRate) {
    if (model is OnlineModel) {
      return model.processAudio(audioData, sampleRate);
    }
    return '';
  }

  // Combine transcripts
  String combineTranscripts(String existingText, String newText) {
    return _transcriptionCombiner.combineTranscripts(existingText, newText);
  }

  // Reset the rolling cache
  void resetCache() {
    rollingCache.reset();
  }

  // Completely clear the rolling cache
  void clearCache() {
    rollingCache.clear();
  }

  // Add audio to rolling cache
  void addToCache(Uint8List audioData) {
    rollingCache.addChunk(audioData);
  }

  // Get data from cache
  Uint8List getCacheData() {
    return rollingCache.getData();
  }

  bool isCacheEmpty() => rollingCache.isEmpty;

  // Reset online model - often needed for both regular and benchmark dictation
  void resetOnlineModel(AsrModel model) {
    if (model is OnlineRecognizerModel) {
      model.resetStream();
    }
  }

  // Handle different model types when updating transcript
  String updateTranscriptByModelType(
      String currentText, String newText, AsrModel model) {
    if (newText.trim().isEmpty) return currentText;

    if (model is KeywordSpotterModel) {
      // For keyword spotters, append in a new line
      return '$currentText\n${newText.trim()}'.trim();
    } else if (model is OnlineRecognizerModel) {
      // For online models, they provide the full text, so replace
      return newText.trim();
    } else {
      // return '$currentText $newText';
      // For offline models, use the transcript combiner
      return combineTranscripts(currentText, newText);
    }
  }

// Finalize transcription (useful for stopping dictation)
  String finalizeTranscription(AsrModel model, int sampleRate) {
    if (model is OnlineRecognizerModel) {
      // Send silence to finalize
      final silenceBuffer = Float32List(sampleRate ~/ 4);
      model.finalizeDecoding();
      return model.processAudio(
          convertFloat32ToBytes(silenceBuffer), sampleRate);
    }
    return '';
  }

  Uint8List convertFloat32ToBytes(Float32List float32Values,
      [endian = Endian.little]) {
    final bytes = Uint8List(float32Values.length * 2);
    final data = ByteData.view(bytes.buffer);

    for (var i = 0; i < float32Values.length; i++) {
      // Convert float (-1.0 to 1.0) to 16-bit PCM
      final int value = (float32Values[i] * 32767).round().clamp(-32768, 32767);
      data.setInt16(i * 2, value, endian);
    }

    return bytes;
  }
}
