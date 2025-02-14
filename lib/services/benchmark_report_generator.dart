import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
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
      if (!await modelDir.exists()) continue;

      // Parse individual file results
      final results = await _parseModelResults(modelDir);
      if (results.isEmpty) continue;

      // Calculate metrics
      final modelMetrics = _calculateModelMetrics(results);
      metrics[model.name] = modelMetrics;
    }

    // Write comprehensive report
    await _writeFullReport(metrics);
    
    return metrics;
  }

  Future<List<FileResult>> _parseModelResults(Directory modelDir) async {
    final results = <FileResult>[];
    
    // Find all comparison files
    await for (final entity in modelDir.list(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.txt')) continue;
      if (!p.basename(entity.path).contains('comparison')) continue;

      final content = await entity.readAsString();
      final result = _parseComparisonFile(content, entity.path);
      if (result != null) {
        results.add(result);
      }
    }

    return results;
  }

  FileResult? _parseComparisonFile(String content, String path) {
    try {
      final lines = content.split('\n');
      String reference = '';
      String hypothesis = '';
      double wer = 0.0;
      double? duration;

      for (final line in lines) {
        if (line.startsWith('Reference:')) {
          reference = line.substring('Reference:'.length).trim();
        } else if (line.startsWith('Hypothesis:')) {
          hypothesis = line.substring('Hypothesis:'.length).trim();
        } else if (line.startsWith('WER:')) {
          wer = double.parse(line.substring('WER:'.length).replaceAll('%', '').trim());
        } else if (line.startsWith('Duration:')) {
          duration = double.parse(line.substring('Duration:'.length).replaceAll('s', '').trim());
        }
      }

      return FileResult(
        path: path,
        reference: reference,
        hypothesis: hypothesis,
        wer: wer,
        duration: duration,
      );
    } catch (e) {
      print('Error parsing comparison file $path: $e');
      return null;
    }
  }

  ModelMetrics _calculateModelMetrics(List<FileResult> results) {
    var totalWer = 0.0;
    var totalDuration = 0.0;
    var totalReferenceWords = 0;
    var totalHypothesisWords = 0;
    var minWer = double.infinity;
    var maxWer = double.negativeInfinity;
    
    for (final result in results) {
      totalWer += result.wer;
      if (result.duration != null) {
        totalDuration += result.duration!;
      }
      totalReferenceWords += result.reference.split(' ').length;
      totalHypothesisWords += result.hypothesis.split(' ').length;
      minWer = minWer > result.wer ? result.wer : minWer;
      maxWer = maxWer < result.wer ? result.wer : maxWer;
    }

    return ModelMetrics(
      totalFiles: results.length,
      averageWer: totalWer / results.length,
      minWer: minWer,
      maxWer: maxWer,
      totalDurationSeconds: totalDuration,
      totalReferenceWords: totalReferenceWords,
      totalHypothesisWords: totalHypothesisWords,
      wordAccuracy: 1 - ((totalWer / results.length) / 100),
    );
  }

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
      ..writeln('| Model | Files | Avg WER | Min WER | Max WER | Duration | Word Accuracy |')
      ..writeln('|-------|--------|---------|---------|---------|-----------|---------------|');

    metrics.forEach((model, metric) {
      final row = [
        model,
        metric.totalFiles,
        '${metric.averageWer.toStringAsFixed(2)}%',
        '${metric.minWer.toStringAsFixed(2)}%',
        '${metric.maxWer.toStringAsFixed(2)}%',
        '${metric.totalDurationSeconds.toStringAsFixed(1)}s',
        '${(metric.wordAccuracy * 100).toStringAsFixed(2)}%',
      ];
      mdReport.writeln('| ${row.join(' | ')} |');
    });

    final mdPath = p.join(reportDir.path, 'benchmark_report.md');
    await File(mdPath).writeAsString(mdReport.toString());
  }
}

class ModelMetrics {
  final int totalFiles;
  final double averageWer;
  final double minWer;
  final double maxWer;
  final double totalDurationSeconds;
  final int totalReferenceWords;
  final int totalHypothesisWords;
  final double wordAccuracy;

  ModelMetrics({
    required this.totalFiles,
    required this.averageWer,
    required this.minWer,
    required this.maxWer,
    required this.totalDurationSeconds,
    required this.totalReferenceWords,
    required this.totalHypothesisWords,
    required this.wordAccuracy,
  });

  Map<String, dynamic> toJson() => {
    'totalFiles': totalFiles,
    'averageWer': averageWer,
    'minWer': minWer,
    'maxWer': maxWer,
    'totalDurationSeconds': totalDurationSeconds,
    'totalReferenceWords': totalReferenceWords,
    'totalHypothesisWords': totalHypothesisWords,
    'wordAccuracy': wordAccuracy,
  };
}

class FileResult {
  final String path;
  final String reference;
  final String hypothesis;
  final double wer;
  final double? duration;

  FileResult({
    required this.path,
    required this.reference,
    required this.hypothesis,
    required this.wer,
    this.duration,
  });
}

class BenchmarkResultsWidget extends StatelessWidget {
  final Map<String, ModelMetrics> metrics;

  const BenchmarkResultsWidget({
    super.key,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Benchmark Results',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2), // Model name
                    1: FlexColumnWidth(1), // Files
                    2: FlexColumnWidth(1), // WER
                    3: FlexColumnWidth(1), // Accuracy
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      children: [
                        _buildHeaderCell(context, 'Model'),
                        _buildHeaderCell(context, 'Files'),
                        _buildHeaderCell(context, 'WER'),
                        _buildHeaderCell(context, 'Accuracy'),
                      ],
                    ),
                    for (final entry in metrics.entries)
                      TableRow(
                        children: [
                          _buildCell(context, entry.key),
                          _buildCell(context, entry.value.totalFiles.toString()),
                          _buildCell(
                            context, 
                            '${entry.value.averageWer.toStringAsFixed(2)}%'
                          ),
                          _buildCell(
                            context,
                            '${(entry.value.wordAccuracy * 100).toStringAsFixed(2)}%'
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildCell(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text),
    );
  }
}