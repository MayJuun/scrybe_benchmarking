// ignore_for_file: avoid_print

import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// Loads the Silero VAD model.
Future<VoiceActivityDetector> loadSileroVad() async {
  print('loading silero vad');
  final sileroVadConfig = SileroVadModelConfig(
    model: await copyAssetFile(null, 'silero_vad.onnx'),
    threshold: 0.4, // Increase confidence threshold
    minSilenceDuration: 0.5, // Longer silence detection
    minSpeechDuration: 0.2, // Slightly longer min speech
    maxSpeechDuration: 7.0,
  );
  final vadConfig = VadModelConfig(
    sileroVad: sileroVadConfig,
    numThreads: 1,
    debug: true,
  );
  return VoiceActivityDetector(config: vadConfig, bufferSizeInSeconds: 15);
}

/// Loads all available offline ASR models (excluding punctuation).
Future<List<AsrModel>> loadModels() async {
  final models = <AsrModel>[];

  // Group models by type:
  models.addAll(await loadOfflineModels());
  // models.addAll(await loadOnlineModels());
  // models.addAll(await loadKeywordSpotterModels());
  // models.addAll(await loadWhisperModels());

  return models;
}

/// Offline models (Moonshine and Nemo).
Future<List<AsrModel>> loadOfflineModels() async {
  final models = <AsrModel>[];

  // Moonshine model (sherpa-onnx-moonshine-base-en-int8)
  try {
    models.add(await OfflineRecognizerModel.createMoonshine(
      modelName: 'sherpa-onnx-moonshine-base-en-int8',
      preprocessor: 'preprocess.onnx',
      encoder: 'encode.int8.onnx',
      uncachedDecoder: 'uncached_decode.int8.onnx',
      cachedDecoder: 'cached_decode.int8.onnx',
      tokens: 'tokens.txt',
      cacheSize: 6,
    ));
  } catch (e) {
    print('Failed to load Moonshine model: $e');
  }

  // Nemo Fast Conformer Transducer (sherpa-onnx-nemo-fast-conformer-transducer-en-24500)
  try {
    models.add(await OfflineRecognizerModel.createTransducer(
      modelName: 'sherpa-onnx-nemo-fast-conformer-transducer-en-24500',
      encoder: 'encoder.onnx',
      decoder: 'decoder.onnx',
      joiner: 'joiner.onnx',
      tokens: 'tokens.txt',
      numThreads: 1,
      modelType: 'nemo_transducer',
      debug: true,
      cacheSize: 6,
    ));
  } catch (e) {
    print('Failed to load Nemo fast conformer transducer model: $e');
  }

  // try {
  //   models.add(await OfflineRecognizerModel.createTransducer(
  //     modelName: 'sherpa-onnx-nemo-parakeet_tdt_transducer_110m-en-36000',
  //     encoder: 'encoder.onnx',
  //     decoder: 'decoder.onnx',
  //     joiner: 'joiner.onnx',
  //     tokens: 'tokens.txt',
  //     numThreads: 1,
  //     modelType: 'nemo_transducer',
  //     debug: true,
  //     cacheSize: 6,
  //   ));
  // } catch (e) {
  //   print('Failed to load Nemo fast conformer transducer model: $e');
  // }

  return models;
}

/// Online models.
Future<List<AsrModel>> loadOnlineModels() async {
  final models = <AsrModel>[];

  // Nemo Streaming Fast Conformer Transducer (1040ms)
  try {
    models.add(await OnlineRecognizerModel.createTransducer(
      modelName:
          'sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-1040ms',
      encoder: 'encoder.onnx',
      decoder: 'decoder.onnx',
      joiner: 'joiner.onnx',
      tokens: 'tokens.txt',
      modelType: 'conformer',
    ));
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
    models.add(await KeywordSpotterModel.createTransducer(
      modelName: 'sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01',
      encoder: 'encoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx',
      decoder: 'decoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx',
      joiner: 'joiner-epoch-12-avg-2-chunk-16-left-64.int8.onnx',
      tokens: 'tokens.txt',
      bpeVocab: 'bpe.model',
      keywordsFile: 'keywords.txt',
    ));
  } catch (e) {
    print('Failed to load keyword spotter model: $e');
  }

  return models;
}

/// ************************************************************
/// Whisper Models
/// ************************************************************

/// Helper to load a Whisper model.
Future<AsrModel?> loadWhisperModel({
  required String modelName,
  required String encoder,
  required String decoder,
  required String tokens,
}) async {
  try {
    return await OfflineRecognizerModel.createWhisper(
      modelName: modelName,
      encoder: encoder,
      decoder: decoder,
      tokens: tokens,
    );
  } catch (e) {
    print('Failed to load $modelName: $e');
    return null;
  }
}

/// Loads all available Whisper models.
Future<List<AsrModel>> loadWhisperModels() async {
  final models = <AsrModel>[];

  final small = await loadWhisperModel(
    modelName: 'sherpa-onnx-whisper-small.en.int8',
    encoder: 'small.en-encoder.int8.onnx',
    decoder: 'small.en-decoder.int8.onnx',
    tokens: 'small.en-tokens.txt',
  );
  if (small != null) models.add(small);

  final base = await loadWhisperModel(
    modelName: 'sherpa-onnx-whisper-base.en',
    encoder: 'base.en-encoder.int8.onnx',
    decoder: 'base.en-decoder.int8.onnx',
    tokens: 'base.en-tokens.txt',
  );
  if (base != null) models.add(base);

  final distil = await loadWhisperModel(
    modelName: 'sherpa-onnx-whisper-distil-medium.en',
    encoder: 'distil-medium.en-encoder.int8.onnx',
    decoder: 'distil-medium.en-decoder.int8.onnx',
    tokens: 'distil-medium.en-tokens.txt',
  );
  if (distil != null) models.add(distil);

  final turbo = await loadWhisperModel(
    modelName: 'sherpa-onnx-whisper-turbo',
    encoder: 'turbo-encoder.int8.onnx',
    decoder: 'turbo-decoder.int8.onnx',
    tokens: 'turbo-tokens.txt',
  );
  if (turbo != null) models.add(turbo);

  return models;
}
