// benchmark_report_generator.dart

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class BenchmarkReportGenerator {
  final String derivedDir;
  final List<AsrModel> asrModels;
  final List<PunctuationModel> punctuationModels;

  BenchmarkReportGenerator({
    required this.derivedDir,
    required this.asrModels,
    required this.punctuationModels,
  });

  Future<Map<String, ModelMetrics>> generateReport() async {
    final metrics = <String, ModelMetrics>{};

    for (final model in asrModels) {
      final modelDir = Directory(p.join(derivedDir, model.name));
      if (!await modelDir.exists()) {
        continue;
      }

      // Parse the CSV results for this model
      final results = await _parseModelCsv(modelDir);
      if (results.isEmpty) {
        continue;
      }

      // Calculate metrics
      final modelMetrics = _calculateModelMetrics(results);
      metrics[model.name] = modelMetrics;
    }

    // Write comprehensive JSON + Markdown report
    await _writeFullReport(metrics);

    return metrics;
  }

  /// Reads the 'WER_results.csv' in [modelDir] and returns a list of [CsvResult].
  /// Now we expect 6 columns:
  /// chunkPath, refWords, hypWords, WER(%), decodeTimeSeconds, chunkAudioSeconds
  Future<List<CsvResult>> _parseModelCsv(Directory modelDir) async {
    final results = <CsvResult>[];
    final csvPath = p.join(modelDir.path, 'WER_results.csv');
    final csvFile = File(csvPath);

    if (!csvFile.existsSync()) {
      return results; // no CSV => no data
    }

    final lines = await csvFile.readAsLines();
    if (lines.isEmpty) {
      return results;
    }

    // Skip the header line
    for (final line in lines.skip(1)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Split into columns
      final parts = trimmed.split(',');
      if (parts.length < 6) {
        // We expect 6 columns based on how we wrote them
        continue;
      }

      final chunkPath = parts[0];
      final refCount = int.tryParse(parts[1]) ?? 0;
      final hypCount = int.tryParse(parts[2]) ?? 0;
      final werPercentage = double.tryParse(parts[3]) ?? 0.0;
      final decodeTimeSeconds = double.tryParse(parts[4]) ?? 0.0;
      final chunkAudioSeconds = double.tryParse(parts[5]) ?? 0.0;

      results.add(
        CsvResult(
          chunkPath: chunkPath,
          refCount: refCount,
          hypCount: hypCount,
          werPercentage: werPercentage,
          decodeTimeSeconds: decodeTimeSeconds,
          chunkAudioSeconds: chunkAudioSeconds,
        ),
      );
    }

    return results;
  }

  /// Aggregates the list of CSV results into a [ModelMetrics] object.
  ModelMetrics _calculateModelMetrics(List<CsvResult> results) {
    double totalWer = 0.0;
    int totalReferenceWords = 0;
    int totalHypothesisWords = 0;
    double minWer = double.infinity;
    double maxWer = double.negativeInfinity;

    double totalDecodeTime = 0.0; // sum of decodeTimeSeconds across all chunks
    double totalAudioTime = 0.0; // sum of chunkAudioSeconds across all chunks

    for (final r in results) {
      final wer = r.werPercentage;
      totalWer += wer;
      if (wer < minWer) minWer = wer;
      if (wer > maxWer) maxWer = wer;

      totalReferenceWords += r.refCount;
      totalHypothesisWords += r.hypCount;

      totalDecodeTime += r.decodeTimeSeconds;
      totalAudioTime += r.chunkAudioSeconds;
    }

    final totalFiles = results.length;
    final avgWer = (totalFiles == 0) ? 0.0 : (totalWer / totalFiles);
    final wordAccuracy = 1.0 - (avgWer / 100.0);

    // Compute average decode time
    final averageDecodeTime =
        (totalFiles == 0) ? 0.0 : (totalDecodeTime / totalFiles);

    // Compute Real-Time Factor (RTF) = totalDecodeTime / totalAudioTime
    // If totalAudioTime == 0, RTF = 0
    final realTimeFactor =
        (totalAudioTime == 0) ? 0.0 : (totalDecodeTime / totalAudioTime);

    return ModelMetrics(
      totalFiles: totalFiles,
      averageWer: avgWer,
      minWer: minWer.isInfinite ? 0.0 : minWer,
      maxWer: maxWer == double.negativeInfinity ? 0.0 : maxWer,
      totalReferenceWords: totalReferenceWords,
      totalHypothesisWords: totalHypothesisWords,
      wordAccuracy: wordAccuracy,
      averageDecodeTime: averageDecodeTime,
      realTimeFactor: realTimeFactor,
    );
  }

  /// Writes out a JSON and a Markdown report summarizing model metrics
  Future<void> _writeFullReport(Map<String, ModelMetrics> metrics) async {
    final reportDir = Directory(p.join(derivedDir, 'reports'));
    await reportDir.create(recursive: true);

    // Write JSON report
    final reportPath = p.join(reportDir.path, 'benchmark_report.json');
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'models': metrics.map((key, value) => MapEntry(key, value.toJson())),
      'punctuation_models': punctuationModels.map((m) => m.name).toList(),
    };

    await File(reportPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
    );

    // Write markdown summary
    final mdReport = StringBuffer()
      ..writeln('# ASR Benchmark Report')
      ..writeln('Generated: ${DateTime.now()}')
      ..writeln()
      ..writeln('## Summary')
      ..writeln()
      ..writeln(
          '| Model | Files | Avg WER | Min WER | Max WER | Word Accuracy | Avg Decode (s) | RTF |')
      ..writeln(
          '|-------|-------|---------|---------|---------|---------------|----------------|-----|');

    metrics.forEach((model, metric) {
      final row = [
        model,
        metric.totalFiles,
        '${metric.averageWer.toStringAsFixed(2)}%',
        '${metric.minWer.toStringAsFixed(2)}%',
        '${metric.maxWer.toStringAsFixed(2)}%',
        '${(metric.wordAccuracy * 100).toStringAsFixed(2)}%',
        metric.averageDecodeTime.toStringAsFixed(2),
        metric.realTimeFactor.toStringAsFixed(2),
      ];
      mdReport.writeln('| ${row.join(' | ')} |');
    });

    final mdPath = p.join(reportDir.path, 'benchmark_report.md');
    await File(mdPath).writeAsString(mdReport.toString());
  }
}

/// Represents a single row of CSV data from `WER_results.csv`.
/// Now includes decodeTimeSeconds and chunkAudioSeconds.
class CsvResult {
  final String chunkPath;
  final int refCount;
  final int hypCount;
  final double werPercentage;
  final double decodeTimeSeconds;
  final double chunkAudioSeconds;

  CsvResult({
    required this.chunkPath,
    required this.refCount,
    required this.hypCount,
    required this.werPercentage,
    required this.decodeTimeSeconds,
    required this.chunkAudioSeconds,
  });
}

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
