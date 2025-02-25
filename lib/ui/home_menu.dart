import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class HomeMenuScreen extends ConsumerWidget {
  const HomeMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(loadModelsNotifierProvider);

    // We'll read the dictation benchmark provider to get its Notifier,
    // or we can do so inline.
    // final dictationBenchNotifier =
    //     ref.read(dictationBenchmarkNotifierProvider.notifier);

    // Similarly for transcription if you want to pre-load files or something
    final transcriptionBenchNotifier =
        ref.read(transcriptionBenchmarkNotifierProvider.notifier);

    // We'll read the preprocessor provider to get its Notifier,
    // or we can do so inline.
    final preprocessorProvider = ref.watch(preprocessorNotifierProvider);

    final preprocessorNotifier =
        ref.read(preprocessorNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scrybe Mobile Menu'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Live Dictation
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          DictationScreen(models: modelState.models),
                    ),
                  );
                },
                child: const Text('Live Dictation'),
              ),
              const SizedBox(height: 24),

              // Dictation Benchmarks (simulate streaming)
              ElevatedButton(
                onPressed: () async {
                  // Load test files first if needed
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DictationBenchmarkScreen(models: modelState.models),
                      ),
                    );
                  }
                },
                child: const Text('Dictation Benchmarks'),
              ),
              const SizedBox(height: 24),

              // Transcription Benchmarks (full-file approach)
              ElevatedButton(
                onPressed: () async {
                  // If you want to pre-load .wav file list for the transcription
                  await transcriptionBenchNotifier.loadTestFiles();
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TranscriptionBenchmarkScreen(
                          offlineConfigs: [],
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Transcription Benchmarks'),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  const Text(
                      'Select the Durations (seconds)\n'
                      'to Convert Your Audio Files',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: preprocessorNotifier.targetDuration,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Target',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: preprocessorNotifier.minDuration,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Minimum',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: preprocessorNotifier.maxDuration,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Maximum',
                          ),
                        ),
                      )
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  // We'll call preprocessorNotifier.convertRawFiles()
                  // Instead of new ASRPreprocessor().convertRawFiles().
                  // This updates progress in state
                  await preprocessorNotifier.convertRawFiles();
                },
                child: const Text('Process Files'),
              ),
              const SizedBox(height: 24),

              // Show progress if isConverting
              if (preprocessorProvider.isConverting) ...[
                LinearProgressIndicator(value: preprocessorProvider.progress),
                const SizedBox(height: 8),
                Text(
                  'Processing file #${preprocessorProvider.processed} '
                  'of ${preprocessorProvider.total}\n'
                  '${preprocessorProvider.currentFile}',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
