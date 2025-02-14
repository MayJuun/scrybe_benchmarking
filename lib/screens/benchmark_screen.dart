// benchmark_screen.dart

// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

/// Main screen for running the Sherpa ONNX benchmarking.
class BenchmarkScreen extends StatefulWidget {
  final List<AsrModel> asrModels;
  final List<PunctuationModel> punctuationModels;

  const BenchmarkScreen({
    super.key,
    required this.asrModels,
    required this.punctuationModels,
  });

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  BenchmarkProgress? _progress;
  bool _isRunning = false;
  bool _isConverting = false;
  String? _error;
  BenchmarkService? _benchmarkService;
  String? _selectedRawDir;
  final double _chunkSize = 30.0; // seconds
  Map<String, ModelMetrics>? _benchmarkResults;
  final Map<String, double> _modelProgress = {};
  DateTime? _benchmarkStartTime;
  final Map<String, Duration> _modelTimings = {};

  @override
  void dispose() {
    _benchmarkService?.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // PICK RAW DIRECTORY (demo approach - in production you may use a proper file picker)
  // --------------------------------------------------------------------------
  Future<void> _selectRawDirectory() async {
    // Replace this with a real directory picker if needed
    final rawDir = Directory(p.join(Directory.current.path, 'assets', 'raw'));
    if (await rawDir.exists()) {
      setState(() {
        _selectedRawDir = rawDir.path;
      });
    } else {
      setState(() {
        _error = 'Raw directory not found: ${rawDir.path}';
      });
    }
  }

  // --------------------------------------------------------------------------
  // CONVERT RAW FILES
  // --------------------------------------------------------------------------
  Future<void> _convertRawFiles() async {
    if (_isConverting || _selectedRawDir == null) return;

    setState(() {
      _isConverting = true;
      _error = null;
      _progress = BenchmarkProgress(
        currentModel: 'Audio Conversion',
        currentFile: 'Starting conversion...',
        processedFiles: 0,
        totalFiles: 0,
        phase: 'converting',
      );
    });

    try {
      final rawDir = Directory(_selectedRawDir!);
      final curatedDir =
          Directory(p.join(Directory.current.path, 'assets', 'curated'));

      if (!await curatedDir.exists()) {
        await curatedDir.create(recursive: true);
      }

      // Find all audio files
      final audioFiles = await rawDir
          .list(recursive: true)
          .where((entity) =>
              entity is File &&
              ['.wav', '.mp3', '.m4a']
                  .contains(p.extension(entity.path).toLowerCase()))
          .toList();

      for (var i = 0; i < audioFiles.length; i++) {
        final audioFile = audioFiles[i] as File;
        final relativePath = p.relative(audioFile.path, from: rawDir.path);
        final outputBasePath = p.join(curatedDir.path, p.dirname(relativePath));

        try {
          // Convert audio file
          final converter = AudioConverter(
              audioFile.path, outputBasePath, _chunkSize.toInt());
          final result = await converter.convert(
            onProgressUpdate: (progress) {
              setState(() {
                _progress = progress;
              });
            },
          );

          if (!result.success) {
            print('Error converting ${audioFile.path}: ${result.error}');
            continue;
          }

          // Look for matching transcript
          final baseName = p.basenameWithoutExtension(audioFile.path);
          final possibleTranscripts = [
            File(p.join(p.dirname(audioFile.path), '$baseName.srt')),
            File(p.join(p.dirname(audioFile.path), '$baseName.json')),
            File(p.join(p.dirname(audioFile.path), '$baseName.txt')),
          ];

          bool foundTranscript = false;
          for (final transcript in possibleTranscripts) {
            if (await transcript.exists()) {
              final processor = TranscriptProcessor(
                inputPath: transcript.path,
                outputPath: outputBasePath,
                chunkSize: _chunkSize,
              );

              await processor.processTranscript(
                totalDuration: result.duration ?? _chunkSize,
                onProgressUpdate: (progress) {
                  setState(() {
                    _progress = progress.copyWith(
                      phase: 'processing_transcript',
                    );
                  });
                },
              );
              foundTranscript = true;
              break;
            }
          }

          if (!foundTranscript) {
            print('Warning: No transcript found for ${audioFile.path}');
          }
        } catch (e) {
          print('Error processing file ${audioFile.path}: $e');
          setState(() {
            _error = 'Error processing ${p.basename(audioFile.path)}: $e';
          });
        }
      }

      setState(() {
        _progress = _progress?.copyWith(
          currentFile: 'Conversion complete',
          processedFiles: audioFiles.length,
          totalFiles: audioFiles.length,
        );
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isConverting = false;
      });
    }
  }

  // --------------------------------------------------------------------------
  // START BENCHMARK
  // --------------------------------------------------------------------------
  Future<void> _confirmStartBenchmark() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Benchmark'),
        content: Text(
            'This will process ${widget.asrModels.length} models. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      await _startBenchmark();
    }
  }

  Future<void> _startBenchmark() async {
    if (_isRunning) return;

    // Check curated directory
    if (!await _validateCuratedDir()) {
      return;
    }

    setState(() {
      _isRunning = true;
      _error = null;
      _benchmarkResults = null;
      _modelProgress.clear();
      _modelTimings.clear();
      _benchmarkStartTime = DateTime.now();
    });

    try {
      final curatedDir = p.join(Directory.current.path, 'assets', 'curated');
      final derivedDir = p.join(Directory.current.path, 'assets', 'derived');

      // Check for audio files in curated
      final curatedFiles = await Directory(curatedDir)
          .list(recursive: true)
          .where((e) => e is File && p.extension(e.path) == '.wav')
          .length;

      if (curatedFiles == 0) {
        throw Exception(
            'No audio files found in curated directory. Please convert raw files first.');
      }

      // Create the service
      _benchmarkService = BenchmarkService(
        curatedDir: curatedDir,
        derivedDir: derivedDir,
        asrModels: widget.asrModels,
        punctuationModels: widget.punctuationModels,
      );

      // Run benchmark
      await _benchmarkService!.runBenchmark(
        onProgressUpdate: (progress) {
          setState(() {
            _progress = progress;
            if (progress.error != null) {
              _error = progress.error;
            }
            // Update per-model progress if you need it for UI
            _modelProgress[progress.currentModel] = progress.progressPercentage;
          });
        },
      );

      // Generate report
      final reportGenerator = BenchmarkReportGenerator(
        derivedDir: derivedDir,
        asrModels: widget.asrModels,
        punctuationModels: widget.punctuationModels,
      );

      final metrics = await reportGenerator.generateReport();
      setState(() {
        _benchmarkResults = metrics;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<bool> _validateCuratedDir() async {
    final curatedDir =
        Directory(p.join(Directory.current.path, 'assets', 'curated'));

    // Check for audio files
    final audioFiles = await curatedDir
        .list(recursive: true)
        .where((e) =>
            e is File &&
            ['.wav', '.mp3'].contains(p.extension(e.path).toLowerCase()))
        .length;

    // Check for transcripts
    final transcriptFiles = await curatedDir
        .list(recursive: true)
        .where((e) =>
            e is File &&
            ['.srt', '.json', '.txt']
                .contains(p.extension(e.path).toLowerCase()))
        .length;

    if (audioFiles == 0 || transcriptFiles == 0) {
      setState(() {
        _error =
            'Curated directory must contain audio files (.wav, .mp3) and matching transcripts (.srt, .json, .txt). Please convert raw files first.';
      });
      return false;
    }
    return true;
  }

  // --------------------------------------------------------------------------
  // UI BUILD
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sherpa ONNX Benchmark'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            BenchmarkHeader(
              asrModels: widget.asrModels,
              selectedRawDir: _selectedRawDir,
            ),
            const SizedBox(height: 24),
            // Main content area
            Expanded(
              child: BenchmarkContent(
                progress: _progress,
                benchmarkResults: _benchmarkResults,
                error: _error,
                modelTimings: _modelTimings,
                benchmarkStartTime: _benchmarkStartTime,
              ),
            ),
            const SizedBox(height: 16),
            // Control buttons
            BenchmarkControlSection(
              isRunning: _isRunning,
              isConverting: _isConverting,
              selectedRawDir: _selectedRawDir,
              onSelectRawDir: _selectRawDirectory,
              onConvertRaw: _convertRawFiles,
              onStartBenchmarkConfirmed: _confirmStartBenchmark,
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 1) HEADER WIDGET
// --------------------------------------------------------------------------
class BenchmarkHeader extends StatelessWidget {
  final List<AsrModel> asrModels;
  final String? selectedRawDir;

  const BenchmarkHeader({
    super.key,
    required this.asrModels,
    required this.selectedRawDir,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Benchmark Status',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        if (selectedRawDir != null)
          Text(
            'Raw Directory: ${p.basename(selectedRawDir!)}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        Text(
          'Models to process: ${asrModels.length}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// 2) MAIN CONTENT WIDGET
// --------------------------------------------------------------------------
class BenchmarkContent extends StatelessWidget {
  final BenchmarkProgress? progress;
  final Map<String, ModelMetrics>? benchmarkResults;
  final String? error;
  final Map<String, Duration> modelTimings;
  final DateTime? benchmarkStartTime;

  const BenchmarkContent({
    super.key,
    this.progress,
    this.benchmarkResults,
    this.error,
    required this.modelTimings,
    this.benchmarkStartTime,
  });

  @override
  Widget build(BuildContext context) {
    // Decide what to show based on state
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    // If there's an error, show that
    if (error != null) {
      return BenchmarkErrorSection(error: error!);
    }

    // If there's benchmark results, show them
    if (benchmarkResults != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (progress != null) ...[
            BenchmarkProgressSection(progress: progress!),
            const SizedBox(height: 16),
            BenchmarkStatsSection(
              progress: progress,
              modelTimings: modelTimings,
              benchmarkStartTime: benchmarkStartTime,
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: BenchmarkResultsWidget(metrics: benchmarkResults!),
          ),
        ],
      );
    }

    // Otherwise, if there's progress, show that
    if (progress != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BenchmarkProgressSection(progress: progress!),
          const SizedBox(height: 16),
          BenchmarkStatsSection(
            progress: progress,
            modelTimings: modelTimings,
            benchmarkStartTime: benchmarkStartTime,
          ),
        ],
      );
    }

    // Fallback: no progress, no results, no error
    return const Center(
      child: Text('Select a raw directory to begin'),
    );
  }
}

// --------------------------------------------------------------------------
// 2a) PROGRESS SECTION
// --------------------------------------------------------------------------
class BenchmarkProgressSection extends StatelessWidget {
  final BenchmarkProgress progress;

  const BenchmarkProgressSection({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final phase = progress.phase ?? '';
    final isConverting =
        phase == 'converting' || phase == 'processing_transcript';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isConverting ? 'Converting Files' : 'Running Benchmark',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Current Task: ${progress.currentModel}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Processing: ${progress.currentFile}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: (progress.progressPercentage.clamp(0, 100) / 100.0),
        ),
        const SizedBox(height: 4),
        Text(
          '${progress.processedFiles} / ${progress.totalFiles} files processed',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// 2b) STATS SECTION
// --------------------------------------------------------------------------
class BenchmarkStatsSection extends StatelessWidget {
  final BenchmarkProgress? progress;
  final Map<String, Duration> modelTimings;
  final DateTime? benchmarkStartTime;

  const BenchmarkStatsSection({
    super.key,
    required this.progress,
    required this.modelTimings,
    this.benchmarkStartTime,
  });

  @override
  Widget build(BuildContext context) {
    if (progress == null) return const SizedBox.shrink();

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildStats(context),
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Statistics',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (progress!.werScore > 0) ...[
          Text(
            'Average WER: ${progress!.werScore.toStringAsFixed(2)}%',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (benchmarkStartTime != null)
            Text(
              'Elapsed Time: '
              '${DateTime.now().difference(benchmarkStartTime!).inMinutes}m '
              '${DateTime.now().difference(benchmarkStartTime!).inSeconds % 60}s',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
        ],
        if (progress?.additionalInfo != null) ...[
          const SizedBox(height: 8),
          for (final entry in progress!.additionalInfo!.entries)
            Text(
              '${entry.key}: ${entry.value}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
        if (modelTimings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Model Timings:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final entry in modelTimings.entries)
            Text(
              '${entry.key}: '
              '${entry.value.inMinutes}m ${entry.value.inSeconds % 60}s',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------------------
// 2c) ERROR SECTION
// --------------------------------------------------------------------------
class BenchmarkErrorSection extends StatelessWidget {
  final String error;

  const BenchmarkErrorSection({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 3) CONTROL SECTION
// --------------------------------------------------------------------------
class BenchmarkControlSection extends StatelessWidget {
  final bool isRunning;
  final bool isConverting;
  final String? selectedRawDir;
  final VoidCallback onSelectRawDir;
  final VoidCallback onConvertRaw;
  final VoidCallback onStartBenchmarkConfirmed;

  const BenchmarkControlSection({
    super.key,
    required this.isRunning,
    required this.isConverting,
    required this.selectedRawDir,
    required this.onSelectRawDir,
    required this.onConvertRaw,
    required this.onStartBenchmarkConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final bool canStartBenchmark = !isConverting && !isRunning;
    final bool canConvert =
        !isConverting && !isRunning && selectedRawDir != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: canStartBenchmark ? onStartBenchmarkConfirmed : null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(isRunning ? 'Benchmark Running...' : 'Start Benchmark'),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: canConvert ? onConvertRaw : null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(isConverting ? 'Converting...' : 'Convert Raw Files'),
          ),
        ),
        const SizedBox(height: 8),
        // Example button to pick a directory
        FilledButton(
          onPressed: !isRunning && !isConverting ? onSelectRawDir : null,
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Select Raw Directory'),
          ),
        ),
      ],
    );
  }
}
