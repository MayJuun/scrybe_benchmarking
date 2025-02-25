// ignore_for_file: avoid_print

import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

Future<VoiceActivityDetector> loadSileroVad() async {
  final sileroVadConfig = SileroVadModelConfig(
    model: await copyAssetFile(null, 'silero_vad.onnx'),
    minSilenceDuration: 0.25,
    minSpeechDuration: 0.5,
    maxSpeechDuration: 5.0,
  );

  final vadConfig =
      VadModelConfig(sileroVad: sileroVadConfig, numThreads: 1, debug: true);

  return VoiceActivityDetector(config: vadConfig, bufferSizeInSeconds: 10);
}

/// Loads all available offline models (except punctuation).
Future<List<OfflineModel>> loadOfflineModels() async {
  final models = <OfflineModel>[];

  // Moonshine model (sherpa-onnx-moonshine-base-en-int8)
  try {
    models.add(await OfflineModel.createMoonshine(
      modelName: 'sherpa-onnx-moonshine-base-en-int8',
      preprocessor: 'preprocess.onnx',
      encoder: 'encode.int8.onnx',
      uncachedDecoder: 'uncached_decode.int8.onnx',
      cachedDecoder: 'cached_decode.int8.onnx',
      tokens: 'tokens.txt',
      cacheSize: 15,
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
      cacheSize: 20,
    ));
  } catch (e) {
    print('Failed to load Nemo fast conformer transducer model: $e');
  }

  // Nemo Conformer CTC Large (sherpa-onnx-nemo-ctc-en-conformer-large)
  // try {
  //   models.add(await OfflineModel.createNemoCtc(
  //     modelName: 'sherpa-onnx-nemo-ctc-en-conformer-large',
  //     model: 'model.int8.onnx',
  //     tokens: 'tokens.txt',
  //   ));
  // } catch (e) {
  //   print('Failed to load NeMo CTC large model: $e');
  // }

  // Nemo Conformer CTC Small (sherpa-onnx-nemo-ctc-en-conformer-small)
  // try {
  //   models.add(await OfflineModel.createNemoCtc(
  //     modelName: 'sherpa-onnx-nemo-ctc-en-conformer-small',
  //     model: 'model.int8.onnx',
  //     tokens: 'tokens.txt',
  //   ));
  // } catch (e) {
  //   print('Failed to load NeMo CTC small model: $e');
  // }

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

  // Zipformer Large (sherpa-onnx-zipformer-large-en-2023-06-26)
  // try {
  //   models.add(await OfflineModel.createTransducer(
  //     modelName: 'sherpa-onnx-zipformer-large-en-2023-06-26',
  //     encoder: 'encoder-epoch-99-avg-1.int8.onnx',
  //     decoder: 'decoder-epoch-99-avg-1.int8.onnx',
  //     joiner: 'joiner-epoch-99-avg-1.int8.onnx',
  //     tokens: 'tokens.txt',
  //     modelType: 'transducer',
  //   ));
  // } catch (e) {
  //   print('Failed to load Zipformer large model: $e');
  // }

  // Zipformer Small (sherpa-onnx-zipformer-small-en-2023-06-26)
  // try {
  //   models.add(await OfflineModel.createTransducer(
  //     modelName: 'sherpa-onnx-zipformer-small-en-2023-06-26',
  //     encoder: 'encoder-epoch-99-avg-1.int8.onnx',
  //     decoder: 'decoder-epoch-99-avg-1.int8.onnx',
  //     joiner: 'joiner-epoch-99-avg-1.int8.onnx',
  //     tokens: 'tokens.txt',
  //     modelType: 'transducer',
  //   ));
  // } catch (e) {
  //   print('Failed to load Zipformer small model: $e');
  // }

  return models;
}
