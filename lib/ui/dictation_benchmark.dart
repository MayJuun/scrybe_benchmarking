import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class DictationBenchmarkScreen extends ConsumerStatefulWidget {
  final List<ModelBase> models;

  const DictationBenchmarkScreen({super.key, required this.models});

  @override
  ConsumerState<DictationBenchmarkScreen> createState() =>
      _DictationBenchmarkScreenState();
}

class _DictationBenchmarkScreenState
    extends ConsumerState<DictationBenchmarkScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // Dispose all models
    for (var model in widget.models) {
      model.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedModel = ref.watch(selectedModelProvider);
    final dictationState = selectedModel != null
        ? ref.watch(dictationBenchmarkProvider(selectedModel))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ASR Tester'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Show recognized text
            Expanded(
              child: SingleChildScrollView(
                reverse: true,
                child: DictationDisplay(
                  text: dictationState?.fullTranscript ?? '',
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Show recognized text
            Expanded(
              child: SingleChildScrollView(
                reverse: true,
                child: DictationDisplay(
                  text: dictationState?.currentChunkText ?? '',
                ),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: Icon(
                dictationState?.status == DictationStatus.recording
                    ? Icons.stop
                    : Icons.mic,
              ),
              label: Text(
                dictationState?.status == DictationStatus.recording
                    ? 'Stop Test'
                    : 'Start Test',
              ),
              onPressed: () async {
                if (dictationState?.status == DictationStatus.recording) {
                  // Stop the current dictation for the selected model
                  final notifier = ref.read(
                      dictationBenchmarkProvider(selectedModel!).notifier);
                  notifier.stopDictation();
                } else {
                  print('number of models: ${widget.models.length}');
                  final allMetrics = <BenchmarkMetrics>[];

                  for (final model in widget.models) {
                    print('model: ${model.modelName}');
                    // Set the current model
                    ref.read(selectedModelProvider.notifier).state = model;

                    // Use the model directly when fetching the notifier
                    final notifier =
                        ref.read(dictationBenchmarkProvider(model).notifier);

                    // Run the model and collect its metrics
                    await notifier.startDictation();
                    allMetrics.addAll(notifier.metrics);
                  }

                  final outputDir = Directory(
                      '${Directory.current.path}/assets/dictation_test');

                  // Generate consolidated report after all models finish
                  final reportGenerator = BenchmarkReportGenerator(
                    metricsList: allMetrics,
                    outputDir: outputDir.path,
                  );
                  await reportGenerator.generateReports();
                  print('Generated benchmark reports in benchmark_results/');
                }
              },
            ),
            // Error message if any
            if (selectedModel != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  selectedModel.modelName,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),

            // Error message if any
            if (dictationState?.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  dictationState!.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
