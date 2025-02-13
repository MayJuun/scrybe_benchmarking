// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:scrybe/scrybe_benchmark.dart';

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

  @override
  void dispose() {
    _benchmarkService?.dispose();
    super.dispose();
  }

  Future<void> _selectRawDirectory() async {
    // Note: In a real app, you'd use a proper directory picker
    // For now, we'll just use a hardcoded path for demonstration
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

      // Create curated directory if it doesn't exist
      if (!await curatedDir.exists()) {
        await curatedDir.create(recursive: true);
      }

      // Process each audio file in raw directory
      final files = await rawDir
          .list(recursive: true)
          .where((entity) =>
              entity is File &&
              ['.wav', '.mp3', '.m4a']
                  .contains(p.extension(entity.path).toLowerCase()))
          .toList();

      for (var i = 0; i < files.length; i++) {
        final file = files[i] as File;
        final relativePath = p.relative(file.path, from: rawDir.path);
        final outputBasePath = p.join(curatedDir.path, p.dirname(relativePath));

        try {
          // Convert audio file
          final converter =
              AudioConverter(file.path, outputBasePath, _chunkSize.toInt());
          final result = await converter.convert(
            onProgressUpdate: (progress) {
              setState(() {
                _progress = progress;
              });
            },
          );

          if (!result.success) {
            print('Error converting ${file.path}: ${result.error}');
            continue;
          }

          // If there's a matching transcript file, process it
          final baseName = p.basenameWithoutExtension(file.path);
          final possibleTranscripts = [
            File(p.join(p.dirname(file.path), '$baseName.srt')),
            File(p.join(p.dirname(file.path), '$baseName.json')),
          ];

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
              break;
            }
          }
        } catch (e) {
          print('Error processing file ${file.path}: $e');
          setState(() {
            _error = 'Error processing ${p.basename(file.path)}: $e';
          });
        }
      }

      setState(() {
        _progress = _progress?.copyWith(
          currentFile: 'Conversion complete',
          processedFiles: files.length,
          totalFiles: files.length,
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

  Future<void> _startBenchmark() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _error = null;
    });

    try {
      final curatedDir = p.join(Directory.current.path, 'assets', 'curated');
      final derivedDir = p.join(Directory.current.path, 'assets', 'derived');

      _benchmarkService = BenchmarkService(
        curatedDir: curatedDir,
        derivedDir: derivedDir,
        asrModels: widget.asrModels,
        punctuationModels: widget.punctuationModels,
      );

      await _benchmarkService!.runBenchmark(
        onProgressUpdate: (progress) {
          setState(() {
            _progress = progress;
            if (progress.error != null) {
              _error = progress.error;
            }
          });
        },
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sherpa Onnx Benchmark'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            Expanded(
              child: _buildContent(context),
            ),
            const SizedBox(height: 16),
            _buildControlSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Benchmark Status',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        if (_selectedRawDir != null)
          Text(
            'Raw Directory: ${p.basename(_selectedRawDir!)}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        Text(
          'Models to process: ${widget.asrModels.length}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_progress != null) ...[
              _buildProgressSection(context),
              const SizedBox(height: 16),
              _buildStatsSection(context),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildErrorSection(context),
            ],
            if (_progress == null && _error == null)
              const Center(
                child: Text('Select a raw directory to begin'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    final phase = _progress?.phase ?? '';
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
          'Current Task: ${_progress?.currentModel ?? "None"}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Processing: ${_progress?.currentFile ?? "Not started"}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: _progress?.progressPercentage.clamp(0, 100) ?? 0 / 100,
        ),
        const SizedBox(height: 4),
        Text(
          '${_progress?.processedFiles ?? 0} / ${_progress?.totalFiles ?? 0} files processed',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    if (_progress == null) return const SizedBox.shrink();

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Statistics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_progress!.werScore > 0)
              Text(
                'Average WER: ${_progress!.werScore.toStringAsFixed(2)}%',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            if (_progress?.additionalInfo != null) ...[
              const SizedBox(height: 8),
              for (final entry in _progress!.additionalInfo!.entries)
                Text(
                  '${entry.key}: ${entry.value}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSection(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Error',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlSection(BuildContext context) {
    final bool canStartBenchmark = !_isConverting && !_isRunning;
    final bool canConvert =
        !_isConverting && !_isRunning && _selectedRawDir != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: _isConverting || _isRunning ? null : _selectRawDirectory,
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Select Raw Directory'),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: canConvert ? _convertRawFiles : null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_isConverting ? 'Converting...' : 'Convert Raw Files'),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: canStartBenchmark ? _startBenchmark : null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                Text(_isRunning ? 'Benchmark Running...' : 'Start Benchmark'),
          ),
        ),
      ],
    );
  }
}
