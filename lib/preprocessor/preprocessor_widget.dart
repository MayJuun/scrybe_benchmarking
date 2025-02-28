import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class PreprocessorWidget extends ConsumerWidget {
  const PreprocessorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preprocessorProvider = ref.watch(preprocessorNotifierProvider);
    final preprocessorNotifier =
        ref.read(preprocessorNotifierProvider.notifier);

    return Column(children: [
      /// Information to convert files
      Column(
        children: [
          const Text(
              'Select the Durations (seconds)\n'
              'to Convert Your Audio Files',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    ]);
  }
}
