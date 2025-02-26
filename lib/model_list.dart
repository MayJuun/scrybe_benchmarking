// ignore_for_file: avoid_print

import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

Future<VoiceActivityDetector> loadSileroVad() async {
  final sileroVadConfig = SileroVadModelConfig(
    model: await copyAssetFile(null, 'silero_vad.onnx'),
    threshold: 0.3,
    minSilenceDuration: 0.2,
    minSpeechDuration: 0.1,
    maxSpeechDuration: 5.0,
  );

  final vadConfig =
      VadModelConfig(sileroVad: sileroVadConfig, numThreads: 1, debug: true);

  return VoiceActivityDetector(config: vadConfig, bufferSizeInSeconds: 15);
}

/// Loads all available offline models (except punctuation).
Future<List<AsrModel>> loadModels() async {
  final models = <AsrModel>[];

  // Moonshine model (sherpa-onnx-moonshine-base-en-int8)
  try {
    models.add(await OfflineModel.createMoonshine(
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
    models.add(await OfflineModel.createTransducer(
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

  // Nemo Streaming Fast Conformer Transducer (1040ms)
  try {
    models.add(await OnlineModel.createTransducer(
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

  // Whisper Medium (sherpa-onnx-whisper-medium.en.int8)
  // try {
  //   models.add(await OfflineModel.createWhisper(
  //     modelName: 'sherpa-onnx-whisper-medium.en.int8',
  //     encoder: 'medium.en-encoder.int8.onnx',
  //     decoder: 'medium.en-decoder.int8.onnx',
  //     tokens: 'medium.en-tokens.txt',
  //   ));
  // } catch (e) {
  //   print('Failed to load Whisper medium model: $e');
  // }

  // Whisper Small (sherpa-onnx-whisper-small.en.int8)
  // try {
  //   models.add(await OfflineModel.createWhisper(
  //     modelName: 'sherpa-onnx-whisper-small.en.int8',
  //     encoder: 'small.en-encoder.int8.onnx',
  //     decoder: 'small.en-decoder.int8.onnx',
  //     tokens: 'small.en-tokens.txt',
  //   ));
  // } catch (e) {
  //   print('Failed to load Whisper small model: $e');
  // }

  return models;
}
