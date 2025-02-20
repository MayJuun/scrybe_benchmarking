import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:path/path.dart' as p;

/// This screen simulates "dictation" (live streaming) from .wav assets.
/// The audio is chunked in 30ms increments, partial results for online models, etc.
class DictationBenchmarkScreen extends ConsumerStatefulWidget {
  final List<OnlineRecognizerConfig> onlineConfigs;
  final List<OfflineRecognizerConfig> offlineConfigs;

  const DictationBenchmarkScreen({
    super.key,
    required this.onlineConfigs,
    required this.offlineConfigs,
  });

  @override
  ConsumerState<DictationBenchmarkScreen> createState() =>
      _DictationBenchmarkScreenState();
}

class _DictationBenchmarkScreenState
    extends ConsumerState<DictationBenchmarkScreen> {
  @override
  void initState() {
    super.initState();
    // Load test .wav files
    ref.read(dictationBenchmarkNotifierProvider.notifier).loadTestFiles();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dictationBenchmarkNotifierProvider);
    final notifier = ref.read(dictationBenchmarkNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictation Benchmark'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Found ${state.testFiles.length} test files'),
            const SizedBox(height: 16),
            if (state.isBenchmarking) ...[
              Text('Current file: ${state.currentFile}'),
              LinearProgressIndicator(value: state.progress),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: DictationDisplay(
                    text: state.recognizedText,
                  ),
                ),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: state.testFiles.isEmpty
                    ? null
                    : () {
                        notifier.runBenchmark(
                          onlineConfigs: widget.onlineConfigs,
                          offlineConfigs: widget.offlineConfigs,
                        );
                      },
                child: const Text('Start Benchmark'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: state.results.keys.length,
                  itemBuilder: (context, index) {
                    final modelName = state.results.keys.elementAt(index);
                    final modelInfo = state.results[modelName]!;
                    final fileMap = modelInfo['files']
                        as Map<String, Map<String, dynamic>>;
                    final modelType = modelInfo['type'] as String;

                    return ExpansionTile(
                      title: Text('$modelName ($modelType)'),
                      subtitle: Text('${fileMap.length} files processed'),
                      children: [
                        for (final filePath in fileMap.keys)
                          ListTile(
                            title: Text(p.basename(filePath)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Text: ${fileMap[filePath]!['text']}'),
                                Text(
                                  'Duration: ${fileMap[filePath]!['duration_ms']} ms',
                                ),
                                Text(
                                  'RTF: ${fileMap[filePath]!['real_time_factor'].toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
