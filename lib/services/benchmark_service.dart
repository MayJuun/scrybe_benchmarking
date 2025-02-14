// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class BenchmarkService {
  final String curatedDir;
  final String derivedDir;
  final List<AsrModel> asrModels;
  final List<PunctuationModel> punctuationModels;

  BenchmarkService({
    required this.curatedDir,
    required this.derivedDir,
    required this.asrModels,
    this.punctuationModels = const [],
  });

  Future<void> runBenchmark({
    required Function(BenchmarkProgress) onProgressUpdate,
  }) async {
    // Validate directories
    for (final dir in [curatedDir, derivedDir]) {
      if (!await FileUtils.validateDirectory(dir)) {
        throw Exception('Required directory does not exist: $dir');
      }
    }

    int totalModels = asrModels.length;
    int currentModelIndex = 0;

    for (final asrModel in asrModels) {
      currentModelIndex++;

      try {
        // Process each model with optional punctuation
        await _runBenchmarkForModel(
          asrModel: asrModel,
          punctuationModel:
              punctuationModels.isNotEmpty ? punctuationModels.first : null,
          onProgressUpdate: (progress) {
            onProgressUpdate(progress.copyWith(
              currentModel:
                  'Model $currentModelIndex of $totalModels: ${progress.currentModel}',
            ));
          },
        );
      } catch (e, stack) {
        print('Error processing model ${asrModel.name}: $e\n$stack');
        onProgressUpdate(BenchmarkProgress(
          currentModel: asrModel.name,
          currentFile: 'Failed',
          processedFiles: 0,
          totalFiles: 0,
          werScore: 0.0,
          error: 'Error processing model ${asrModel.name}: $e',
        ));
      }
    }

    // Final completion update
    onProgressUpdate(BenchmarkProgress(
      currentModel: 'Complete',
      currentFile: 'All models processed',
      processedFiles: 1,
      totalFiles: 1,
      werScore: 0.0,
    ));
  }

  Future<void> _runBenchmarkForModel({
    required AsrModel asrModel,
    PunctuationModel? punctuationModel,
    required Function(BenchmarkProgress) onProgressUpdate,
  }) async {
    try {
      print('Initializing Sherpa Onnx model ${asrModel.name}');
      final modelBundle = await _initSherpaModel(
        asrModel: asrModel,
        punctuationModel: punctuationModel,
      );

      // final asrRecognizer = modelBundle.asrRecognizer;
      final topDir = Directory(curatedDir);
      final csvBuffer = StringBuffer();
      csvBuffer.writeln('chunkPath,refWords,hypWords,WER(%)');

      // Count total files for progress tracking
      final allSubs =
          topDir.listSync(recursive: true).whereType<Directory>().toList();
      int totalFiles = 0;
      for (final subDir in allSubs) {
        final files = subDir.listSync().whereType<File>().toList();
        totalFiles += files.where((f) => p.extension(f.path) == '.wav').length;
      }

      int processedFiles = 0;
      double totalWer = 0.0;

      // Process each subdirectory
      for (final subDir in allSubs) {
        final files = subDir.listSync().whereType<File>().toList();
        final chunkWavs = files.where((f) => p.extension(f.path) == '.wav');

        for (final wavFile in chunkWavs) {
          try {
            final result = await _processAudioFile(
              wavFile: wavFile,
              modelBundle: modelBundle,
              derivedDir: derivedDir,
              asrModel: asrModel,
              curatedDir: curatedDir,
              onProgressUpdate: (progress) =>
                  onProgressUpdate(progress.copyWith(
                processedFiles: processedFiles,
                totalFiles: totalFiles,
                werScore: processedFiles > 0 ? totalWer / processedFiles : 0.0,
              )),
            );

            if (result != null) {
              csvBuffer.writeln(result.csvLine);
              totalWer += result.wer;
              processedFiles++;
            }
          } catch (e, stack) {
            print('Error processing file ${wavFile.path}: $e\n$stack');
            onProgressUpdate(BenchmarkProgress(
              currentModel: asrModel.name,
              currentFile: wavFile.path,
              processedFiles: processedFiles,
              totalFiles: totalFiles,
              werScore: processedFiles > 0 ? totalWer / processedFiles : 0.0,
              error: 'Error processing ${wavFile.path}: $e',
            ));
          }
        }
      }

      // Write summary CSV
      final summaryCsvPath =
          p.join(derivedDir, asrModel.name, 'WER_results.csv');
      await File(summaryCsvPath).writeAsString(csvBuffer.toString());

      modelBundle.free();

      // Final model update
      onProgressUpdate(BenchmarkProgress(
        currentModel: asrModel.name,
        currentFile: 'Complete',
        processedFiles: processedFiles,
        totalFiles: totalFiles,
        werScore: processedFiles > 0 ? totalWer / processedFiles : 0.0,
      ));
    } catch (e, stack) {
      print('Error processing model ${asrModel.name}: $e\n$stack');
      onProgressUpdate(BenchmarkProgress(
        currentModel: asrModel.name,
        currentFile: 'Failed',
        processedFiles: 0,
        totalFiles: 0,
        werScore: 0.0,
        error: 'Error processing model ${asrModel.name}: $e',
      ));
      rethrow;
    }
  }

  Future<ModelBundle> _initSherpaModel({
    required AsrModel asrModel,
    required PunctuationModel? punctuationModel,
  }) async {
    sherpa.initBindings();
    final modelDir = p.join(Directory.current.path, 'assets', 'models');

    if (asrModel is WhisperModel) {
      return WhisperModelBundle.fromModel(asrModel, modelDir);
    } else {
      final onlineModelBundle = OnlineModelBundle.fromModel(asrModel, modelDir);
      onlineModelBundle.initPunctuation(punctuationModel, modelDir);
      return onlineModelBundle;
    }
  }

  Future<ProcessingResult?> _processAudioFile({
    required File wavFile,
    required ModelBundle modelBundle,
    required String derivedDir,
    required AsrModel asrModel,
    required String curatedDir,
    required Function(BenchmarkProgress) onProgressUpdate,
  }) async {
    final base = p.basenameWithoutExtension(wavFile.path);
    final srtFile = File(p.join(p.dirname(wavFile.path), '$base.srt'));

    if (!srtFile.existsSync()) {
      print('No matching SRT for $wavFile => skip');
      return null;
    }

    onProgressUpdate(BenchmarkProgress(
      currentModel: asrModel.name,
      currentFile: wavFile.path,
      processedFiles: 0,
      totalFiles: 1,
    ));

    final referenceText = await _parseSrtFile(srtFile);

    final recognizedText = await modelBundle.decodeAudioFile(wavFile.path);

    final cleanedText = recognizedText.toLowerCase().trim();

    final finalText = await modelBundle.applyPunctuation(cleanedText);

    final wer = WerCalculator.computeWer(referenceText, finalText) * 100.0;

    // Get the relative directory from curated (e.g., "<group>/<pair-folder>")
    final relativeDir = p.relative(p.dirname(wavFile.path), from: curatedDir);
    // Get the base name of the chunk file (e.g., "myfile_part1")
    final fileBaseName = p.basenameWithoutExtension(wavFile.path);
    // Create an extra subdirectory for this particular chunk
    final outSubDir =
        Directory(p.join(derivedDir, asrModel.name, relativeDir, fileBaseName));
    await outSubDir.create(recursive: true);

    // Save the generated SRT file
    final outSrtFilePath = p.join(outSubDir.path, '$fileBaseName.srt');
    await File(outSrtFilePath).writeAsString(_generateSrt(finalText));

    // Save the comparison text file (original transcript vs generated)
    final outComparisonFilePath = p.join(outSubDir.path, '$fileBaseName.txt');
    await File(outComparisonFilePath).writeAsString(
      'Reference: $referenceText\n'
      'Hypothesis: $finalText\n'
      'WER: ${wer.toStringAsFixed(2)}%\n',
    );

    return ProcessingResult(
      csvLine:
          '${wavFile.path},${referenceText.split(' ').length},${finalText.split(' ').length},${wer.toStringAsFixed(2)}',
      wer: wer,
    );
  }

  Future<String> _parseSrtFile(File srtFile) async {
    final lines = await srtFile.readAsLines();
    final buffer = <String>[];
    for (var line in lines) {
      line = line.trim();
      if (RegExp(r'^\d+$').hasMatch(line)) continue;
      if (line.contains('-->')) continue;
      if (line.isNotEmpty) buffer.add(line);
    }
    return buffer.join(' ');
  }

  String _generateSrt(String text) {
    const duration = Duration(seconds: 30);
    final startStr = _formatDuration(Duration.zero);
    final endStr = _formatDuration(duration);
    return '1\n$startStr --> $endStr\n$text\n';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$milliseconds';
  }

  void dispose() {}
}

class ProcessingResult {
  final String csvLine;
  final double wer;

  ProcessingResult({
    required this.csvLine,
    required this.wer,
  });
}
