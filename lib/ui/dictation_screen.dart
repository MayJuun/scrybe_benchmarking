import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// A typical "ASR Tester" screen with a mic button for live dictation.
class DictationScreen extends ConsumerStatefulWidget {
  final List<OnlineRecognizerConfig> onlineModels;
  final List<OfflineRecognizerConfig> offlineModels;

  const DictationScreen({
    super.key,
    required this.onlineModels,
    required this.offlineModels,
  });

  @override
  ConsumerState<DictationScreen> createState() => _DictationScreenState();
}

class _DictationScreenState extends ConsumerState<DictationScreen> {
  @override
  void initState() {
    super.initState();
    // Request mic permission after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dictationNotifierProvider.notifier).requestMicPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dictationState = ref.watch(dictationNotifierProvider);
    final dictationNotifier = ref.read(dictationNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ASR Tester'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // If model is loading, show progress
            if (dictationState.isModelLoading)
              const LinearProgressIndicator()
            else
              const SizedBox(height: 4),

            // Show recognized text
            Expanded(
              child: SingleChildScrollView(
                reverse: true,
                child: DictationDisplay(
                  text: dictationState.recognizedText,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Model dropdown
            DropdownButtonFormField<String>(
              value: dictationState.selectedModelName,
              decoration: const InputDecoration(
                labelText: 'Select Model',
                border: OutlineInputBorder(),
              ),
              items: [
                ...widget.offlineModels.map(
                  (m) => DropdownMenuItem(
                    value: m.modelName,
                    child: Text(m.modelName),
                  ),
                ),
                ...widget.onlineModels.map(
                  (m) => DropdownMenuItem(
                    value: m.modelName,
                    child: Text(m.modelName),
                  ),
                ),
              ],
              onChanged: dictationState.isModelLoading
                  ? null
                  : (selected) {
                      if (selected != null &&
                          selected != dictationState.selectedModelName) {
                        dictationNotifier.initializeDictation(
                          modelName: selected,
                          onlineModels: widget.onlineModels,
                          offlineModels: widget.offlineModels,
                        );
                      }
                    },
            ),
            const SizedBox(height: 16),

            // Start/Stop mic button
            ElevatedButton.icon(
              icon: Icon(
                dictationState.isRecording ? Icons.stop : Icons.mic,
              ),
              label: Text(
                dictationState.isRecording ? 'Stop' : 'Start',
              ),
              onPressed: dictationState.isModelLoading
                  ? null
                  : dictationNotifier.toggleRecording,
            ),
          ],
        ),
      ),
    );
  }
}
