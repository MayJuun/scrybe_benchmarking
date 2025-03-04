import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

// This is just a simple UI that shows the recognized text and
// has a button to start or stop the entire benchmark across models.

class DictationBenchmarkScreen extends ConsumerStatefulWidget {
  final List<AsrModel> models;
  final AudioTestFiles testFiles;

  const DictationBenchmarkScreen({
    super.key,
    required this.models,
    required this.testFiles,
  });

  @override
  ConsumerState<DictationBenchmarkScreen> createState() =>
      _DictationBenchmarkScreenState();
}

class _DictationBenchmarkScreenState
    extends ConsumerState<DictationBenchmarkScreen> {
  @override
  Widget build(BuildContext context) {
    // The selected model is watched from a provider
    final selectedModel = ref.watch(selectedModelProvider);

    // The current dictation state if a model is selected
    final dictationState = selectedModel != null
        ? ref.watch(dictationBenchmarkProvider(selectedModel))
        : null;

    // For displaying the model index out of total models
    final modelIndex =
        selectedModel == null ? 0 : (widget.models.indexOf(selectedModel) + 1);
    final totalModels = widget.models.length;

    // For displaying the file index out of total files
    final fileIndex = widget.testFiles.currentFileIndex + 1;
    final totalFiles = widget.testFiles.length;

    // The current filename (just the basename if you want to hide the full path)
    final currentFileName = widget.testFiles.isEmpty
        ? ''
        : p.basename(widget.testFiles.currentFile);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ASR Tester'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // -----------------------------------
            // Display which model & which file
            // -----------------------------------
            Text(
              'Model $modelIndex of $totalModels'
              '${selectedModel != null ? ': ${selectedModel.modelName}' : ''}',
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 20),
            // Show file index & name
            Text(
              'File $fileIndex of $totalFiles'
              '${currentFileName.isNotEmpty ? ': $currentFileName' : ''}',
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 16),

            // Show recognized text so far (the final transcript)
            Expanded(
              child: SingleChildScrollView(
                reverse: true,
                child: DictationDisplay(
                  text: dictationState?.fullTranscript ?? '',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Show the current chunk/hypothesis text
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
                  notifier.stopDictation(fileRecorderProvider);
                  return;
                }

                // Otherwise, we do a full run of all models
                print('Number of models to test: ${widget.models.length}');
                final allMetrics = <BenchmarkMetrics>[];

                for (final model in widget.models) {
                  print('Running benchmark with model: ${model.modelName}');
                  ref.read(selectedModelProvider.notifier).state = model;

                  final notifier =
                      ref.read(dictationBenchmarkProvider(model).notifier);
                  widget.testFiles.currentFileIndex = 0;
                  notifier.setTestFiles(widget.testFiles);

                  await notifier.startDictation();

                  allMetrics.addAll(notifier.metrics);
                }

                final Directory directory =
                    await getApplicationDocumentsDirectory();
                // After all models are done, generate a consolidated report
                final outputDir =
                    Directory(p.join(directory.path, 'dictation_test'));
                if (!outputDir.existsSync()) {
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
