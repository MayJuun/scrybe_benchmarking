// benchmark_service.dart
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
    onProgressUpdate(
      BenchmarkProgress(
        currentModel: 'Complete',
        currentFile: 'All models processed',
        processedFiles: 1,
        totalFiles: 1,
        werScore: 0.0,
      ),
    );
  }

  Future<void> _runBenchmarkForModel({
    required AsrModel asrModel,
    PunctuationModel? punctuationModel,
    required Function(BenchmarkProgress) onProgressUpdate,
  }) async {
    try {
      final modelBundle = await _initSherpaModel(
        asrModel: asrModel,
        punctuationModel: punctuationModel,
      );

      // We'll store the CSV lines for WER_results here:
      final csvBuffer = StringBuffer();
      // Updated header to include decodeTimeSeconds, chunkAudioSeconds
      csvBuffer.writeln(
          'chunkPath,refWords,hypWords,WER(%),decodeTimeSeconds,chunkAudioSeconds');

      // We'll count total .wav files, then process them one by one
      final topDir = Directory(curatedDir);
      final allSubs =
          topDir.listSync(recursive: true).whereType<Directory>().toList();
      int totalFiles = 0;
      for (final subDir in allSubs) {
        final files = subDir.listSync().whereType<File>().toList();
        totalFiles += files.where((f) => p.extension(f.path) == '.wav').length;
      }

      int processedFiles = 0;
      double totalWer = 0.0;

      // Process each .wav chunk in each subdirectory
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
              onProgressUpdate: (progress) => onProgressUpdate(
                progress.copyWith(
                  processedFiles: processedFiles,
                  totalFiles: totalFiles,
                  werScore:
                      (processedFiles > 0) ? totalWer / processedFiles : 0.0,
                ),
              ),
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
              werScore: (processedFiles > 0) ? totalWer / processedFiles : 0.0,
              error: 'Error processing ${wavFile.path}: $e',
            ));
          }
        }
      }

      // Write out the final CSV for this model
      final summaryCsvPath =
          p.join(derivedDir, asrModel.name, 'WER_results.csv');
      await File(summaryCsvPath).writeAsString(csvBuffer.toString());

      modelBundle.free();

      // Final update for this model
      onProgressUpdate(
        BenchmarkProgress(
          currentModel: asrModel.name,
          currentFile: 'Complete',
          processedFiles: processedFiles,
          totalFiles: totalFiles,
          werScore: (processedFiles > 0) ? totalWer / processedFiles : 0.0,
        ),
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
      rethrow;
    }
  }

  Future<ModelBundle> _initSherpaModel({
    required AsrModel asrModel,
    required PunctuationModel? punctuationModel,
  }) async {
    sherpa.initBindings();
    final modelDir = p.join(Directory.current.path, 'assets', 'models');
    print('Model directory: ${asrModel.name}');

    switch (asrModel.modelType) {
      // === OFFLINE ===
      case SherpaModelType.whisper:
      case SherpaModelType.zipformer: // offline Zipformer transducer
      case SherpaModelType.transducer: // offline generic transducer
      case SherpaModelType.moonshine:
      case SherpaModelType.nemoTransducer:
      case SherpaModelType.nemoCtcOffline: // offline Nemo CTC
      case SherpaModelType.telespeechCtc:
      case SherpaModelType.tdnn:
      case SherpaModelType.wenetCtc:
        final offlineModelBundle =
            OfflineModelBundle.fromModel(asrModel, modelDir);
        offlineModelBundle.initPunctuation(punctuationModel, modelDir);
        return offlineModelBundle;

      // === ONLINE (STREAMING) ===
      case SherpaModelType.zipformer2: // streaming Zipformer transducer
      case SherpaModelType.zipformer2Ctc: // streaming Zipformer2 CTC
      case SherpaModelType.conformer:
      case SherpaModelType.lstm:
      case SherpaModelType.nemoCtcOnline: // streaming Nemo CTC
        final onlineModelBundle =
            OnlineModelBundle.fromModel(asrModel, modelDir);
        onlineModelBundle.initPunctuation(punctuationModel, modelDir);
        return onlineModelBundle;

      // === UNIMPLEMENTED ===
      case SherpaModelType.paraformer:
        throw UnimplementedError();
    }
  }

  Future<double?> _getAudioDuration(String wavPath) async {
    final result = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'format=duration',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      wavPath,
    ]);

    if (result.exitCode != 0) {
      stderr.writeln('ffprobe error: ${result.stderr}');
      return null;
    }

    final output = result.stdout.toString().trim();
    if (output.isEmpty) return null;

    return double.tryParse(output);
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

    // If no transcript, skip
    if (!srtFile.existsSync()) {
      print('No matching SRT for $wavFile => skip');
      return null;
    }

    // Provide a quick progress update for this file
    onProgressUpdate(
      BenchmarkProgress(
        currentModel: asrModel.name,
        currentFile: wavFile.path,
        processedFiles: 0,
        totalFiles: 1,
      ),
    );

    // Parse reference text from the SRT
    final referenceText = await _parseSrtFile(srtFile);

    // Time how long decodeAudioFile() takes
    final stopwatch = Stopwatch()..start();
    final recognizedText = await modelBundle.decodeAudioFile(wavFile.path);
    stopwatch.stop();

    final decodeTimeSeconds = stopwatch.elapsedMilliseconds / 1000.0;

    // Apply punctuation if needed
    final cleanedText = recognizedText.toLowerCase().trim();
    final finalText = await modelBundle.applyPunctuation(cleanedText);

    // Compute WER
    final wer = WerCalculator.computeWer(referenceText, finalText) * 100.0;

    final maybeDuration = await _getAudioDuration(wavFile.path);
    if (maybeDuration == null) {
      // Handle error case or default to 0
      throw Exception('Failed to get duration for ${wavFile.path}');
    }
    final chunkAudioSeconds = maybeDuration;

    // Build subdirectory for storing results for this chunk
    final relativeDir = p.relative(p.dirname(wavFile.path), from: curatedDir);
    final fileBaseName = p.basenameWithoutExtension(wavFile.path);
    final outSubDir =
        Directory(p.join(derivedDir, asrModel.name, relativeDir, fileBaseName));
    await outSubDir.create(recursive: true);

    // Save generated SRT
    final outSrtFilePath = p.join(outSubDir.path, '$fileBaseName.srt');
    await File(outSrtFilePath)
        .writeAsString(_generateSrt(finalText, chunkAudioSeconds));

    // Save a quick comparison text file
    final outComparisonFilePath = p.join(outSubDir.path, '$fileBaseName.txt');
    await File(outComparisonFilePath).writeAsString(
      'Reference: $referenceText\n'
      'Hypothesis: $finalText\n'
      'WER: ${wer.toStringAsFixed(2)}%\n'
      'DecodeTime(s): ${decodeTimeSeconds.toStringAsFixed(2)}\n',
    );

    // Return a CSV line with decodeTimeSeconds and chunkAudioSeconds
    final csvLine = [
      wavFile.path, // chunkPath
      referenceText.split(' ').length, // refWords
      finalText.split(' ').length, // hypWords
      wer.toStringAsFixed(2), // WER(%)
      decodeTimeSeconds.toStringAsFixed(2), // decodeTimeSeconds
      chunkAudioSeconds.toStringAsFixed(2), // chunkAudioSeconds
    ].join(',');

    return ProcessingResult(
      csvLine: csvLine,
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

  String _generateSrt(String text, double durationSeconds) {
    Duration duration =
        Duration(microseconds: (durationSeconds * 1000000).round());
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
