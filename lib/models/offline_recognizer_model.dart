import 'dart:convert';
import 'dart:typed_data';

import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

class OfflineRecognizerModel extends AsrModel {
  final OfflineRecognizer recognizer;
  final int cacheSize;

  OfflineRecognizerModel(
      {required OfflineRecognizerConfig config, this.cacheSize = 10})
      : recognizer = OfflineRecognizer(config),
        super(
            modelName:
                (config.model.tokens.split('/')..removeLast()).removeLast());

  /// Returns a pretty printed JSON string.
  final JsonEncoder jsonEncoder = JsonEncoder.withIndent('    ');

  /// Returns a pretty printed JSON string.
  String prettyPrintJson(Map<String, dynamic> map) => jsonEncoder.convert(map);

  String processAudio(Uint8List audioData, int sampleRate) {
    // print('Processing audio data ${audioData.length} bytes');
    final stream = recognizer.createStream();

    // Convert audio data to samples
    final samples = convertBytesToFloat32(audioData);

    // Process waveform with recognizer stream
    stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
    recognizer.decode(stream);

    // Get the result from the recognizer
    final result = recognizer.getResult(stream);
    // print(prettyPrintJson(result.toJson()));

    // Clean up stream after use
    stream.free();

    return result.text;
  }

  @override
  void dispose() {
    recognizer.free();
  }

  /// Creates configuration for offline Moonshine models.
  static Future<OfflineRecognizerModel> createMoonshine({
    required String modelName,
    required String preprocessor,
    required String encoder,
    required String uncachedDecoder,
    required String cachedDecoder,
    required String tokens,
    // Core model settings
    int numThreads = 1,
    bool debug = true,
    String provider = 'cpu',
    String modelType = 'moonshine',
    // Optional components
    String modelingUnit = '',
    String bpeVocab = '',
    String telespeechCtc = '',
    // Feature settings
    int sampleRate = 16000,
    int featureDim = 80,
    // Language model settings
    String offlineLMConfigModel = '',
    double offlineLMConfigScale = 1.0,
    // Decoding settings
    String decodingMethod = 'greedy_search',
    int maxActivePaths = 4,
    String hotwordsFile = '',
    double hotwordsScore = 1.5,
    String ruleFsts = '',
    String ruleFars = '',
    double blankPenalty = 0.0,
    int? cacheSize,
  }) async {
    return OfflineRecognizerModel(
      config: OfflineRecognizerConfig(
        model: OfflineModelConfig(
          moonshine: OfflineMoonshineModelConfig(
            preprocessor: await copyAssetFile(modelName, preprocessor),
            encoder: await copyAssetFile(modelName, encoder),
            uncachedDecoder: await copyAssetFile(modelName, uncachedDecoder),
            cachedDecoder: await copyAssetFile(modelName, cachedDecoder),
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
          telespeechCtc: telespeechCtc,
        ),
        feat: FeatureConfig(sampleRate: sampleRate, featureDim: featureDim),
        lm: OfflineLMConfig(
          model: offlineLMConfigModel,
          scale: offlineLMConfigScale,
        ),
        decodingMethod: decodingMethod,
        maxActivePaths: maxActivePaths,
        hotwordsFile: hotwordsFile.isNotEmpty
            ? await copyAssetFile(modelName, hotwordsFile)
            : '',
        hotwordsScore: hotwordsScore,
        ruleFsts: ruleFsts,
        ruleFars: ruleFars,
        blankPenalty: blankPenalty,
      ),
      cacheSize: cacheSize ?? 10,
    );
  }

  /// Creates configuration for offline Whisper models.
  static Future<OfflineRecognizerModel> createWhisper({
    required String modelName,
    required String encoder,
    required String decoder,
    required String tokens,
    // Whisper specific
    String language = '',
    String task = '',
    int tailPaddings = -1,
    // Core model settings
    int numThreads = 1,
    bool debug = true,
    String provider = 'cpu',
    String modelType = 'whisper',
    // Optional components
    String modelingUnit = '',
    String bpeVocab = '',
    String telespeechCtc = '',
    // Feature settings
    int sampleRate = 16000,
    int featureDim = 80,
    // Language model settings
    String offlineLMConfigModel = '',
    double offlineLMConfigScale = 1.0,
    // Decoding settings
    String decodingMethod = 'greedy_search',
    int maxActivePaths = 4,
    String hotwordsFile = '',
    double hotwordsScore = 1.5,
    String ruleFsts = '',
    String ruleFars = '',
    double blankPenalty = 0.0,
    int? cacheSize,
  }) async {
    return OfflineRecognizerModel(
      config: OfflineRecognizerConfig(
        model: OfflineModelConfig(
          whisper: OfflineWhisperModelConfig(
            encoder: await copyAssetFile(modelName, encoder),
            decoder: await copyAssetFile(modelName, decoder),
            language: language,
            task: task,
            tailPaddings: tailPaddings,
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
          telespeechCtc: telespeechCtc,
        ),
        feat: FeatureConfig(sampleRate: sampleRate, featureDim: featureDim),
        lm: OfflineLMConfig(
          model: offlineLMConfigModel,
          scale: offlineLMConfigScale,
        ),
        decodingMethod: decodingMethod,
        maxActivePaths: maxActivePaths,
        hotwordsFile: hotwordsFile.isNotEmpty
            ? await copyAssetFile(modelName, hotwordsFile)
            : '',
        hotwordsScore: hotwordsScore,
        ruleFsts: ruleFsts,
        ruleFars: ruleFars,
        blankPenalty: blankPenalty,
      ),
      cacheSize: cacheSize ?? 10,
    );
  }

  /// Creates configuration for offline Nemo CTC models.
  static Future<OfflineRecognizerModel> createNemoCtc({
    required String modelName,
    required String model,
    required String tokens,
    // Core model settings
    int numThreads = 1,
    bool debug = true,
    String provider = 'cpu',
    String modelType = 'nemo_ctc',
    // Optional components
    String modelingUnit = '',
    String bpeVocab = '',
    String telespeechCtc = '',
    // Feature settings
    int sampleRate = 16000,
    int featureDim = 80,
    // Language model settings
    String offlineLMConfigModel = '',
    double offlineLMConfigScale = 1.0,
    // Decoding settings
    String decodingMethod = 'greedy_search',
    int maxActivePaths = 4,
    String hotwordsFile = '',
    double hotwordsScore = 1.5,
    String ruleFsts = '',
    String ruleFars = '',
    double blankPenalty = 0.0,
    int? cacheSize,
  }) async {
    return OfflineRecognizerModel(
      config: OfflineRecognizerConfig(
        model: OfflineModelConfig(
          nemoCtc: OfflineNemoEncDecCtcModelConfig(
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
          telespeechCtc: telespeechCtc,
        ),
        feat: FeatureConfig(sampleRate: sampleRate, featureDim: featureDim),
        lm: OfflineLMConfig(
          model: offlineLMConfigModel,
          scale: offlineLMConfigScale,
        ),
        decodingMethod: decodingMethod,
        maxActivePaths: maxActivePaths,
        hotwordsFile: hotwordsFile.isNotEmpty
            ? await copyAssetFile(modelName, hotwordsFile)
            : '',
        hotwordsScore: hotwordsScore,
        ruleFsts: ruleFsts,
        ruleFars: ruleFars,
        blankPenalty: blankPenalty,
      ),
      cacheSize: cacheSize ?? 10,
    );
  }

  /// Creates configuration for SenseVoice models.
  static Future<OfflineRecognizerModel> createSenseVoice({
    required String modelName,
    required String model,
    required String tokens,
    // SenseVoice specific
    String language = '',
    bool useInverseTextNormalization = false,
    // Core model settings
    int numThreads = 1,
    bool debug = true,
    String provider = 'cpu',
    String modelType = 'sense_voice',
    // Optional components
    String modelingUnit = '',
    String bpeVocab = '',
    String telespeechCtc = '',
    // Feature settings
    int sampleRate = 16000,
    int featureDim = 80,
    // Language model settings
    String offlineLMConfigModel = '',
    double offlineLMConfigScale = 1.0,
    // Decoding settings
    String decodingMethod = 'greedy_search',
    int maxActivePaths = 4,
    String hotwordsFile = '',
    double hotwordsScore = 1.5,
    String ruleFsts = '',
    String ruleFars = '',
    double blankPenalty = 0.0,
    int? cacheSize,
  }) async {
    return OfflineRecognizerModel(
      config: OfflineRecognizerConfig(
        model: OfflineModelConfig(
          senseVoice: OfflineSenseVoiceModelConfig(
            model: await copyAssetFile(modelName, model),
            language: language,
            useInverseTextNormalization: useInverseTextNormalization,
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
          telespeechCtc: telespeechCtc,
        ),
        feat: FeatureConfig(sampleRate: sampleRate, featureDim: featureDim),
        lm: OfflineLMConfig(
          model: offlineLMConfigModel,
          scale: offlineLMConfigScale,
        ),
        decodingMethod: decodingMethod,
        maxActivePaths: maxActivePaths,
        hotwordsFile: hotwordsFile.isNotEmpty
            ? await copyAssetFile(modelName, hotwordsFile)
            : '',
        hotwordsScore: hotwordsScore,
        ruleFsts: ruleFsts,
        ruleFars: ruleFars,
        blankPenalty: blankPenalty,
      ),
      cacheSize: cacheSize ?? 10,
    );
  }

  /// Creates configuration for Paraformer models.
  static Future<OfflineRecognizerModel> createParaformer({
    required String modelName,
    required String model,
    required String tokens,
    // Core model settings
    int numThreads = 1,
    bool debug = true,
    String provider = 'cpu',
    String modelType = 'paraformer',
    // Optional components
    String modelingUnit = '',
    String bpeVocab = '',
    String telespeechCtc = '',
    // Feature settings
    int sampleRate = 16000,
    int featureDim = 80,
    // Language model settings
    String offlineLMConfigModel = '',
    double offlineLMConfigScale = 1.0,
    // Decoding settings
    String decodingMethod = 'greedy_search',
    int maxActivePaths = 4,
    String hotwordsFile = '',
    double hotwordsScore = 1.5,
    String ruleFsts = '',
    String ruleFars = '',
    double blankPenalty = 0.0,
    int? cacheSize,
  }) async {
    return OfflineRecognizerModel(
      config: OfflineRecognizerConfig(
        model: OfflineModelConfig(
          paraformer: OfflineParaformerModelConfig(
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
          telespeechCtc: telespeechCtc,
        ),
        feat: FeatureConfig(sampleRate: sampleRate, featureDim: featureDim),
        lm: OfflineLMConfig(
          model: offlineLMConfigModel,
          scale: offlineLMConfigScale,
        ),
        decodingMethod: decodingMethod,
        maxActivePaths: maxActivePaths,
        hotwordsFile: hotwordsFile.isNotEmpty
            ? await copyAssetFile(modelName, hotwordsFile)
            : '',
        hotwordsScore: hotwordsScore,
        ruleFsts: ruleFsts,
        ruleFars: ruleFars,
        blankPenalty: blankPenalty,
      ),
      cacheSize: cacheSize ?? 10,
    );
  }

  /// Creates configuration for offline transducer models.
  ///
  /// Required parameters:
  /// - [modelName]: Name of the model directory in assets
  /// - [encoder]: Filename of the encoder model
  /// - [decoder]: Filename of the decoder model
  /// - [joiner]: Filename of the joiner model
  /// - [tokens]: Filename of the tokens file
  static Future<OfflineRecognizerModel> createTransducer({
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
    // Optional components with empty string defaults
    String modelingUnit = '',
    String bpeVocab = '',
    String telespeechCtc = '',
    // Feature settings
    int sampleRate = 16000,
    int featureDim = 80,
    // Language model settings
    String offlineLMConfigModel = '',
    double offlineLMConfigScale = 1.0,
    // Decoding settings
    String decodingMethod = 'greedy_search',
    int maxActivePaths = 4,
    String hotwordsFile = '',
    double hotwordsScore = 1.5,
    String ruleFsts = '',
    String ruleFars = '',
    double blankPenalty = 0.0,
    int? cacheSize,
  }) async {
    // Validate inputs
    if (bpeVocab.isNotEmpty && modelingUnit.isEmpty) {
      modelingUnit = 'bpe'; // Set if bpeVocab provided
    }

    return OfflineRecognizerModel(
      config: OfflineRecognizerConfig(
        model: OfflineModelConfig(
          transducer: OfflineTransducerModelConfig(
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
          telespeechCtc: telespeechCtc,
        ),
        feat: FeatureConfig(sampleRate: sampleRate, featureDim: featureDim),
        lm: OfflineLMConfig(
          model: offlineLMConfigModel,
          scale: offlineLMConfigScale,
        ),
        decodingMethod: decodingMethod,
        maxActivePaths: maxActivePaths,
        hotwordsFile: hotwordsFile.isNotEmpty
            ? await copyAssetFile(modelName, hotwordsFile)
            : '',
        hotwordsScore: hotwordsScore,
        ruleFsts: ruleFsts,
        ruleFars: ruleFars,
        blankPenalty: blankPenalty,
      ),
      cacheSize: cacheSize ?? 10,
    );
  }
}
