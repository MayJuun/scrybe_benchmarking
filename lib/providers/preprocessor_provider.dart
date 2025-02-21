// preprocessor_notifier.dart

import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class PreprocessorState {
  final bool isConverting;
  final String currentFile;
  final int processed;
  final int total;
  final double progress; // 0..1

  const PreprocessorState({
    this.isConverting = false,
    this.currentFile = '',
    this.processed = 0,
    this.total = 0,
    this.progress = 0.0,
  });

  PreprocessorState copyWith({
    bool? isConverting,
    String? currentFile,
    int? processed,
    int? total,
    double? progress,
  }) {
    return PreprocessorState(
      isConverting: isConverting ?? this.isConverting,
      currentFile: currentFile ?? this.currentFile,
      processed: processed ?? this.processed,
      total: total ?? this.total,
      progress: progress ?? this.progress,
    );
  }
}

class PreprocessorNotifier extends Notifier<PreprocessorState> {
  final targetDuration = TextEditingController(text: '20.0');
  final minDuration = TextEditingController(text: '5.0');
  final maxDuration = TextEditingController(text: '30.0');

  @override
  PreprocessorState build() {
    return const PreprocessorState();
  }

  Future<void> convertRawFiles() async {
    // 1) Mark as converting
    state = state.copyWith(
        isConverting: true, processed: 0, total: 0, progress: 0.0);

    try {
      final rawDir = Directory(p.join(Directory.current.path, 'assets', 'raw'));
      // 2) Collect all directories and audio files up front
      final subDirs = rawDir.listSync().whereType<Directory>().toList();

      final curatedDir =
          Directory(p.join(Directory.current.path, 'assets', 'curated'));
      if (await curatedDir.exists()) {
        await curatedDir.delete(recursive: true);
      }
      await curatedDir.create(recursive: true);

      // We’ll do a quick pass to count total audio files:
      int totalAudioFiles = 0;
      for (final subDir in subDirs) {
        final audioFiles = subDir
            .listSync(recursive: true)
            .where((entity) =>
                entity is File &&
                ['.wav', '.mp3', '.m4a']
                    .contains(p.extension(entity.path).toLowerCase()))
            .length;
        totalAudioFiles += audioFiles;
      }

      // Update state with total
      state = state.copyWith(total: totalAudioFiles);

      // We'll create an instance of your ASRPreprocessor,
      // but we want to intercept its progress signals. We'll do so by injecting
      // a callback or something.
      var targetDur = double.tryParse(targetDuration.text);
      if (targetDur == null || targetDur <= 0) {
        targetDur = 20.0;
      }
      var minDur = double.tryParse(minDuration.text);
      if (minDur == null || minDur <= 0) {
        minDur = 5.0;
      }
      var maxDur = double.tryParse(maxDuration.text);
      if (maxDur == null || maxDur <= 0) {
        maxDur = 30.0;
      }
      final preprocessor = ASRPreprocessor(
        targetDuration: targetDur,
        minDuration: minDur,
        maxDuration: maxDur,
      );

      // 3) Process each subDir
      int processedCount = 0;
      for (final subDir in subDirs) {
        // Instead of calling preprocessor.convertRawDirectory(subDir),
        // we do our own logic so we can track each file’s progress:
        await _convertRawDirectoryWithProgress(subDir, preprocessor,
            onFileProcessed: (filePath) {
          processedCount++;
          final newProgress =
              (processedCount / totalAudioFiles).clamp(0.0, 1.0);
          state = state.copyWith(
            currentFile: filePath,
            processed: processedCount,
            progress: newProgress,
          );
        });
      }
    } catch (e, st) {
      print('Error in convertRawFiles: $e\n$st');
    } finally {
      // 4) Mark done
      state = state.copyWith(isConverting: false, currentFile: '');
    }
  }

  /// Helper that does the same as `ASRPreprocessor.convertRawDirectory`
  /// but also calls [onFileProcessed] after each file is done.
  Future<void> _convertRawDirectoryWithProgress(
    Directory rawDir,
    ASRPreprocessor preprocessor, {
    required void Function(String filePath) onFileProcessed,
  }) async {
    final audioFiles = await rawDir
        .list(recursive: true)
        .where((entity) =>
            entity is File &&
            ['.wav', '.mp3', '.m4a']
                .contains(p.extension(entity.path).toLowerCase()))
        .toList();

    for (var entity in audioFiles) {
      final audioFile = entity as File;

      // Find matching transcript
      final baseName = p.basenameWithoutExtension(audioFile.path);
      final possibleTranscripts = [
        File(p.join(p.dirname(audioFile.path), '$baseName.srt')),
        File(p.join(p.dirname(audioFile.path), '$baseName.json')),
        File(p.join(p.dirname(audioFile.path), '$baseName.txt')),
      ];

      File? transcriptFile;
      for (final t in possibleTranscripts) {
        if (await t.exists()) {
          transcriptFile = t;
          break;
        }
      }

      if (transcriptFile == null) {
        print('Warning: No transcript for ${audioFile.path}');
        continue;
      }

      // Call your existing method
      await preprocessor.process(transcriptFile.path, audioFile.path);

      // Notify that we processed one file
      onFileProcessed(audioFile.path);
    }
  }
}

// Finally the provider:
final preprocessorNotifierProvider =
    NotifierProvider<PreprocessorNotifier, PreprocessorState>(
  PreprocessorNotifier.new,
);
