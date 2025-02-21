// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
// import 'package:sherpa_onnx/sherpa_onnx.dart';
// import 'package:path/path.dart' as p;

// /// This screen simulates "dictation" (live streaming) from .wav assets.
// /// The audio is chunked in 30ms increments, partial results for online models, etc.
// class DictationBenchmarkScreen extends ConsumerStatefulWidget {
//   final List<OnlineRecognizerConfig> onlineConfigs;
//   final List<OfflineRecognizerConfig> offlineConfigs;

//   const DictationBenchmarkScreen({
//     super.key,
//     required this.onlineConfigs,
//     required this.offlineConfigs,
//   });

//   @override
//   ConsumerState<DictationBenchmarkScreen> createState() =>
//       _DictationBenchmarkScreenState();
// }

// class _DictationBenchmarkScreenState
//     extends ConsumerState<DictationBenchmarkScreen> {
//   @override
//   void initState() {
//     super.initState();
//     // Load test .wav files
//     ref.read(dictationBenchmarkNotifierProvider.notifier).loadTestFiles();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final state = ref.watch(dictationBenchmarkNotifierProvider);
//     final notifier = ref.read(dictationBenchmarkNotifierProvider.notifier);

//     final isRunning = state.isBenchmarking;
//     final fileCount = state.testFiles.length;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Dictation Benchmark'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             Text('Found $fileCount test files'),
//             const SizedBox(height: 16),

//             if (isRunning) ...[
//               Text('Current file: ${state.currentFile}'),
//               LinearProgressIndicator(value: state.progress),
//               const SizedBox(height: 16),
//               Expanded(
//                 child: SingleChildScrollView(
//                   child: DictationDisplay(
//                     text: state.recognizedText,
//                   ),
//                 ),
//               ),
//             ] else ...[
//               ElevatedButton(
//                 onPressed: fileCount == 0
//                     ? null
//                     : () {
//                         notifier.runBenchmark(
//                           onlineConfigs: widget.onlineConfigs,
//                           offlineConfigs: widget.offlineConfigs,
//                         );
//                       },
//                 child: const Text('Start Benchmark'),
//               ),
//               const SizedBox(height: 16),

//               // Once not benchmarking, show the final results from metricsList
//               Expanded(
//                 child: _DictationResultsList(metricsList: state.metricsList),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _DictationResultsList extends StatelessWidget {
//   final List<BenchmarkMetrics> metricsList;

//   const _DictationResultsList({required this.metricsList});

//   @override
//   Widget build(BuildContext context) {
//     if (metricsList.isEmpty) {
//       return const Center(
//         child: Text('No results yet'),
//       );
//     }

//     // Group them by (modelName, modelType)
//     final grouped = <String, List<BenchmarkMetrics>>{};

//     for (final m in metricsList) {
//       final key = '${m.modelName}___${m.modelType}';
//       grouped.putIfAbsent(key, () => []).add(m);
//     }

//     final keys = grouped.keys.toList();

//     return ListView.builder(
//       itemCount: keys.length,
//       itemBuilder: (context, index) {
//         final key = keys[index];
//         final items = grouped[key]!;
//         // each item has same modelName/modelType, so we can pick from first
//         final first = items.first;
//         final modelName = first.modelName;
//         final modelType = first.modelType;

//         return ExpansionTile(
//           title: Text('$modelName ($modelType)'),
//           subtitle: Text('${items.length} files processed'),
//           children: [
//             for (final metric in items)
//               ListTile(
//                 title: Text(p.basename(metric.fileName)),
//                 subtitle: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text('Recognized: ${metric.transcription}'),
//                     Text('Duration: ${metric.durationMs} ms'),
//                     Text('RTF: ${metric.rtf.toStringAsFixed(2)}'),
//                     Text('WER: ${(metric.werStats.wer * 100).toStringAsFixed(2)}%'),
//                   ],
//                 ),
//               ),
//           ],
//         );
//       },
//     );
//   }
// }
