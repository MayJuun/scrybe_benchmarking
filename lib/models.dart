import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

final asrModels = [
  AsrModel(
    name: 'sherpa-onnx-nemo-streaming-fast-conformer-ctc-en-80ms',
    encoder: 'model.onnx',
    decoder: '',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: '',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.nemoCtcOnline,
  ),

  // 0) Offline Whisper model (INT8)
  AsrModel(
    name: 'sherpa-onnx-whisper-medium.en.int8',
    encoder: 'medium.en-encoder.int8.onnx',
    decoder: 'medium.en-decoder.int8.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: '',
    tokens: 'medium.en-tokens.txt',
    modelType: SherpaModelType.whisper,
  ),
  // 1) Offline Whisper model
  AsrModel(
    name: 'sherpa-onnx-whisper-small.en.int8',
    encoder: 'small.en-encoder.int8.onnx',
    decoder: 'small.en-decoder.int8.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: '',
    tokens: 'small.en-tokens.txt',
    modelType: SherpaModelType.whisper,
  ),

  // 2) Offline Moonshine model
  AsrModel(
    name: 'sherpa-onnx-moonshine-base-en-int8',
    encoder: 'encode.int8.onnx',
    decoder: '',
    preprocessor: 'preprocess.onnx',
    uncachedDecoder: 'uncached_decode.int8.onnx',
    cachedDecoder: 'cached_decode.int8.onnx',
    joiner: '',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.moonshine,
  ),

  // 3) Offline Nemo transducer
  AsrModel(
    name: 'sherpa-onnx-nemo-fast-conformer-transducer-en-24500',
    encoder: 'encoder.onnx',
    decoder: 'decoder.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: 'joiner.onnx',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.nemoTransducer,
  ),

  // 4) Streaming Zipformer v2 (INT8)
  AsrModel(
    name: 'sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile.int8',
    encoder: 'encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    decoder: 'decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: 'joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.zipformer2,
  ),
  // 5) Streaming Zipformer v2 transducer (INT8)
  AsrModel(
    name: 'sherpa-onnx-streaming-zipformer-en-2023-06-26.int8',
    encoder: 'encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    decoder: 'decoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: 'joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.zipformer2,
  ),

  // // 3) Streaming Zipformer transducer (v2)
  // AsrModel(
  //   name: 'sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile',
  //   encoder: 'encoder-epoch-99-avg-1-chunk-16-left-128.onnx',
  //   decoder: 'decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
  //   preprocessor: '',
  //   uncachedDecoder: '',
  //   cachedDecoder: '',
  //   joiner: 'joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
  //   tokens: 'tokens.txt',
  //   modelType: SherpaModelType.zipformer2,
  // ),

  // 5..10) Offline Whisper models
  // AsrModel(
  //   name: 'sherpa-onnx-whisper-medium.en',
  //   encoder: 'medium.en-encoder.onnx',
  //   decoder: 'medium.en-decoder.onnx',
  //   preprocessor: '',
  //   uncachedDecoder: '',
  //   cachedDecoder: '',
  //   joiner: '',
  //   tokens: 'medium.en-tokens.txt',
  //   modelType: SherpaModelType.whisper,
  // ),
  // AsrModel(
  //   name: 'sherpa-onnx-whisper-small.en',
  //   encoder: 'small.en-encoder.onnx',
  //   decoder: 'small.en-decoder.onnx',
  //   preprocessor: '',
  //   uncachedDecoder: '',
  //   cachedDecoder: '',
  //   joiner: '',
  //   tokens: 'small.en-tokens.txt',
  //   modelType: SherpaModelType.whisper,
  // ),
  // AsrModel(
  //   name: 'sherpa-onnx-whisper-tiny.en',
  //   encoder: 'tiny.en-encoder.onnx',
  //   decoder: 'tiny.en-decoder.onnx',
  //   preprocessor: '',
  //   uncachedDecoder: '',
  //   cachedDecoder: '',
  //   joiner: '',
  //   tokens: 'tiny.en-tokens.txt',
  //   modelType: SherpaModelType.whisper,
  // ),
  // AsrModel(
  //   name: 'sherpa-onnx-whisper-tiny.en.int8',
  //   encoder: 'tiny.en-encoder.int8.onnx',
  //   decoder: 'tiny.en-decoder.int8.onnx',
  //   preprocessor: '',
  //   uncachedDecoder: '',
  //   cachedDecoder: '',
  //   joiner: '',
  //   tokens: 'tiny.en-tokens.txt',
  //   modelType: SherpaModelType.whisper,
  // ),

  // // 11) Offline Zipformer transducer
  // AsrModel(
  //   name: 'sherpa-onnx-zipformer-small-en-2023-06-26',
  //   encoder: 'encoder-epoch-99-avg-1.onnx',
  //   decoder: 'decoder-epoch-99-avg-1.onnx',
  //   preprocessor: '',
  //   uncachedDecoder: '',
  //   cachedDecoder: '',
  //   joiner: 'joiner-epoch-99-avg-1.onnx',
  //   tokens: 'tokens.txt',
  //   modelType: SherpaModelType.transducer,
  // ),

  // // 12) Offline Zipformer transducer (INT8)
  // AsrModel(
  //   name: 'sherpa-onnx-zipformer-small-en-2023-06-26.int8',
  //   encoder: 'encoder-epoch-99-avg-1.int8.onnx',
  //   decoder: 'decoder-epoch-99-avg-1.int8.onnx',
  //   preprocessor: '',
  //   uncachedDecoder: '',
  //   cachedDecoder: '',
  //   joiner: 'joiner-epoch-99-avg-1.int8.onnx',
  //   tokens: 'tokens.txt',
  //   modelType: SherpaModelType.transducer,
  // ),

  // // 13) Nemo CTC offline
  // AsrModel(
  //   name: 'sherpa-onnx-nemo-ctc-en-conformer-large',
  //   encoder: 'model.int8.onnx',
  //   decoder: '',
  //   preprocessor: '',
  //   uncachedDecoder: '',
  //   cachedDecoder: '',
  //   joiner: '',
  //   tokens: 'tokens.txt',
  //   modelType: SherpaModelType.nemoCtcOffline,
  // ),

  // // 14) Nemo CTC offline
  // AsrModel(
  //   name: 'sherpa-onnx-nemo-ctc-en-conformer-small',
  //   encoder: 'model.int8.onnx',
  //   decoder: '',
  //   preprocessor: '',
  //   uncachedDecoder: '',
  //   cachedDecoder: '',
  //   joiner: '',
  //   tokens: 'tokens.txt',
  //   modelType: SherpaModelType.nemoCtcOffline,
  // ),

  // 16) Streaming Zipformer2 CTC
  // AsrModel(
  //   name: 'sherpa-onnx-streaming-zipformer-ctc-small-2024-03-18',
  //   encoder: 'ctc-epoch-30-avg-3-chunk-16-left-128.onnx',
  //   decoder: '',
  //   preprocessor: '',
  //   uncachedDecoder: '',
  //   cachedDecoder: '',
  //   joiner: '',
  //   tokens: 'tokens.txt',
  //   modelType: SherpaModelType.zipformer2Ctc,
  // ),

  // // 17) Streaming Zipformer v2 transducer
  // AsrModel(
  //   name: 'sherpa-onnx-streaming-zipformer-en-2023-06-26',
  //   encoder: 'encoder-epoch-99-avg-1-chunk-16-left-128.onnx',
  //   decoder: 'decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
  //   preprocessor: '',
  //   uncachedDecoder: '',
  //   cachedDecoder: '',
  //   joiner: 'joiner-epoch-99-avg-1-chunk-16-left-128.onnx',
  //   tokens: 'tokens.txt',
  //   modelType: SherpaModelType.zipformer2,
  // ),

  // // 19) Offline zipformer (large)
  // AsrModel(
  //   name: 'sherpa-onnx-zipformer-large-en-2023-06-26',
  //   encoder: 'encoder-epoch-99-avg-1.onnx',
  //   decoder: 'decoder-epoch-99-avg-1.onnx',
  //   preprocessor: '',
  //   uncachedDecoder: '',
  //   cachedDecoder: '',
  //   joiner: 'joiner-epoch-99-avg-1.onnx',
  //   tokens: 'tokens.txt',
  //   modelType: SherpaModelType.transducer,
  // ),

  // // 20) Offline zipformer (large) INT8
  // AsrModel(
  //   name: 'sherpa-onnx-zipformer-large-en-2023-06-26.int8',
  //   encoder: 'encoder-epoch-99-avg-1.int8.onnx',
  //   decoder: 'decoder-epoch-99-avg-1.int8.onnx',
  //   preprocessor: '',
  //   uncachedDecoder: '',
  //   cachedDecoder: '',
  //   joiner: 'joiner-epoch-99-avg-1.int8.onnx',
  //   tokens: 'tokens.txt',
  //   modelType: SherpaModelType.transducer,
  // ),
];

// Define punctuation models
final punctuationModels = <PunctuationModel>[
  // PunctuationModel(
  //   name: 'sherpa-onnx-online-punct-en-2024-08-06',
  //   model: 'model.onnx',
  //   vocab: 'bpe.vocab',
  // ),
];
