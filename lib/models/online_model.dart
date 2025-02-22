import 'dart:typed_data';

import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

class OnlineModel extends ModelBase {
  final OnlineRecognizer recognizer;
  OnlineStream? stream;

  OnlineModel({required OnlineRecognizerConfig config})
      : recognizer = OnlineRecognizer(config),
        super(
            modelName:
                (config.model.tokens.split('/')..removeLast()).removeLast());

  // Stream management
  bool createStream() {
    try {
      stream = recognizer.createStream();
      return true;
    } catch (e) {
      print('Failed to create stream for $modelName: $e');
      return false;
    }
  }

  @override
  TranscriptionResult processAudio(Uint8List audioData, int sampleRate) {
    if (stream == null) return TranscriptionResult.empty();

    final samples = convertBytesToFloat32(audioData);
    stream!.acceptWaveform(samples: samples, sampleRate: sampleRate);

    OnlineRecognizerResult? result;
    while (recognizer.isReady(stream!)) {
      recognizer.decode(stream!);
      result = recognizer.getResult(stream!);
    }
    return result == null
        ? TranscriptionResult.empty()
        : TranscriptionResult.fromJson(result.toJson());
  }

  String finalizeAndGetResult() {
    if (stream == null) return '';

    stream!.inputFinished();
    while (recognizer.isReady(stream!)) {
      recognizer.decode(stream!);
    }
    return recognizer.getResult(stream!).text;
  }

  void onRecordingStop() {
    stream?.inputFinished();
    final finalText = finalizeAndGetResult();
    stream?.free();
  }

  @override
  void dispose() {
    stream?.free();
    recognizer.free();
  }
}

/// Creates configuration for online transducer models.
Future<OnlineRecognizerConfig> createOnlineTransducerConfig({
  required String modelName,
  required String encoder,
  required String decoder,
  required String joiner,
  required String tokens,
  // Core model settings
  int numThreads = 1,
  bool debug = true,
  String provider = 'cpu',
  String modelType = 'transducer',
  // Optional components
  String modelingUnit = '',
  String bpeVocab = '',
  // Feature settings
  int sampleRate = 16000,
  int featureDim = 80,
  // Endpoint settings
  bool enableEndpoint = true,
  double rule1MinTrailingSilence = 2.4,
  double rule2MinTrailingSilence = 1.2,
  double rule3MinUtteranceLength = 20.0,
  // Decoding settings
  String decodingMethod = 'greedy_search',
  int maxActivePaths = 4,
  String hotwordsFile = '',
  double hotwordsScore = 1.5,
  String ruleFsts = '',
  String ruleFars = '',
  double blankPenalty = 0.0,
  // CTC FST decoder settings
  String ctcFstDecoderGraph = '',
  int ctcFstDecoderMaxActive = 3000,
}) async {
  return OnlineRecognizerConfig(
    model: OnlineModelConfig(
      transducer: OnlineTransducerModelConfig(
        encoder: await copyAssetFile(modelName, encoder),
        decoder: await copyAssetFile(modelName, decoder),
        joiner: await copyAssetFile(modelName, joiner),
      ),
      tokens: await copyAssetFile(modelName, tokens),
      numThreads: numThreads,
      debug: debug,
      provider: provider,
      modelType: modelType,
      modelingUnit: modelingUnit,
      bpeVocab:
          bpeVocab.isNotEmpty ? await copyAssetFile(modelName, bpeVocab) : '',
    ),
    feat: FeatureConfig(sampleRate: sampleRate, featureDim: featureDim),
    enableEndpoint: enableEndpoint,
    rule1MinTrailingSilence: rule1MinTrailingSilence,
    rule2MinTrailingSilence: rule2MinTrailingSilence,
    rule3MinUtteranceLength: rule3MinUtteranceLength,
    decodingMethod: decodingMethod,
    maxActivePaths: maxActivePaths,
    hotwordsFile: hotwordsFile.isNotEmpty
        ? await copyAssetFile(modelName, hotwordsFile)
        : '',
    hotwordsScore: hotwordsScore,
    ruleFsts: ruleFsts,
    ruleFars: ruleFars,
    blankPenalty: blankPenalty,
    ctcFstDecoderConfig: OnlineCtcFstDecoderConfig(
      graph: ctcFstDecoderGraph.isNotEmpty
          ? await copyAssetFile(modelName, ctcFstDecoderGraph)
          : '',
      maxActive: ctcFstDecoderMaxActive,
    ),
  );
}

/// Creates configuration for online paraformer models.
Future<OnlineRecognizerConfig> createOnlineParaformerConfig({
  required String modelName,
  required String encoder,
  required String decoder,
  required String tokens,
  // Core model settings
  int numThreads = 1,
  bool debug = true,
  String provider = 'cpu',
  String modelType = 'paraformer',
  // Optional components
  String modelingUnit = '',
  String bpeVocab = '',
  // Feature settings
  int sampleRate = 16000,
  int featureDim = 80,
  // Endpoint settings
  bool enableEndpoint = true,
  double rule1MinTrailingSilence = 2.4,
  double rule2MinTrailingSilence = 1.2,
  double rule3MinUtteranceLength = 20.0,
  // Decoding settings
  String decodingMethod = 'greedy_search',
  int maxActivePaths = 4,
  String hotwordsFile = '',
  double hotwordsScore = 1.5,
  String ruleFsts = '',
  String ruleFars = '',
  double blankPenalty = 0.0,
  // CTC FST decoder settings
  String ctcFstDecoderGraph = '',
  int ctcFstDecoderMaxActive = 3000,
}) async {
  return OnlineRecognizerConfig(
    model: OnlineModelConfig(
      paraformer: OnlineParaformerModelConfig(
        encoder: await copyAssetFile(modelName, encoder),
        decoder: await copyAssetFile(modelName, decoder),
      ),
      tokens: await copyAssetFile(modelName, tokens),
      numThreads: numThreads,
      debug: debug,
      provider: provider,
      modelType: modelType,
      modelingUnit: modelingUnit,
      bpeVocab:
          bpeVocab.isNotEmpty ? await copyAssetFile(modelName, bpeVocab) : '',
    ),
    feat: FeatureConfig(sampleRate: sampleRate, featureDim: featureDim),
    enableEndpoint: enableEndpoint,
    rule1MinTrailingSilence: rule1MinTrailingSilence,
    rule2MinTrailingSilence: rule2MinTrailingSilence,
    rule3MinUtteranceLength: rule3MinUtteranceLength,
    decodingMethod: decodingMethod,
    maxActivePaths: maxActivePaths,
    hotwordsFile: hotwordsFile.isNotEmpty
        ? await copyAssetFile(modelName, hotwordsFile)
        : '',
    hotwordsScore: hotwordsScore,
    ruleFsts: ruleFsts,
    ruleFars: ruleFars,
    blankPenalty: blankPenalty,
    ctcFstDecoderConfig: OnlineCtcFstDecoderConfig(
      graph: ctcFstDecoderGraph.isNotEmpty
          ? await copyAssetFile(modelName, ctcFstDecoderGraph)
          : '',
      maxActive: ctcFstDecoderMaxActive,
    ),
  );
}

/// Creates configuration for online Zipformer2 CTC models.
Future<OnlineRecognizerConfig> createOnlineZipformer2CtcConfig({
  required String modelName,
  required String model,
  required String tokens,
  // Core model settings
  int numThreads = 1,
  bool debug = true,
  String provider = 'cpu',
  String modelType = 'zipformer2_ctc',
  // Optional components
  String modelingUnit = '',
  String bpeVocab = '',
  // Feature settings
  int sampleRate = 16000,
  int featureDim = 80,
  // Endpoint settings
  bool enableEndpoint = true,
  double rule1MinTrailingSilence = 2.4,
  double rule2MinTrailingSilence = 1.2,
  double rule3MinUtteranceLength = 20.0,
  // Decoding settings
  String decodingMethod = 'greedy_search',
  int maxActivePaths = 4,
  String hotwordsFile = '',
  double hotwordsScore = 1.5,
  String ruleFsts = '',
  String ruleFars = '',
  double blankPenalty = 0.0,
  // CTC FST decoder settings
  String ctcFstDecoderGraph = '',
  int ctcFstDecoderMaxActive = 3000,
}) async {
  return OnlineRecognizerConfig(
    model: OnlineModelConfig(
      zipformer2Ctc: OnlineZipformer2CtcModelConfig(
        model: await copyAssetFile(modelName, model),
      ),
      tokens: await copyAssetFile(modelName, tokens),
      numThreads: numThreads,
      debug: debug,
      provider: provider,
      modelType: modelType,
      modelingUnit: modelingUnit,
      bpeVocab:
          bpeVocab.isNotEmpty ? await copyAssetFile(modelName, bpeVocab) : '',
    ),
    feat: FeatureConfig(sampleRate: sampleRate, featureDim: featureDim),
    enableEndpoint: enableEndpoint,
    rule1MinTrailingSilence: rule1MinTrailingSilence,
    rule2MinTrailingSilence: rule2MinTrailingSilence,
    rule3MinUtteranceLength: rule3MinUtteranceLength,
    decodingMethod: decodingMethod,
    maxActivePaths: maxActivePaths,
    hotwordsFile: hotwordsFile.isNotEmpty
        ? await copyAssetFile(modelName, hotwordsFile)
        : '',
    hotwordsScore: hotwordsScore,
    ruleFsts: ruleFsts,
    ruleFars: ruleFars,
    blankPenalty: blankPenalty,
    ctcFstDecoderConfig: OnlineCtcFstDecoderConfig(
      graph: ctcFstDecoderGraph.isNotEmpty
          ? await copyAssetFile(modelName, ctcFstDecoderGraph)
          : '',
      maxActive: ctcFstDecoderMaxActive,
    ),
  );
}

/// Creates configuration for online NeMo CTC models.
// Future<OnlineRecognizerConfig> createOnlineNeMoCtcModelConfig({
//   required String modelName,
//   required String model,
//   required String tokens,
//   // Core model settings
//   int numThreads = 1,
//   bool debug = true,
//   String provider = 'cpu',
//   String modelType = 'nemo_ctc',
//   // Optional components
//   String modelingUnit = '',
//   String bpeVocab = '',
//   // Feature settings
//   int sampleRate = 16000,
//   int featureDim = 80,
//   // Endpoint settings
//   bool enableEndpoint = true,
//   double rule1MinTrailingSilence = 2.4,
//   double rule2MinTrailingSilence = 1.2,
//   double rule3MinUtteranceLength = 20.0,
//   // Decoding settings
//   String decodingMethod = 'greedy_search',
//   int maxActivePaths = 4,
//   String hotwordsFile = '',
//   double hotwordsScore = 1.5,
//   String ruleFsts = '',
//   String ruleFars = '',
//   double blankPenalty = 0.0,
//   // CTC FST decoder settings
//   String ctcFstDecoderGraph = '',
//   int ctcFstDecoderMaxActive = 3000,
// }) async {
//   return OnlineRecognizerConfig(
//     model: OnlineModelConfig(
//       zipformer2Ctc: OnlineZipformer2CtcModelConfig(
//         model: await copyAssetFile(modelName, model),
//       ),
//       tokens: await copyAssetFile(modelName, tokens),
//       numThreads: numThreads,
//       debug: debug,
//       provider: provider,
//       modelType: modelType,
//       modelingUnit: modelingUnit,
//       bpeVocab:
//           bpeVocab.isNotEmpty ? await copyAssetFile(modelName, bpeVocab) : '',
//     ),
//     feat: FeatureConfig(sampleRate: sampleRate, featureDim: featureDim),
//     enableEndpoint: enableEndpoint,
//     rule1MinTrailingSilence: rule1MinTrailingSilence,
//     rule2MinTrailingSilence: rule2MinTrailingSilence,
//     rule3MinUtteranceLength: rule3MinUtteranceLength,
//     decodingMethod: decodingMethod,
//     maxActivePaths: maxActivePaths,
//     hotwordsFile: hotwordsFile.isNotEmpty
//         ? await copyAssetFile(modelName, hotwordsFile)
//         : '',
//     hotwordsScore: hotwordsScore,
//     ruleFsts: ruleFsts,
//     ruleFars: ruleFars,
//     blankPenalty: blankPenalty,
//     ctcFstDecoderConfig: OnlineCtcFstDecoderConfig(
//       graph: ctcFstDecoderGraph.isNotEmpty
//           ? await copyAssetFile(modelName, ctcFstDecoderGraph)
//           : '',
//       maxActive: ctcFstDecoderMaxActive,
//     ),
//   );
// }
