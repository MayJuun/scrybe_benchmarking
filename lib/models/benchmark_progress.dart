class BenchmarkProgress {
  final String currentModel;
  final String currentFile;
  final int processedFiles;
  final int totalFiles;
  final double werScore;
  final String? error;
  final String? phase;  // For indicating 'converting', 'benchmarking', etc.
  final Map<String, dynamic>? additionalInfo;  // For flexible extra data

  const BenchmarkProgress({
    required this.currentModel,
    required this.currentFile,
    required this.processedFiles,
    required this.totalFiles,
    this.werScore = 0.0,
    this.error,
    this.phase,
    this.additionalInfo,
  });

  double get progressPercentage =>
      totalFiles > 0 ? (processedFiles / totalFiles) * 100 : 0;

  bool get isComplete => processedFiles >= totalFiles;
  bool get hasError => error != null;

  BenchmarkProgress copyWith({
    String? currentModel,
    String? currentFile,
    int? processedFiles,
    int? totalFiles,
    double? werScore,
    String? error,
    String? phase,
    Map<String, dynamic>? additionalInfo,
  }) {
    return BenchmarkProgress(
      currentModel: currentModel ?? this.currentModel,
      currentFile: currentFile ?? this.currentFile,
      processedFiles: processedFiles ?? this.processedFiles,
      totalFiles: totalFiles ?? this.totalFiles,
      werScore: werScore ?? this.werScore,
      error: error ?? this.error,
      phase: phase ?? this.phase,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('BenchmarkProgress(');
    buffer.write('model: $currentModel, ');
    buffer.write('file: $currentFile, ');
    buffer.write('progress: $processedFiles/$totalFiles, ');
    buffer.write('WER: ${werScore.toStringAsFixed(2)}%, ');
    if (phase != null) buffer.write('phase: $phase, ');
    if (error != null) buffer.write('error: $error, ');
    buffer.write('${progressPercentage.toStringAsFixed(1)}% complete');
    buffer.write(')');
    return buffer.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'currentModel': currentModel,
      'currentFile': currentFile,
      'processedFiles': processedFiles,
      'totalFiles': totalFiles,
      'werScore': werScore,
      if (error != null) 'error': error,
      if (phase != null) 'phase': phase,
      if (additionalInfo != null) 'additionalInfo': additionalInfo,
    };
  }

  factory BenchmarkProgress.fromJson(Map<String, dynamic> json) {
    return BenchmarkProgress(
      currentModel: json['currentModel'] as String,
      currentFile: json['currentFile'] as String,
      processedFiles: json['processedFiles'] as int,
      totalFiles: json['totalFiles'] as int,
      werScore: (json['werScore'] as num).toDouble(),
      error: json['error'] as String?,
      phase: json['phase'] as String?,
      additionalInfo: json['additionalInfo'] as Map<String, dynamic>?,
    );
  }

  factory BenchmarkProgress.initial() {
    return const BenchmarkProgress(
      currentModel: 'Not started',
      currentFile: 'Not started',
      processedFiles: 0,
      totalFiles: 0,
    );
  }

  factory BenchmarkProgress.error(String errorMessage) {
    return BenchmarkProgress(
      currentModel: 'Error',
      currentFile: 'Failed',
      processedFiles: 0,
      totalFiles: 0,
      error: errorMessage,
    );
  }
}