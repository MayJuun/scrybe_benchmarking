// Updated enum remains the same.
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

enum DictationStatus {
  idle,
  recording,
  finishing,
  error,
}

class DictationState {
  final DictationStatus status;
  final String? errorMessage;
  final String currentChunkText;
  final String fullTranscript;

  const DictationState({
    this.status = DictationStatus.idle,
    this.errorMessage,
    this.currentChunkText = '',
    this.fullTranscript = '',
  });

  DictationState copyWith({
    DictationStatus? status,
    String? errorMessage,
    String? currentChunkText,
    String? fullTranscript,
  }) {
    return DictationState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      currentChunkText: currentChunkText ?? this.currentChunkText,
      fullTranscript: fullTranscript ?? this.fullTranscript,
    );
  }
}

class DictationBenchmarkState extends DictationState {
  final List<BenchmarkMetrics> metricsList;

  const DictationBenchmarkState({
    super.status = DictationStatus.idle,
    super.errorMessage,
    super.currentChunkText = '',
    super.fullTranscript = '',
    this.metricsList = const [],
  });

  @override
  DictationBenchmarkState copyWith({
    DictationStatus? status,
    String? errorMessage,
    String? currentChunkText,
    String? fullTranscript,
    List<BenchmarkMetrics>? metricsList,
  }) {
    return DictationBenchmarkState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      currentChunkText: currentChunkText ?? this.currentChunkText,
      fullTranscript: fullTranscript ?? this.fullTranscript,
      metricsList: metricsList ?? this.metricsList,
    );
  }
}
