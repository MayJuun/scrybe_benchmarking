import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:path/path.dart' as p;

/// This screen decodes entire `.wav` files at once (no chunking).
class TranscriptionBenchmarkScreen extends ConsumerStatefulWidget {
  final List<OfflineRecognizerConfig> offlineConfigs;

  const TranscriptionBenchmarkScreen({
    super.key,
    required this.offlineConfigs,
  });

  @override
  ConsumerState<TranscriptionBenchmarkScreen> createState() =>
      _TranscriptionBenchmarkScreenState();
}

class _TranscriptionBenchmarkScreenState
    extends ConsumerState<TranscriptionBenchmarkScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transcriptionBenchmarkNotifierProvider);
    final notifier = ref.read(transcriptionBenchmarkNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcription Benchmark'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Found ${state.testFiles.length} test files'),
            const SizedBox(height: 16),
            if (state.isTranscribing) ...[
              Text('Current file: ${state.currentFile}'),
              LinearProgressIndicator(value: state.progress),
              const SizedBox(height: 16),
              const Expanded(child: Center(child: Text('Transcribing...'))),
            ] else ...[
              ElevatedButton(
                onPressed: state.testFiles.isEmpty
                    ? null
                    : () {
                        notifier.runTranscriptionBenchmark(
                          offlineConfigs: widget.offlineConfigs,
                        );
                      },
                child: const Text('Start Benchmark'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _ResultsList(results: state.results),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  final Map<String, Map<String, dynamic>> results;

  const _ResultsList({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(child: Text('No results yet'));
    }
    return ListView.builder(
      itemCount: results.keys.length,
      itemBuilder: (context, index) {
        final modelName = results.keys.elementAt(index);
        final modelInfo = results[modelName]!;
        final filesMap = modelInfo['files'] as Map<String, dynamic>;
        final modelType = modelInfo['type'] as String;

        return ExpansionTile(
          title: Text('$modelName ($modelType)'),
          subtitle: Text('${filesMap.length} files processed'),
          children: filesMap.keys.map((filePath) {
            final data = filesMap[filePath] as Map<String, dynamic>;
            final text = data['text'] ?? '';
            final duration = data['duration_ms'] ?? 0;
            final rtf = data['real_time_factor'] ?? 0.0;
            return ListTile(
              title: Text(p.basename(filePath)),
              subtitle: Text(
                'Text: $text\nDuration: ${duration}ms\nRTF: ${rtf.toStringAsFixed(2)}',
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
