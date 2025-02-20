import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';


/// Creates configuration for offline Moonshine models.
Future<OfflineRecognizerConfig> createOfflineMoonshineConfig({
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
}) async {
  return OfflineRecognizerConfig(
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
      bpeVocab:
          bpeVocab.isNotEmpty ? await copyAssetFile(modelName, bpeVocab) : '',
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
  );
}

/// Creates configuration for offline Whisper models.
Future<OfflineRecognizerConfig> createOfflineWhisperConfig({
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
}) async {
  return OfflineRecognizerConfig(
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
      bpeVocab:
          bpeVocab.isNotEmpty ? await copyAssetFile(modelName, bpeVocab) : '',
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
  );
}

/// Creates configuration for offline Nemo CTC models.
Future<OfflineRecognizerConfig> createOfflineNemoCtcConfig({
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
}) async {
  return OfflineRecognizerConfig(
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
      bpeVocab:
          bpeVocab.isNotEmpty ? await copyAssetFile(modelName, bpeVocab) : '',
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
  );
}

/// Creates configuration for SenseVoice models.
Future<OfflineRecognizerConfig> createOfflineSenseVoiceConfig({
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
}) async {
  return OfflineRecognizerConfig(
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
      bpeVocab:
          bpeVocab.isNotEmpty ? await copyAssetFile(modelName, bpeVocab) : '',
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
  );
}

/// Creates configuration for Paraformer models.
Future<OfflineRecognizerConfig> createOfflineParaformerConfig({
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
}) async {
  return OfflineRecognizerConfig(
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
      bpeVocab:
          bpeVocab.isNotEmpty ? await copyAssetFile(modelName, bpeVocab) : '',
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
Future<OfflineRecognizerConfig> createOfflineTransducerConfig({
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
}) async {
  // Validate inputs
  if (bpeVocab.isNotEmpty && modelingUnit.isEmpty) {
    modelingUnit = 'bpe'; // Set if bpeVocab provided
  }

  return OfflineRecognizerConfig(
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
      bpeVocab:
          bpeVocab.isNotEmpty ? await copyAssetFile(modelName, bpeVocab) : '',
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
  );
}
