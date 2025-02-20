import 'dart:io';
import 'dart:convert';
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
  // 1) CSV REPORT
  // --------------------------------------------------------------------------
  Future<void> _writeCsvReport() async {
    final csvLines = <String>[
      'Model,Type,File,Text,Reference,Duration (ms),RTF,WER,Word Accuracy,Subs,Del,Ins,RefLen'
    ];

    for (final m in metricsList) {
      final werPercent = m.werStats.wer * 100;
      final wordAccuracy = (1.0 - m.werStats.wer) * 100;

      csvLines.add([
        m.modelName,
        m.modelType,
        m.fileName,
        _escapeCsv(m.transcription),
        _escapeCsv(m.reference),
        m.durationMs,
        m.rtf.toStringAsFixed(3),
        werPercent.toStringAsFixed(2),
        wordAccuracy.toStringAsFixed(2),
        m.werStats.substitutions,
        m.werStats.deletions,
        m.werStats.insertions,
        m.werStats.referenceLength,
      ].join(','));
    }

    final csvPath = p.join(outputDir, 'benchmark_results.csv');
    await File(csvPath).writeAsString(csvLines.join('\n'));
    print('CSV report written to: $csvPath');
  }

  String _escapeCsv(String text) {
    return text
        .replaceAll(',', ';')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
  }

  // --------------------------------------------------------------------------
  // 2) JSON REPORT
  // --------------------------------------------------------------------------
  Future<void> _writeJsonReport() async {
    final List<Map<String, dynamic>> entries = metricsList.map((m) {
      return {
        'model': m.modelName,
        'type': m.modelType,
        'file': m.fileName,
        'recognized': m.transcription,
        'reference': m.reference,
        'duration_ms': m.durationMs,
        'rtf': m.rtf,
        'wer': m.werStats.wer,
        'word_accuracy': 1.0 - m.werStats.wer,
        'substitutions': m.werStats.substitutions,
        'deletions': m.werStats.deletions,
        'insertions': m.werStats.insertions,
        'reference_length': m.werStats.referenceLength,
      };
    }).toList();

    final jsonMap = {
      'timestamp': DateTime.now().toIso8601String(),
      'results': entries,
    };

    final jsonPath = p.join(outputDir, 'benchmark_results.json');
    await File(jsonPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonMap),
    );
    print('JSON report written to: $jsonPath');
  }

  // --------------------------------------------------------------------------
  // 3) MARKDOWN REPORT
  // --------------------------------------------------------------------------
  Future<void> _writeMarkdownReport() async {
    final sb = StringBuffer();
    sb.writeln('# Benchmark Report');
    sb.writeln('Generated: ${DateTime.now()}');
    sb.writeln();

    final grouped = <String, List<BenchmarkMetrics>>{};
    for (final m in metricsList) {
      grouped.putIfAbsent(m.modelName, () => []).add(m);
    }

    for (final modelName in grouped.keys) {
      final exampleType = grouped[modelName]!.first.modelType;
      sb.writeln('## Model: $modelName ($exampleType)');
      sb.writeln();
      sb.writeln('| File | WER(%) | Duration(ms) | RTF |');
      sb.writeln('|------|--------|--------------|-----|');

      for (final m in grouped[modelName]!) {
        final werPercent = (m.werStats.wer * 100).toStringAsFixed(2);
        sb.writeln(
          '| ${m.fileName} | $werPercent | ${m.durationMs} | ${m.rtf.toStringAsFixed(3)} |'
        );
      }
      sb.writeln();
    }

    final mdPath = p.join(outputDir, 'benchmark_results.md');
    await File(mdPath).writeAsString(sb.toString());
    print('Markdown report written to: $mdPath');
  }
}
