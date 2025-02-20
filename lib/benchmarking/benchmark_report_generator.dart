// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart'; // for WerCalculator

/// This class generates a CSV, JSON, or Markdown summary from the
/// final `results` map your benchmark produces.
class BenchmarkReportGenerator {
  /// The final `results` map. It might look like:
  ///
  /// ```dart
  /// {
  ///   "MyOnlineModel": {
  ///     "type": "online",
  ///     "files": {
  ///       "assets/dictation_test/test_files/audio1.wav": {
  ///         "text": "... recognized text ...",
  ///         "reference": "... reference text ...",
  ///         "duration_ms": 1234,
  ///         "real_time_factor": 0.75,
  ///       },
  ///       ...
  ///     }
  ///   },
  ///   "MyOfflineModel": {
  ///     "type": "offline",
  ///     "files": {
  ///       "assets/dictation_test/test_files/audio1.wav": {...},
  ///       ...
  ///     }
  ///   }
  /// }
  /// ```
  final Map<String, Map<String, dynamic>> results;

  /// Where you want to save the final reports (CSV, JSON, MD).
  /// On mobile, you might use `path_provider` instead of `Directory.current`.
  final String outputDir;

  BenchmarkReportGenerator({
    required this.results,
    required this.outputDir,
  });

  /// Main entry point: create CSV, JSON, and/or Markdown summaries.
  Future<void> generateReports() async {
    await _writeCsvReport();
    await _writeJsonReport();
    await _writeMarkdownReport();
  }

  // --------------------------------------------------------------------------
  // 1) CSV REPORT
  // --------------------------------------------------------------------------
  Future<void> _writeCsvReport() async {
    // CSV header
    final csvLines = <String>[
      'Model,Type,File,Text,Reference,Duration (ms),RTF,WER,Word Accuracy,Subs,Del,Ins,RefLen'
    ];

    // For each model in results...
    for (final modelName in results.keys) {
      final modelInfo = results[modelName]!;
      final modelType = modelInfo['type'] as String? ?? 'unknown';
      final fileMap = modelInfo['files'] as Map<String, dynamic>;

      for (final filePath in fileMap.keys) {
        final fileResult = fileMap[filePath] as Map<String, dynamic>;

        final recognized = fileResult['text'] as String? ?? '';
        final reference = fileResult['reference'] as String? ?? '';
        final durationMs = fileResult['duration_ms'] as int? ?? 0;
        final rtf = fileResult['real_time_factor'] as double? ?? 0.0;

        // Compute WER stats
        final werStats = WerCalculator.getDetailedStats(reference, recognized);
        final werPercent = werStats.wer * 100;
        final wordAccuracy = (1.0 - werStats.wer) * 100;

        csvLines.add([
          modelName,
          modelType,
          p.basename(filePath),
          // Make sure to handle commas or newlines in recognized/reference text
          // For simplicity, you can do naive escaping or remove them.
          _escapeCsv(recognized),
          _escapeCsv(reference),
          durationMs,
          rtf.toStringAsFixed(2),
          werPercent.toStringAsFixed(2),
          wordAccuracy.toStringAsFixed(2),
          werStats.substitutions,
          werStats.deletions,
          werStats.insertions,
          werStats.referenceLength
        ].join(','));
      }
    }

    // Write out the CSV
    final csvPath = p.join(outputDir, 'benchmark_results.csv');
    await File(csvPath).writeAsString(csvLines.join('\n'));
    print('CSV report written to: $csvPath');
  }

  /// A quick helper to handle simple CSV escaping. Adjust as needed.
  String _escapeCsv(String text) {
    // Replace any commas with semicolons, or handle quotes, etc.
    return text.replaceAll(',', ';').replaceAll('\n', ' ');
  }

  // --------------------------------------------------------------------------
  // 2) JSON REPORT
  // --------------------------------------------------------------------------
  Future<void> _writeJsonReport() async {
    // We'll build a JSON array of items for each model/file
    final List<Map<String, dynamic>> allEntries = [];

    for (final modelName in results.keys) {
      final modelInfo = results[modelName]!;
      final modelType = modelInfo['type'] as String? ?? 'unknown';
      final fileMap = modelInfo['files'] as Map<String, dynamic>;

      for (final filePath in fileMap.keys) {
        final fileResult = fileMap[filePath] as Map<String, dynamic>;

        final recognized = fileResult['text'] as String? ?? '';
        final reference = fileResult['reference'] as String? ?? '';
        final durationMs = fileResult['duration_ms'] as int? ?? 0;
        final rtf = fileResult['real_time_factor'] as double? ?? 0.0;

        final werStats = WerCalculator.getDetailedStats(reference, recognized);

        allEntries.add({
          'model': modelName,
          'type': modelType,
          'file': p.basename(filePath),
          'recognized': recognized,
          'reference': reference,
          'duration_ms': durationMs,
          'rtf': rtf,
          'wer': werStats.wer,
          'word_accuracy': 1.0 - werStats.wer,
          'substitutions': werStats.substitutions,
          'deletions': werStats.deletions,
          'insertions': werStats.insertions,
          'reference_length': werStats.referenceLength,
        });
      }
    }

    final jsonMap = {
      'timestamp': DateTime.now().toIso8601String(),
      'results': allEntries,
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
    // You could gather aggregated stats or list them. A simple approach:
    final sb = StringBuffer();
    sb.writeln('# Benchmark Report');
    sb.writeln('Generated: ${DateTime.now()}');
    sb.writeln();

    for (final modelName in results.keys) {
      final modelInfo = results[modelName]!;
      final modelType = modelInfo['type'] as String? ?? 'unknown';
      final fileMap = modelInfo['files'] as Map<String, dynamic>;

      sb.writeln('## Model: $modelName ($modelType)');
      sb.writeln();
      sb.writeln('| File | WER(%) | Duration(ms) | RTF |');
      sb.writeln('|-----|--------|--------------|-----|');

      for (final filePath in fileMap.keys) {
        final fileResult = fileMap[filePath] as Map<String, dynamic>;

        final recognized = fileResult['text'] as String? ?? '';
        final reference = fileResult['reference'] as String? ?? '';
        final durationMs = fileResult['duration_ms'] as int? ?? 0;
        final rtf = fileResult['real_time_factor'] as double? ?? 0.0;

        final werStats = WerCalculator.getDetailedStats(reference, recognized);
        final werPercent = (werStats.wer * 100).toStringAsFixed(2);

        sb.writeln(
            '| ${p.basename(filePath)} | $werPercent | $durationMs | ${rtf.toStringAsFixed(2)} |');
      }

      sb.writeln();
    }

    final mdPath = p.join(outputDir, 'benchmark_results.md');
    await File(mdPath).writeAsString(sb.toString());
    print('Markdown report written to: $mdPath');
  }
}
