// ignore_for_file: avoid_print

import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// Loads all available offline models (except punctuation).
Future<List<OfflineModel>> loadOfflineConfigs() async {
  final configs = <OfflineRecognizerConfig>[];

  // // Moonshine model (sherpa-onnx-moonshine-base-en-int8)
  // try {
  //   configs.add(await createOfflineMoonshineConfig(
  //     modelName: 'sherpa-onnx-moonshine-base-en-int8',
  //     preprocessor: 'preprocess.onnx',
  //     encoder: 'encode.int8.onnx',
  //     uncachedDecoder: 'uncached_decode.int8.onnx',
  //     cachedDecoder: 'cached_decode.int8.onnx',
  //     tokens: 'tokens.txt',
  //   ));
  // } catch (e) {
  //   print('Failed to load Moonshine model: $e');
  // }

  // // Nemo Conformer CTC Large (sherpa-onnx-nemo-ctc-en-conformer-large)
  // try {
  //   configs.add(await createOfflineNemoCtcConfig(
  //     modelName: 'sherpa-onnx-nemo-ctc-en-conformer-large',
  //     model: 'model.int8.onnx',
  //     tokens: 'tokens.txt',
  //   ));
  // } catch (e) {
  //   print('Failed to load NeMo CTC large model: $e');
  // }

  // // Nemo Conformer CTC Small (sherpa-onnx-nemo-ctc-en-conformer-small)
  // try {
  //   configs.add(await createOfflineNemoCtcConfig(
  //     modelName: 'sherpa-onnx-nemo-ctc-en-conformer-small',
  //     model: 'model.int8.onnx',
  //     tokens: 'tokens.txt',
  //   ));
  // } catch (e) {
  //   print('Failed to load NeMo CTC small model: $e');
  // }

  // // Nemo Fast Conformer Transducer (sherpa-onnx-nemo-fast-conformer-transducer-en-24500)
  // try {
  //   configs.add(await createOfflineTransducerConfig(
  //     modelName: 'sherpa-onnx-nemo-fast-conformer-transducer-en-24500',
  //     encoder: 'encoder.onnx',
  //     decoder: 'decoder.onnx',
  //     joiner: 'joiner.onnx',
  //     tokens: 'tokens.txt',
  //     numThreads: 1,
  //     modelType: 'nemo_transducer',
  //     debug: true,
  //   ));
  // } catch (e) {
  //   print('Failed to load Nemo fast conformer transducer model: $e');
  // }

  // // Whisper Medium (sherpa-onnx-whisper-medium.en.int8)
  // // try {
  // //   configs.add(await createOfflineWhisperConfig(
  // //     modelName: 'sherpa-onnx-whisper-medium.en.int8',
  // //     encoder: 'medium.en-encoder.int8.onnx',
  // //     decoder: 'medium.en-decoder.int8.onnx',
  // //     tokens: 'medium.en-tokens.txt',
  // //   ));
  // // } catch (e) {
  // //   print('Failed to load Whisper medium model: $e');
  // // }

  // // Whisper Small (sherpa-onnx-whisper-small.en.int8)
  // // try {
  // //   configs.add(await createOfflineWhisperConfig(
  // //     modelName: 'sherpa-onnx-whisper-small.en.int8',
  // //     encoder: 'small.en-encoder.int8.onnx',
  // //     decoder: 'small.en-decoder.int8.onnx',
  // //     tokens: 'small.en-tokens.txt',
  // //   ));
  // // } catch (e) {
  // //   print('Failed to load Whisper small model: $e');
  // // }

  // // Zipformer Large (sherpa-onnx-zipformer-large-en-2023-06-26)
  // try {
  //   configs.add(await createOfflineTransducerConfig(
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

  // // Zipformer Small (sherpa-onnx-zipformer-small-en-2023-06-26)
  // try {
  //   configs.add(await createOfflineTransducerConfig(
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

  return configs.map((e) => OfflineModel(config: e)).toList();
}

/// Loads all available online models (again, excluding punctuation).
Future<List<OnlineModel>> loadOnlineConfigs() async {
  final configs = <OnlineRecognizerConfig>[];

  // Nemo Streaming Fast Conformer Transducer (1040ms)
  try {
    configs.add(await createOnlineTransducerConfig(
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
  // Zipformer2 Streaming (sherpa-onnx-streaming-zipformer-en-2023-06-26.int8)
  try {
    configs.add(await createOnlineTransducerConfig(
      modelName: 'sherpa-onnx-streaming-zipformer-en-2023-06-26.int8',
      encoder: 'encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
      decoder: 'decoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
      joiner: 'joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
      tokens: 'tokens.txt',
      modelType: 'zipformer2',
    ));
  } catch (e) {
    print('Failed to load Zipformer2 streaming model: $e');
  }

  // TODO(Dokotela) - crashes every time
  // Nemo Streaming Fast Conformer CTC (80ms)
  // try {
  //   configs.add(await createOnlineNeMoCtcModelConfig(
  //     modelName: 'sherpa-onnx-nemo-streaming-fast-conformer-ctc-en-80ms',
  //     model: 'model.onnx',
  //     tokens: 'tokens.txt',
  //   ));
  // } catch (e) {
  //   print('Failed to load Nemo streaming fast conformer CTC (80ms) model: $e');
  // }

  // Nemo Streaming Fast Conformer Transducer (80ms)
  // try {
  //   configs.add(await createOnlineTransducerConfig(
  //     modelName: 'sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-80ms',
  //     encoder: 'encoder.onnx',
  //     decoder: 'decoder.onnx',
  //     joiner: 'joiner.onnx',
  //     tokens: 'tokens.txt',
  //     modelType: 'conformer',
  //   ));
  // } catch (e) {
  //   print(
  //       'Failed to load Nemo streaming fast conformer transducer (80ms) model: $e');
  // }

  // Nemo Streaming Fast Conformer Transducer (480ms)
  // try {
  //   configs.add(await createOnlineTransducerConfig(
  //     modelName:
  //         'sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-480ms',
  //     encoder: 'encoder.onnx',
  //     decoder: 'decoder.onnx',
  //     joiner: 'joiner.onnx',
  //     tokens: 'tokens.txt',
  //     modelType: 'conformer',
  //   ));
  // } catch (e) {
  //   print(
  //       'Failed to load Nemo streaming fast conformer transducer (480ms) model: $e');
  // }

  // Mobile Zipformer Model
  // try {
  //   configs.add(await createOnlineTransducerConfig(
  //     modelName: 'sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile.int8',
  //     encoder: 'encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
  //     decoder: 'decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
  //     joiner: 'joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
  //     tokens: 'tokens.txt',
  //     modelType: 'zipformer2',
  //   ));
  // } catch (e) {
  //   print('Failed to load Mobile Zipformer model: $e');
  // }

  return configs.map((e) => OnlineModel(config: e)).toList();
}
