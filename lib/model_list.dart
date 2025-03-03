// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

Future<String> copyAssetFile(String? modelName, String file) async {
  final Directory directory = await getApplicationDocumentsDirectory();
  final target = modelName == null
      ? p.join(directory.path, file)
      : p.join(directory.path, modelName, file);
  bool exists = await File(target).exists();
  if (!exists) {
    await File(target).create(recursive: true);
  }
  final data = modelName == null
      ? await rootBundle.load(p.join('assets', 'models', file))
      : await rootBundle.load(p.join('assets', 'models', modelName, file));
  if (!exists || File(target).lengthSync() != data.lengthInBytes) {
    final List<int> bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(target).writeAsBytes(bytes);
  }

  return target;
}

/// Loads all available offline ASR models (excluding punctuation).
Future<List<AsrModel>> loadModels() async {
  final models = <AsrModel>[];

  // Group models by type:
  models.addAll(await loadOfflineModels());
  models.addAll(await loadOnlineModels());
  // models.addAll(await loadKeywordSpotterModels());
  models.addAll(await loadWhisperModels());

  return models;
}

/// Offline models (Moonshine and Nemo).
Future<List<AsrModel>> loadOfflineModels() async {
  final models = <AsrModel>[];

  // Moonshine model
  try {
    final modelName = 'sherpa-onnx-moonshine-base-en-int8';
    models.add(OfflineRecognizerModel(
        config: OfflineRecognizerConfig.fromJson({
      'model': {
        'moonshine': {
          'preprocessor': await copyAssetFile(modelName, 'preprocess.onnx'),
          'encoder': await copyAssetFile(modelName, 'encode.int8.onnx'),
          'uncachedDecoder':
              await copyAssetFile(modelName, 'uncached_decode.int8.onnx'),
          'cachedDecoder':
              await copyAssetFile(modelName, 'cached_decode.int8.onnx')
        },
        'tokens': await copyAssetFile(modelName, 'tokens.txt'),
        'modelType': 'moonshine',
        'debug': true
      }
    })));
  } catch (e) {
    print('Failed to load Moonshine model: $e');
  }

  // Nemo Fast Conformer Transducer
  try {
    final modelName = 'sherpa-onnx-nemo-fast-conformer-transducer-en-24500';
    models.add(OfflineRecognizerModel(
        config: OfflineRecognizerConfig.fromJson({
      'model': {
        'transducer': {
          'encoder': await copyAssetFile(modelName, 'encoder.onnx'),
          'decoder': await copyAssetFile(modelName, 'decoder.onnx'),
          'joiner': await copyAssetFile(modelName, 'joiner.onnx'),
        },
        'tokens': await copyAssetFile(modelName, 'tokens.txt'),
        'modelType': 'nemo_transducer',
        'debug': true
      }
    })));
  } catch (e) {
    print('Failed to load Nemo fast conformer transducer model: $e');
  }

  try {
    final modelName = 'sherpa-onnx-nemo-parakeet_tdt_transducer_110m-en-36000';
    models.add(OfflineRecognizerModel(
        config: OfflineRecognizerConfig.fromJson({
      'model': {
        'transducer': {
          'encoder': await copyAssetFile(modelName, 'encoder.onnx'),
          'decoder': await copyAssetFile(modelName, 'decoder.onnx'),
          'joiner': await copyAssetFile(modelName, 'joiner.onnx'),
        },
        'tokens': await copyAssetFile(modelName, 'tokens.txt'),
        'modelType': 'nemo_transducer',
        'debug': true,
      }
    })));
  } catch (e) {
    print('Failed to load Nemo fast conformer transducer model: $e');
  }

  return models;
}

/// Online models.
Future<List<AsrModel>> loadOnlineModels() async {
  final models = <AsrModel>[];

  // Nemo Streaming Fast Conformer Transducer (1040ms)
  try {
    final modelName =
        'sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-1040ms';
    models.add(OnlineRecognizerModel(
        config: OnlineRecognizerConfig.fromJson({
      'model': {
        'transducer': {
          'encoder': await copyAssetFile(modelName, 'encoder.onnx'),
          'decoder': await copyAssetFile(modelName, 'decoder.onnx'),
          'joiner': await copyAssetFile(modelName, 'joiner.onnx'),
        },
        'tokens': await copyAssetFile(modelName, 'tokens.txt'),
        'modelType': 'conformer',
        'debug': true
      }
    })));
  } catch (e) {
    print(
        'Failed to load Nemo streaming fast conformer transducer (1040ms) model: $e');
  }

  return models;
}

/// Keyword Spotter models.
Future<List<AsrModel>> loadKeywordSpotterModels() async {
  final models = <AsrModel>[];

  // sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01
  try {
    final modelName = 'sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01';
    models.add(KeywordSpotterModel(
        config: KeywordSpotterConfig.fromJson({
      'model': {
        'transducer': {
          'encoder': await copyAssetFile(
              modelName, 'encoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx'),
          'decoder': await copyAssetFile(
              modelName, 'decoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx'),
          'joiner': await copyAssetFile(
              modelName, 'joiner-epoch-12-avg-2-chunk-16-left-64.int8.onnx'),
        },
        'tokens': await copyAssetFile(modelName, 'tokens.txt'),
        'modelType': 'transducer',
        'modelingUnit': 'bpe',
        'bpeVocab': await copyAssetFile(modelName, 'bpe.model'),
        'debug': true
      },
      'keywordsFile': await copyAssetFile(modelName, 'keywords.txt')
    })));
  } catch (e) {
    print('Failed to load keyword spotter model: $e');
  }

  return models;
}

/// Loads all available Whisper models.
Future<List<AsrModel>> loadWhisperModels() async {
  final models = <AsrModel>[];
  // Small Whisper model
  try {
    final modelName = 'sherpa-onnx-whisper-tiny.en';
    models.add(OfflineRecognizerModel(
        config: OfflineRecognizerConfig.fromJson({
      'model': {
        'whisper': {
          'encoder':
              await copyAssetFile(modelName, 'tiny.en-encoder.int8.onnx'),
          'decoder':
              await copyAssetFile(modelName, 'tiny.en-decoder.int8.onnx'),
          'tailPaddings':
              4000, // Add this line to fix the "invalid expand shape" errors
        },
        'tokens': await copyAssetFile(modelName, 'tiny.en-tokens.txt'),
        'modelType': 'whisper',
        'debug': true
      }
    })));
  } catch (e) {
    print('Failed to load whisper small model: $e');
  }

  // Small Whisper model
  // try {
  //   final modelName = 'sherpa-onnx-whisper-tiny';
  //   models.add(OfflineRecognizerModel(
  //       cacheSize: 6,
  //       config: OfflineRecognizerConfig.fromJson({
  //         'model': {
  //           'whisper': {
  //             'encoder':
  //                 await copyAssetFile(modelName, 'tiny-encoder.int8.onnx'),
  //             'decoder':
  //                 await copyAssetFile(modelName, 'tiny-decoder.int8.onnx'),
  //           },
  //           'tokens': await copyAssetFile(modelName, 'tiny-tokens.txt'),
  //           'modelType': 'whisper',
  //           'debug': true
  //         }
  //       })));
  // } catch (e) {
  //   print('Failed to load whisper small model: $e');
  // }

  // Small Whisper model
  try {
    final modelName = 'sherpa-onnx-whisper-small.en.int8';
    models.add(OfflineRecognizerModel(
        config: OfflineRecognizerConfig.fromJson({
      'model': {
        'whisper': {
          'encoder':
              await copyAssetFile(modelName, 'small.en-encoder.int8.onnx'),
          'decoder':
              await copyAssetFile(modelName, 'small.en-decoder.int8.onnx'),
          'tailPaddings': 4000,
        },
        'tokens': await copyAssetFile(modelName, 'small.en-tokens.txt'),
        'modelType': 'whisper',
        'debug': true
      }
    })));
  } catch (e) {
    print('Failed to load whisper small model: $e');
  }

  // Base Whisper model
  try {
    final modelName = 'sherpa-onnx-whisper-base.en';
    models.add(OfflineRecognizerModel(
        config: OfflineRecognizerConfig.fromJson({
      'model': {
        'whisper': {
          'encoder':
              await copyAssetFile(modelName, 'base.en-encoder.int8.onnx'),
          'decoder':
              await copyAssetFile(modelName, 'base.en-decoder.int8.onnx'),
        },
        'tokens': await copyAssetFile(modelName, 'base.en-tokens.txt'),
        'modelType': 'whisper',
        'debug': true
      }
    })));
  } catch (e) {
    print('Failed to load whisper base model: $e');
  }

  // Turbo Whisper model
  try {
    final modelName = 'sherpa-onnx-whisper-turbo';
    models.add(OfflineRecognizerModel(
        config: OfflineRecognizerConfig.fromJson({
      'model': {
        'whisper': {
          'encoder': await copyAssetFile(modelName, 'turbo-encoder.int8.onnx'),
          'decoder': await copyAssetFile(modelName, 'turbo-decoder.int8.onnx'),
        },
        'tokens': await copyAssetFile(modelName, 'turbo-tokens.txt'),
        'modelType': 'whisper',
        'debug': true
      }
    })));
  } catch (e) {
    print('Failed to load whisper turbo model: $e');
  }

  return models;
}

/// Loads the Silero VAD model.
Future<VoiceActivityDetector> loadSileroVad() async => VoiceActivityDetector(
    config: VadModelConfig.fromJson(
      {
        'sileroVad': {
          'model': await copyAssetFile(null, 'silero_vad.onnx'),
          'threshold': 0.4,
          'minSilenceDuration': 0.5,
          'minSpeechDuration': 0.1,
          'maxSpeechDuration': 7.0,
        },
        'numThreads': 1,
        'debug': true,
      },
    ),
    bufferSizeInSeconds: 15);
