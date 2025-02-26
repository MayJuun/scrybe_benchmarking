import 'dart:typed_data';

import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

class OnlineModel extends AsrModel {
  final OnlineRecognizer recognizer;
  OnlineStream? _stream;

  OnlineModel({required OnlineRecognizerConfig config})
      : recognizer = OnlineRecognizer(config),
        super(
            modelName:
                (config.model.tokens.split('/')..removeLast()).removeLast());

  String processAudio(Uint8List audioData, int sampleRate) {
    // Create a stream if we don't have one
    _stream ??= recognizer.createStream();

    // Convert audio data to samples
    final samples = convertBytesToFloat32(audioData);

    // Process the audio
    _stream!.acceptWaveform(samples: samples, sampleRate: sampleRate);

    // Decode while there's data to process
    while (recognizer.isReady(_stream!)) {
      recognizer.decode(_stream!);
    }

    // Get the result text
    final result = recognizer.getResult(_stream!);

    // If we've reached an endpoint, reset the stream
    if (recognizer.isEndpoint(_stream!)) {
      recognizer.reset(_stream!);
    }

    return result.text;
  }

  // In the OnlineModel class
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
}
