import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:path/path.dart' as p;

/// This screen decodes entire `.wav` files at once (no chunking).
class TranscriptionBenchmarkScreen extends ConsumerStatefulWidget {
  final List<OfflineRecognizerModel> models;
  final AudioTestFiles testFiles;

  const TranscriptionBenchmarkScreen({
    super.key,
    required this.models,
    required this.testFiles,
  });

  @override
  ConsumerState<TranscriptionBenchmarkScreen> createState() =>
      _TranscriptionBenchmarkScreenState();
}

class _TranscriptionBenchmarkScreenState
    extends ConsumerState<TranscriptionBenchmarkScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transcriptionBenchmarkNotifierProvider);
    final notifier = ref.read(transcriptionBenchmarkNotifierProvider.notifier);

    final isRunning = state.isTranscribing;
    final fileCount = widget.testFiles.length;
    final modelCount = widget.models.length;
    final modelName = state.modelName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcription Benchmark'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Found $fileCount test files'),
            Text('Using $modelCount models'),
            const SizedBox(height: 16),
            if (isRunning) ...[
              Text('Current file: ${state.currentFile} (${state.progress}%)'),
              LinearProgressIndicator(value: state.progress),
              const SizedBox(height: 16),
              if (modelName.isNotEmpty) ...[
                Text('Model: $modelName'),
                const SizedBox(height: 16),
              ],
              const Expanded(child: Center(child: Text('Transcribing...'))),
            ] else ...[
              ElevatedButton(
                onPressed: fileCount == 0
                    ? null
                    : () {
                        notifier.runTranscriptionBenchmark(
                          models: widget.models,
                          testFiles: widget.testFiles,
                        );
                      },
                child: const Text('Start Benchmark'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _TranscriptionResultsList(
                  metricsList: state.metricsList,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TranscriptionResultsList extends StatelessWidget {
  final List<BenchmarkMetrics> metricsList;

  const _TranscriptionResultsList({required this.metricsList});

  @override
  Widget build(BuildContext context) {
    if (metricsList.isEmpty) {
      return const Center(child: Text('No results yet'));
    }

    // Group by modelName + modelType (though modelType is usually 'offline' here)
    final grouped = <String, List<BenchmarkMetrics>>{};
    for (final m in metricsList) {
      final key = '${m.modelName}___${m.modelType}';
      grouped.putIfAbsent(key, () => []).add(m);
    }

    final keys = grouped.keys.toList();

    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final items = grouped[key]!;
        final first = items.first;
        final modelName = first.modelName;
        final modelType = first.modelType;

        return ExpansionTile(
          title: Text('$modelName ($modelType)'),
          subtitle: Text('${items.length} files processed'),
          children: [
            for (final metric in items)
              ListTile(
                title: Text(p.basename(metric.fileName)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recognized: ${metric.transcription}'),
                    Text('Actual: ${metric.reference}'),
                    Text('Duration: ${metric.durationMs} ms'),
                    Text('RTF: ${metric.rtf.toStringAsFixed(2)}'),
                    Text(
                        'WER: ${(metric.werStats.wer * 100).toStringAsFixed(2)}%'),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
