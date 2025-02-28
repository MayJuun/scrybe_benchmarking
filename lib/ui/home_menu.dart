import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class HomeMenuScreen extends ConsumerWidget {
  const HomeMenuScreen(this.models, {super.key});

  final List<AsrModel> models;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      builder: (_) => DictationScreen(models: models),
                    ),
                  );
                },
                child: const Text('Live Dictation'),
              ),
              const SizedBox(height: 24),

              // Dictation Benchmarks (simulate streaming)
              ElevatedButton(
                onPressed: () async {
                  ref.read(dictationFilesProvider).whenData((data) {
                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DictationBenchmarkScreen(
                              models: models, testFiles: data),
                        ),
                      );
                    }
                  });
                },
                child: const Text('Dictation Benchmarks'),
              ),
              const SizedBox(height: 24),

              // Transcription Benchmarks (full-file approach)
              ElevatedButton(
                onPressed: () async {
                  ref.read(transcriptionFilesProvider).whenData((data) {
                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TranscriptionBenchmarkScreen(
                            models: models
                                .whereType<OfflineRecognizerModel>()
                                .toList(),
                            testFiles: data,
                          ),
                        ),
                      );
                    }
                  });
                },
                child: const Text('Transcription Benchmarks'),
              ),
              const SizedBox(height: 24),
              PreprocessorWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
