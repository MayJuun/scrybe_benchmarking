// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:scrybe/scrybe_benchmark.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:wav/wav.dart';

class BenchmarkService {
  final String curatedDir;
  final String derivedDir;
  final List<AsrModel> asrModels;
  final List<PunctuationModel> punctuationModels;
  PunctuationService? _punctuationService;

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

      final asrRecognizer = modelBundle.asrRecognizer;
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
              asrRecognizer: asrRecognizer,
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

      asrRecognizer.free();

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

  Future<SherpaModelBundle> _initSherpaModel({
    required AsrModel asrModel,
    required PunctuationModel? punctuationModel,
  }) async {
    sherpa.initBindings();
    final modelDir = p.join(Directory.current.path, 'assets', 'models');

    final asrConfig = sherpa.OnlineRecognizerConfig(
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: p.join(modelDir, asrModel.encoder),
          decoder: p.join(modelDir, asrModel.decoder),
          joiner: p.join(modelDir, asrModel.joiner),
        ),
        tokens: p.join(modelDir, asrModel.tokens),
        numThreads: 1,
        modelType: asrModel.modelType,
        debug: false,
      ),
    );
    final asrRecognizer = sherpa.OnlineRecognizer(asrConfig);

    if (punctuationModel != null) {
      _punctuationService = PunctuationService(type: PunctuationType.online);
      await _punctuationService!.initialize(
        modelDir: p.join(modelDir, punctuationModel.name),
      );
    }

    return SherpaModelBundle(
      asrRecognizer: asrRecognizer,
      punctuationRecognizer: null,
    );
  }

  Future<ProcessingResult?> _processAudioFile({
    required File wavFile,
    required sherpa.OnlineRecognizer asrRecognizer,
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
    print('Got reference text: $referenceText');

    final recognizedText = await _decodeAudioFile(asrRecognizer, wavFile.path);
    print('Got recognized text: $recognizedText');

    final cleanedText = recognizedText.toLowerCase().trim();

    final finalText = await _applyPunctuation(cleanedText);
    print('Got final text after punctuation: $finalText');

    final wer = WerCalculator.computeWer(referenceText, finalText) * 100.0;
    print('Computed WER: $wer');

    final relativePath = p.relative(p.dirname(wavFile.path), from: curatedDir);
    final outSubDir =
        Directory(p.join(derivedDir, asrModel.name, relativePath));
    await outSubDir.create(recursive: true);

    final outSrtFilePath = p.join(outSubDir.path, '$base.srt');
    await File(outSrtFilePath).writeAsString(_generateSrt(finalText));

    final outWerFilePath = p.join(outSubDir.path, '$base-wer.txt');
    await File(outWerFilePath).writeAsString(
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

  Future<String> _decodeAudioFile(
    sherpa.OnlineRecognizer recognizer,
    String wavPath,
  ) async {
    print('Decoding file: $wavPath');
    final stream = recognizer.createStream();
    final samples = await _loadWavAsFloat32(wavPath);

    print('Loaded ${samples.length} samples');

    stream.acceptWaveform(samples: samples, sampleRate: 16000);

    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
      // Optionally print intermediate results
      print('Intermediate result: ${recognizer.getResult(stream).text}');
    }

    final text = recognizer.getResult(stream).text;
    print('Final recognition result: $text');
    stream.free();
    return text;
  }

  Future<String> _applyPunctuation(String text) async {
    if (_punctuationService == null) return text;
    return _punctuationService!.addPunctuation(text);
  }

  Future<Float32List> _loadWavAsFloat32(String wavPath) async {
    final fileBytes = await File(wavPath).readAsBytes();
    final wavFile = Wav.read(fileBytes);

    if (wavFile.channels.length != 1) {
      print('Warning: file has ${wavFile.channels.length} channels, expected 1');
    }
    if (wavFile.samplesPerSecond != 16000) {
      print('Warning: file has ${wavFile.samplesPerSecond} Hz, expected 16000');
    }

    final samplesFloat64 = wavFile.channels[0];
    final float32 = Float32List(samplesFloat64.length);

    for (int i = 0; i < samplesFloat64.length; i++) {
      float32[i] = samplesFloat64[i].toDouble().clamp(-1.0, 1.0);
    }

    return float32;
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

  void dispose() {
    _punctuationService?.dispose();
    _punctuationService = null;
  }
}

class SherpaModelBundle {
  final sherpa.OnlineRecognizer asrRecognizer;
  final sherpa.OnlineRecognizer? punctuationRecognizer;

  SherpaModelBundle({
    required this.asrRecognizer,
    this.punctuationRecognizer,
  });
}

class ProcessingResult {
  final String csvLine;
  final double wer;

  ProcessingResult({
    required this.csvLine,
    required this.wer,
  });
}
