import 'dart:typed_data';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// Represents an Online (streaming) Sherpa-ONNX model.
class OnlineModel extends ModelBase {
  final OnlineRecognizer recognizer;
  OnlineStream? stream;
  final _accumulatedSegments = <String>[];

  OnlineModel({required OnlineRecognizerConfig config})
      : recognizer = OnlineRecognizer(config),
        super(
          modelName:
              (config.model.tokens.split('/')..removeLast()).removeLast(),
        );

  /// Create a new streaming context. Must be called before processing audio.
  bool createStream() {
    try {
      stream = recognizer.createStream();
      _accumulatedSegments.clear();
      return true;
    } catch (e) {
      print('Failed to create stream for $modelName: $e');
      return false;
    }
  }

  /// Feed audio data to the streaming recognizer in small chunks
  /// (mimics real-time). Returns either a partial hypothesis (if still in
  /// the middle of speaking) or final text if an endpoint was detected.
  @override
  String processAudio(Uint8List audioData, int sampleRate) {
    if (stream == null) return '';

    final samples = convertBytesToFloat32(audioData);
    stream!.acceptWaveform(samples: samples, sampleRate: sampleRate);

    while (recognizer.isReady(stream!)) {
      recognizer.decode(stream!);
    }

    final result = recognizer.getResult(stream!);
    final text = result.text.trim();

    if (recognizer.isEndpoint(stream!)) {
      // Get the final text before resetting
      if (text.isNotEmpty) {
        _accumulatedSegments.add(text);
        print('Added segment: $text');
      }

      // Only reset after we've captured the text
      recognizer.reset(stream!);

      final fullText = _accumulatedSegments.join(' ');
      print('Current accumulated: $fullText');
      return fullText;
    }

    return text; // Return partial
  }

  String finalizeAndGetResult() {
    if (stream == null) return '';

    stream!.inputFinished();
    while (recognizer.isReady(stream!)) {
      recognizer.decode(stream!);
    }

    // Get final text before closing
    final lastResult = recognizer.getResult(stream!).text.trim();
    if (lastResult.isNotEmpty &&
        (_accumulatedSegments.isEmpty ||
            lastResult != _accumulatedSegments.last)) {
      _accumulatedSegments.add(lastResult);
      print('Added final segment: $lastResult');
    }

    final finalText = _accumulatedSegments.join(' ');
    print('Final accumulated text: $finalText');
    return finalText;
  }

  /// Freed on normal stop, but you can also forcibly close it here.
  void onRecordingStop() {
    final finalText = finalizeAndGetResult();
    print('finalText: $finalText');
    stream?.free();
  }

  @override
  void dispose() {
    stream?.free();
    recognizer.free();
  }

  /// Creates configuration for online transducer models.
  static Future<OnlineModel> createTransducer({
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
    return OnlineModel(
      config: OnlineRecognizerConfig(
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
          bpeVocab: bpeVocab.isNotEmpty
              ? await copyAssetFile(modelName, bpeVocab)
              : '',
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
      ),
    );
  }

  /// Creates configuration for online paraformer models.
  static Future<OnlineModel> createParaformer({
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
    return OnlineModel(
      config: OnlineRecognizerConfig(
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
          bpeVocab: bpeVocab.isNotEmpty
              ? await copyAssetFile(modelName, bpeVocab)
              : '',
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
      ),
    );
  }

  /// Creates configuration for online Zipformer2 CTC models.
  static Future<OnlineModel> createZipformer2Ctc({
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
    return OnlineModel(
      config: OnlineRecognizerConfig(
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
          bpeVocab: bpeVocab.isNotEmpty
              ? await copyAssetFile(modelName, bpeVocab)
              : '',
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
      ),
    );
  }

  /// Creates configuration for online NeMo CTC models.
// static Future<OnlineModel>  createNeMoCtcModel({
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
//   return OnlineModel(config: OnlineRecognizerConfig(
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
//     ),),
//   );
// }
}
