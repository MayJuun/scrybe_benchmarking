// transcription_benchmark_notifier.dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class TranscriptionBenchmarkState {
  final bool isTranscribing;
  final String currentFile;
  final double progress;
  final List<BenchmarkMetrics> metricsList;
  final int totalFiles;
  final String modelName;

  const TranscriptionBenchmarkState({
    this.isTranscribing = false,
    this.currentFile = '',
    this.progress = 0.0,
    this.metricsList = const [],
    this.totalFiles = 0,
    this.modelName = '',
  });

  TranscriptionBenchmarkState copyWith({
    bool? isTranscribing,
    String? currentFile,
    double? progress,
    List<BenchmarkMetrics>? metricsList,
    int? totalFiles,
    String? modelName,
  }) {
    return TranscriptionBenchmarkState(
      isTranscribing: isTranscribing ?? this.isTranscribing,
      currentFile: currentFile ?? this.currentFile,
      progress: progress ?? this.progress,
      metricsList: metricsList ?? this.metricsList,
      totalFiles: totalFiles ?? this.totalFiles,
      modelName: modelName ?? this.modelName,
    );
  }
}

class TranscriptionBenchmarkNotifier
    extends Notifier<TranscriptionBenchmarkState> {
  @override
  TranscriptionBenchmarkState build() {
    return const TranscriptionBenchmarkState();
  }

  Future<void> runTranscriptionBenchmark({
    required List<OfflineRecognizerModel> models,
    required AudioTestFiles testFiles,
  }) async {
    final numberOfFiles = testFiles.length;
    // Reset
    state = state.copyWith(
        isTranscribing: true,
        metricsList: [],
        progress: 0.0,
        totalFiles: numberOfFiles);

    final allMetrics = <BenchmarkMetrics>[];

    try {
      for (final model in models) {
        final offlineRecognizer = model.recognizer;
        state = state.copyWith(modelName: model.modelName);

        for (int i = 0; i < testFiles.length; i++) {
          final audioFilePath = testFiles.allFiles[i]; // This is a string
          final baseName = p.basename(audioFilePath);
          final progressVal = i / numberOfFiles;

          state = state.copyWith(currentFile: baseName, progress: progressVal);

          // Get reference text from AudioTestFiles
          final referenceText =
              testFiles.getReferenceTranscript(audioFilePath) ?? '';

          // Transcribe
          final metrics = await TranscriptionService.transcribeFile(
            audioFilePath: audioFilePath,
            offlineRecognizer: offlineRecognizer,
            modelName: model.modelName,
            referenceText: referenceText,
          );
          allMetrics.add(metrics);

          // Update partial state
          state = state.copyWith(metricsList: List.from(allMetrics));
        }

        offlineRecognizer.free();
      }

      // Final
      state = state.copyWith(progress: 1.0, metricsList: allMetrics);

      // Generate CSV/JSON/MD
      final outputPath =
          Directory(p.join(Directory.current.path, 'assets', 'derived'));
      if (await outputPath.exists()) {
        await outputPath.delete(recursive: true);
      }
      await outputPath.create(recursive: true);

      final reporter = BenchmarkReportGenerator(
        metricsList: allMetrics,
        outputDir: outputPath.path,
      );
      await reporter.generateReports();
    } catch (e, st) {
      print('TranscriptionBenchmark error: $e\n$st');
    } finally {
      state =
          state.copyWith(isTranscribing: false, currentFile: '', progress: 1.0);
    }
  }
}

// The provider
final transcriptionBenchmarkNotifierProvider = NotifierProvider<
    TranscriptionBenchmarkNotifier, TranscriptionBenchmarkState>(
  TranscriptionBenchmarkNotifier.new,
);
