/// Metrics for a single model after aggregating all CSV lines
class ModelMetrics {
  final int totalFiles;
  final double averageWer;
  final double minWer;
  final double maxWer;
  final int totalReferenceWords;
  final int totalHypothesisWords;
  final double wordAccuracy;

  /// Additional timing stats
  final double averageDecodeTime; // avg decode time across all chunks
  final double realTimeFactor; // totalDecodeTime / totalAudioTime

  ModelMetrics({
    required this.totalFiles,
    required this.averageWer,
    required this.minWer,
    required this.maxWer,
    required this.totalReferenceWords,
    required this.totalHypothesisWords,
    required this.wordAccuracy,
    this.averageDecodeTime = 0.0,
    this.realTimeFactor = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'totalFiles': totalFiles,
        'averageWer': averageWer,
        'minWer': minWer,
        'maxWer': maxWer,
        'totalReferenceWords': totalReferenceWords,
        'totalHypothesisWords': totalHypothesisWords,
        'wordAccuracy': wordAccuracy,
        'averageDecodeTime': averageDecodeTime,
        'realTimeFactor': realTimeFactor,
      };
}
