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
    final dictationState =
        selectedModel != null && selectedModel is OfflineModel
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

            // Model dropdown
            DropdownButtonFormField<String>(
              value: selectedModel?.modelName,
              decoration: const InputDecoration(
                labelText: 'Select Model',
                border: OutlineInputBorder(),
              ),
              items: widget.models
                  .map((e) => e.modelName)
                  .map((name) => DropdownMenuItem(
                        value: name,
                        child: Text(name),
                      ))
                  .toList(),
              onChanged: (selected) {
                if (selected != null) {
                  // Stop current dictation if any
                  if (selectedModel != null && selectedModel is OfflineModel) {
                    ref
                        .read(dictationBenchmarkProvider(selectedModel).notifier)
                        .stopDictation();
                  }
                  // Select new model
                  ref.read(selectedModelProvider.notifier).state =
                      widget.models.where((e) => e.modelName == selected).first;
                }
              },
            ),
            const SizedBox(height: 16),

            // Start/Stop button
            if (selectedModel != null) ...[
              ElevatedButton.icon(
                icon: Icon(
                  dictationState?.status == DictationStatus.recording
                      ? Icons.stop
                      : Icons.mic,
                ),
                label: Text(
                  dictationState?.status == DictationStatus.recording
                      ? 'Stop'
                      : 'Start',
                ),
                onPressed: () {
                  if (selectedModel is OfflineModel) {
                    final notifier = ref.read(
                        dictationBenchmarkProvider(selectedModel).notifier);
                    if (dictationState?.status == DictationStatus.recording) {
                      notifier.stopDictation();
                    } else {
                      notifier.startDictation();
                    }
                  }
                },
              ),
            ],

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
