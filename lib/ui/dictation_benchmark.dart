import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

// This is just a simple UI that shows the recognized text and
// has a button to start or stop the entire benchmark across models.

class DictationBenchmarkScreen extends ConsumerStatefulWidget {
  final List<ModelBase> models;

  const DictationBenchmarkScreen({
    super.key,
    required this.models,
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
    // The user picks one model in a provider, but we also run multiple if needed
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
            // Show recognized text so far (the final transcript or partial accumulation)
            Expanded(
              child: SingleChildScrollView(
                reverse: true,
                child: DictationDisplay(
                  text: dictationState?.fullTranscript ?? '',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Show the current chunk/hypothesis text, if you want to see partial updates
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
                // If we are currently recording for a model, we stop
                if (dictationState?.status == DictationStatus.recording) {
                  final notifier = ref.read(
                      dictationBenchmarkProvider(selectedModel!).notifier);
                  notifier.stopDictation();
                  return;
                }

                // Otherwise, we do a full run of all models
                print('Number of models to test: ${widget.models.length}');
                final allMetrics = <BenchmarkMetrics>[];

                for (final model in widget.models) {
                  print('Running benchmark with model: ${model.modelName}');
                  // Mark this as the selected model
                  ref.read(selectedModelProvider.notifier).state = model;

                  final notifier =
                      ref.read(dictationBenchmarkProvider(model).notifier);

                  // Start the dictation on the current model
                  await notifier.startDictation();
                  // Once it completes, gather metrics
                  allMetrics.addAll(notifier.metrics);
                }

                final Directory directory =
                    await getApplicationDocumentsDirectory();
                // After all models are done, generate a consolidated report
                final outputDir =
                    Directory(p.join(directory.path, 'dictation_test'));
                if(!outputDir.existsSync()) {
                  outputDir.createSync();
                }
                final reportGenerator = BenchmarkReportGenerator(
                  metricsList: allMetrics,
                  outputDir: outputDir.path,
                );
                await reportGenerator.generateReports();
                print('Generated benchmark reports in benchmark_results/');
              },
            ),

            // Optional: show model name or errors
            if (selectedModel != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  selectedModel.modelName,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),

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
