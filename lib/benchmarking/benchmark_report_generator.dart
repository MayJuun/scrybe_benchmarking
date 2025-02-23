import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class BenchmarkReportGenerator {
  final List<BenchmarkMetrics> metricsList;
  final String outputDir;

  BenchmarkReportGenerator({
    required this.metricsList,
    required this.outputDir,
  });

  Future<void> generateReports() async {
    await _writeCsvReport();
    await _writeJsonReport();
    await _writeMarkdownReport();
  }

  // --------------------------------------------------------------------------
  // 1) CSV REPORT - All models in one table
  // --------------------------------------------------------------------------
  Future<void> _writeCsvReport() async {
    final csvLines = <String>[
      'File,Model,Type,WER%,Duration(ms),RTF,Word Accuracy%,Subs,Del,Ins'
    ];

    // Sort by file name first, then model name for consistent ordering
    final sortedMetrics = List<BenchmarkMetrics>.from(metricsList)
      ..sort((a, b) {
        final fileCompare = a.fileName.compareTo(b.fileName);
        if (fileCompare != 0) return fileCompare;
        return a.modelName.compareTo(b.modelName);
      });

    for (final m in sortedMetrics) {
      final werPercent = (m.werStats.wer * 100).toStringAsFixed(2);
      final wordAccuracy = ((1.0 - m.werStats.wer) * 100).toStringAsFixed(2);

      csvLines.add([
        m.fileName,
        m.modelName,
        m.modelType,
        werPercent,
        m.durationMs,
        m.rtf.toStringAsFixed(3),
        wordAccuracy,
        m.werStats.substitutions,
        m.werStats.deletions,
        m.werStats.insertions,
      ].join(','));
    }

    final csvPath = p.join(outputDir, 'benchmark_results.csv');
    await File(csvPath).writeAsString(csvLines.join('\n'));
    print('CSV report written to: $csvPath');
  }

  // --------------------------------------------------------------------------
  // 2) Markdown Report - Side by side comparison
  // --------------------------------------------------------------------------
  Future<void> _writeMarkdownReport() async {
    final sb = StringBuffer();
    sb.writeln('# ASR Model Benchmark Comparison');
    sb.writeln('Generated: ${DateTime.now()}');
    sb.writeln();

    // Get unique files and models
    final files = metricsList.map((m) => m.fileName).toSet().toList()..sort();
    final models = metricsList.map((m) => m.modelName).toSet().toList()..sort();

    // 1. Overall Summary Table
    sb.writeln('## Overall Results');
    sb.writeln();
    sb.writeln('| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |');
    sb.writeln('|-------|------|----------|---------|------------------|');

    for (final model in models) {
      final modelMetrics =
          metricsList.where((m) => m.modelName == model).toList();
      final avgWer = modelMetrics
          .map((m) => m.werStats.wer * 100)
          .average
          .toStringAsFixed(2);
      final avgRtf = modelMetrics.map((m) => m.rtf).average.toStringAsFixed(3);
      final avgDuration =
          (modelMetrics.map((m) => m.durationMs).average).toStringAsFixed(0);
      final type = modelMetrics.first.modelType;

      sb.writeln('| $model | $type | $avgWer | $avgRtf | $avgDuration |');
    }
    sb.writeln();

    // 2. Detailed Comparison Table
    sb.writeln('## Detailed Results by File');
    sb.writeln();

    // Header row with model names
    sb.write('| File |');
    for (final model in models) {
      sb.write(' $model |');
    }
    sb.writeln();

    // Separator row
    sb.write('|------|');
    for (var i = 0; i < models.length; i++) {
      sb.write('------|');
    }
    sb.writeln();

    // Data rows
    for (final file in files) {
      sb.write('| $file |');
      for (final model in models) {
        final metric = metricsList.firstWhereOrNull(
            (m) => m.fileName == file && m.modelName == model);
        final wer = ((metric?.werStats.wer ?? 1) * 100).toStringAsFixed(2);
        final rtf = metric?.rtf.toStringAsFixed(3);
        sb.write(' $wer% (RTF: $rtf) |');
      }
      sb.writeln();
    }

    final mdPath = p.join(outputDir, 'benchmark_results.md');
    await File(mdPath).writeAsString(sb.toString());
    print('Markdown report written to: $mdPath');
  }

  // --------------------------------------------------------------------------
  // 3) JSON Report - Structured data for further processing
  // --------------------------------------------------------------------------
  Future<void> _writeJsonReport() async {
    final results = {
      'timestamp': DateTime.now().toIso8601String(),
      'summary': _generateSummary(),
      'detailed_results': _generateDetailedResults(),
    };

    final jsonPath = p.join(outputDir, 'benchmark_results.json');
    await File(jsonPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(results),
    );
    print('JSON report written to: $jsonPath');
  }

  Map<String, dynamic> _generateSummary() {
    final models = metricsList.map((m) => m.modelName).toSet().toList();
    final summary = <String, Map<String, dynamic>>{};

    for (final model in models) {
      final modelMetrics =
          metricsList.where((m) => m.modelName == model).toList();
      summary[model] = {
        'type': modelMetrics.first.modelType,
        'average_wer': modelMetrics.map((m) => m.werStats.wer).average,
        'average_rtf': modelMetrics.map((m) => m.rtf).average,
        'average_duration_ms': modelMetrics.map((m) => m.durationMs).average,
      };
    }

    return summary;
  }

  Map<String, dynamic> _generateDetailedResults() {
    final files = metricsList.map((m) => m.fileName).toSet().toList()..sort();
    final results = <String, Map<String, dynamic>>{};

    for (final file in files) {
      final fileMetrics = metricsList.where((m) => m.fileName == file).toList();
      results[file] = {
        for (final m in fileMetrics)
          m.modelName: {
            'wer': m.werStats.wer,
            'rtf': m.rtf,
            'duration_ms': m.durationMs,
            'errors': {
              'substitutions': m.werStats.substitutions,
              'deletions': m.werStats.deletions,
              'insertions': m.werStats.insertions,
            }
          }
      };
    }

    return results;
  }
}

extension ListExtension<T extends num> on Iterable<T> {
  double get average => isEmpty ? 0 : sum / length;
  T get sum => isEmpty ? 0 as T : reduce((a, b) => (a + b) as T);
}
