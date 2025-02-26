import 'dart:typed_data';

import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

class KeywordSpotterModel extends OnlineModel {
  final KeywordSpotter recognizer;
  OnlineStream? _stream;

  KeywordSpotterModel({required KeywordSpotterConfig config})
      : recognizer = KeywordSpotter(config),
        super(
            modelName:
                (config.model.tokens.split('/')..removeLast()).removeLast());

  @override
  String processAudio(Uint8List audioData, int sampleRate) {
    _stream ??= recognizer.createStream();
    final samples = convertBytesToFloat32(audioData);
    _stream!.acceptWaveform(samples: samples, sampleRate: sampleRate);

    // Loop until there's no more immediate data to decode
    while (recognizer.isReady(_stream!)) {
      recognizer.decode(_stream!);
      final result = recognizer.getResult(_stream!);
      if (result.keyword != '') {
        // Keyword detected: reset stream and return the keyword.
        recognizer.reset(_stream!);
        return '${DateTime.now()} ${result.keyword}';
      }
    }

    // Return empty string if no keyword was detected.
    return '';
  }

  @override
  // In the KeywordSpotter class
  void finalizeDecoding() {
    // For some models, there's a specific API for this
    if (_stream != null) {
      // Add small silence to flush any buffered audio
      final silenceBuffer = Float32List(1600); // 0.1 second at 16kHz
      _stream!.acceptWaveform(samples: silenceBuffer, sampleRate: 16000);

      // Force all decoding of buffered audio
      while (recognizer.isReady(_stream!)) {
        recognizer.decode(_stream!);
      }
    }
  }

  void resetStream() {
    if (_stream != null) {
      _stream!.free();
      _stream = recognizer.createStream();
    }
  }

  @override
  void dispose() {
    _stream?.free();
    recognizer.free();
  }

  /// Creates configuration for online transducer models.
  static Future<KeywordSpotterModel> createTransducer({
    required String modelName,
    required String encoder,
    required String decoder,
    required String joiner,
    required String tokens,
    required String keywordsFile,
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
    bool enableEndpoint = false,
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
    return KeywordSpotterModel(
      config: KeywordSpotterConfig(
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
          maxActivePaths: maxActivePaths,
          keywordsFile: await copyAssetFile(modelName, keywordsFile)),
    );
  }
}
