import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class TranscriptionBenchmark {
  final bool isRunning;
  final bool isConverting;
  final BenchmarkProgress? progress;          // High-level progress info
  final Map<String, ModelMetrics>? results;   // Final results after run
  final Map<String, double> modelProgress;    // Could store per-model progress
  final DateTime? benchmarkStartTime;
  final Map<String, Duration> modelTimings;   // If you want to track them
  final String? error;

  // The “raw directory” path you selected
  // Typically you'd pick or set this differently on mobile, but we'll keep it.
  final String selectedRawDir;

  // Just a convenience: the "curated" and "derived" directories
  // we might store them in state, or they could be computed in the notifier
  final String curatedDir;
  final String derivedDir;

  const TranscriptionBenchmark({
    this.isRunning = false,
    this.isConverting = false,
    this.progress,
    this.results,
    this.modelProgress = const {},
    this.benchmarkStartTime,
    this.modelTimings = const {},
    this.error,
    // Adjust to your environment
    this.selectedRawDir = '',
    this.curatedDir = '',
    this.derivedDir = '',
  });

  TranscriptionBenchmark copyWith({
    bool? isRunning,
    bool? isConverting,
    BenchmarkProgress? progress,
    Map<String, ModelMetrics>? results,
    Map<String, double>? modelProgress,
    DateTime? benchmarkStartTime,
    Map<String, Duration>? modelTimings,
    String? error,
    String? selectedRawDir,
    String? curatedDir,
    String? derivedDir,
  }) {
    return TranscriptionBenchmark(
      isRunning: isRunning ?? this.isRunning,
      isConverting: isConverting ?? this.isConverting,
      progress: progress ?? this.progress,
      results: results ?? this.results,
      modelProgress: modelProgress ?? this.modelProgress,
      benchmarkStartTime: benchmarkStartTime ?? this.benchmarkStartTime,
      modelTimings: modelTimings ?? this.modelTimings,
      error: error,
      selectedRawDir: selectedRawDir ?? this.selectedRawDir,
      curatedDir: curatedDir ?? this.curatedDir,
      derivedDir: derivedDir ?? this.derivedDir,
    );
  }
}
