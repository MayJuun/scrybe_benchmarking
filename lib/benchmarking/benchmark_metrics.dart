// benchmark_metrics.dart

import 'package:path/path.dart' as path;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class BenchmarkMetrics {
  final String modelName;
  final String modelType;
  final String fileName;
  final String transcription;
  final String reference;
  final WerStats werStats;
  final int durationMs;
  final double rtf;

  BenchmarkMetrics._({
    required this.modelName,
    required this.modelType,
    required this.fileName,
    required this.transcription,
    required this.reference,
    required this.werStats,
    required this.durationMs,
    required this.rtf,
  });

  /// Factory method to create benchmark metrics with all necessary calculations
  static BenchmarkMetrics create({
    required String modelName,
    required String modelType,
    required String wavFile,
    required String transcription,
    required String reference,
    required Duration processingDuration,
    required int audioLengthMs, // <--- we pass this in now
  }) {
    // Calculate WER stats
    final werStats = WerCalculator.getDetailedStats(reference, transcription);

    // Calculate RTF = processingTime / audioTime
    final rtf = processingDuration.inMilliseconds / audioLengthMs;

    return BenchmarkMetrics._(
      modelName: modelName,
      modelType: modelType,
      fileName: path.basename(wavFile),
      transcription: transcription,
      reference: reference,
      werStats: werStats,
      durationMs: processingDuration.inMilliseconds,
      rtf: rtf,
    );
  }

  // Helper method to get a summary of the metrics
  Map<String, dynamic> toSummary() {
    return {
      'model_name': modelName,
      'model_type': modelType,
      'file_name': fileName,
      'wer': werStats.wer,
      'word_accuracy': 1 - werStats.wer,
      'rtf': rtf,
      'duration_ms': durationMs,
      'substitutions': werStats.substitutions,
      'deletions': werStats.deletions,
      'insertions': werStats.insertions,
    };
  }

  @override
  String toString() {
    return '''
Model: $modelName ($modelType)
File: $fileName
WER: ${(werStats.wer * 100).toStringAsFixed(2)}%
Word Accuracy: ${((1 - werStats.wer) * 100).toStringAsFixed(2)}%
RTF: ${rtf.toStringAsFixed(2)}
Duration: ${durationMs}ms
Errors: ${werStats.substitutions} sub, ${werStats.deletions} del, ${werStats.insertions} ins
''';
  }
}
