import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:wav/wav.dart';

abstract class ModelBundle {
  ModelBundle({
    required this.sherpaModelType,
  });
  SherpaModelType sherpaModelType;

  void free();

  Future<String> decodeAudioFile(String audioPath);

  Future<String> applyPunctuation(String text) async => text;

  Future<Float32List> loadWavAsFloat32(String wavPath) async {
    final fileBytes = await File(wavPath).readAsBytes();
    final wavFile = Wav.read(fileBytes);

    if (wavFile.channels.length != 1) {
      print(
          'Warning: file has ${wavFile.channels.length} channels, expected 1');
    }
    if (wavFile.samplesPerSecond != 16000) {
      print('Warning: file has ${wavFile.samplesPerSecond} Hz, expected 16000');
    }

    final samplesFloat64 = wavFile.channels[0];
    final float32 = Float32List(samplesFloat64.length);

    for (int i = 0; i < samplesFloat64.length; i++) {
      float32[i] = samplesFloat64[i].toDouble().clamp(-1.0, 1.0);
    }

    return float32;
  }
}

class OfflineModelBundle extends ModelBundle {
  OfflineModelBundle({
    required this.recognizer,
    this.punctuation,
    required super.sherpaModelType,
  });

  factory OfflineModelBundle.fromModel(
    AsrModel asrModel,
    String modelDir,
  ) {
    final asrConfig = sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        transducer: asrModel.modelType == SherpaModelType.zipformer ||
                asrModel.modelType == SherpaModelType.transducer ||
                asrModel.modelType == SherpaModelType.nemoTransducer
            ? sherpa.OfflineTransducerModelConfig(
                encoder: p.join(modelDir, asrModel.name, asrModel.encoder),
                decoder: p.join(modelDir, asrModel.name, asrModel.decoder),
                joiner: p.join(modelDir, asrModel.name, asrModel.joiner),
              )
            : sherpa.OfflineTransducerModelConfig(),
        nemoCtc: asrModel.modelType == SherpaModelType.telespeechCtc
            ? sherpa.OfflineNemoEncDecCtcModelConfig(
                model: p.join(modelDir, asrModel.name, asrModel.encoder))
            : sherpa.OfflineNemoEncDecCtcModelConfig(),
        whisper: asrModel.modelType == SherpaModelType.whisper
            ? sherpa.OfflineWhisperModelConfig(
                encoder: p.join(modelDir, asrModel.name, asrModel.encoder),
                decoder: p.join(modelDir, asrModel.name, asrModel.decoder),
              )
            : sherpa.OfflineWhisperModelConfig(),
        moonshine: SherpaModelType.moonshine == asrModel.modelType
            ? sherpa.OfflineMoonshineModelConfig(
                preprocessor:
                    p.join(modelDir, asrModel.name, asrModel.preprocessor),
                encoder: p.join(modelDir, asrModel.name, asrModel.encoder),
                uncachedDecoder:
                    p.join(modelDir, asrModel.name, asrModel.uncachedDecoder),
                cachedDecoder:
                    p.join(modelDir, asrModel.name, asrModel.cachedDecoder),
              )
            : sherpa.OfflineMoonshineModelConfig(),
        tokens: p.join(modelDir, asrModel.name, asrModel.tokens),
        numThreads: 1,
        modelType: asrModel.modelType.toString(),
        debug: false,
      ),
    );
    final asrRecognizer = sherpa.OfflineRecognizer(asrConfig);

    return OfflineModelBundle(
      recognizer: asrRecognizer,
      punctuation: null,
      sherpaModelType: asrModel.modelType,
    );
  }

  final sherpa.OfflineRecognizer recognizer;
  sherpa.OfflinePunctuation? punctuation;

  void initPunctuation(PunctuationModel? punctuationModel, String modelDir) {
    if (punctuationModel != null) {
      final dir = p.join(modelDir, punctuationModel.name);

      final config = sherpa.OfflinePunctuationModelConfig(
          ctTransformer: p.join(dir, punctuationModel.model));

      final puncConfig = sherpa.OfflinePunctuationConfig(model: config);
      punctuation = sherpa.OfflinePunctuation(config: puncConfig);
    }
  }

  @override
  void free() {
    recognizer.free();
  }

  @override
  Future<String> decodeAudioFile(String audioPath) async {
    final stream = recognizer.createStream();

    final rawSamples = await loadWavAsFloat32(audioPath);

    try {
      // Add preprocessing for NeMo models
      Float32List processedSamples;

      processedSamples = rawSamples;

      stream.acceptWaveform(samples: processedSamples, sampleRate: 16000);

      recognizer.decode(stream);

      final text = recognizer.getResult(stream).text;
      stream.free();

      return punctuation?.addPunct(text.toLowerCase().trim()) ?? text;
    } catch (e, stacktrace) {
      print('Error during processing: $e');
      print('Stacktrace: $stacktrace');
      stream.free();
      rethrow;
    }
  }
}

class OnlineModelBundle extends ModelBundle {
  OnlineModelBundle({
    required this.recognizer,
    this.punctuation,
    required super.sherpaModelType,
  });

  factory OnlineModelBundle.fromModel(
    AsrModel asrModel,
    String modelDir,
  ) {
    final asrConfig = sherpa.OnlineRecognizerConfig(
      model: sherpa.OnlineModelConfig(
        transducer: asrModel.modelType == SherpaModelType.zipformer2
            ? sherpa.OnlineTransducerModelConfig(
                encoder: p.join(modelDir, asrModel.name, asrModel.encoder),
                decoder: p.join(modelDir, asrModel.name, asrModel.decoder),
                joiner: p.join(modelDir, asrModel.name, asrModel.joiner),
              )
            : sherpa.OnlineTransducerModelConfig(),
        zipformer2Ctc: asrModel.modelType == SherpaModelType.zipformer2Ctc
            ? sherpa.OnlineZipformer2CtcModelConfig(
                model: p.join(modelDir, asrModel.name, asrModel.encoder),
              )
            : sherpa.OnlineZipformer2CtcModelConfig(),
        // neMoCtc: asrModel.modelType == SherpaModelType.nemoCtc
        //     ? sherpa.OnlineNeMoCtcModelConfig(
        //         model: p.join(modelDir, asrModel.name, asrModel.encoder))
        //     : sherpa.OnlineNeMoCtcModelConfig(),
        tokens: p.join(modelDir, asrModel.name, asrModel.tokens),
        numThreads: 1,
        modelType: asrModel.modelType.toString(),
        debug: false,
      ),
    );

    final asrRecognizer = sherpa.OnlineRecognizer(asrConfig);

    return OnlineModelBundle(
      recognizer: asrRecognizer,
      punctuation: null,
      sherpaModelType: asrModel.modelType,
    );
  }

  final sherpa.OnlineRecognizer recognizer;
  sherpa.OnlinePunctuation? punctuation;

  void initPunctuation(PunctuationModel? punctuationModel, String modelDir) {
    if (punctuationModel != null) {
      final dir = p.join(modelDir, punctuationModel.name);

      final config = sherpa.OnlinePunctuationModelConfig(
        cnnBiLstm: p.join(dir, punctuationModel.model),
        bpeVocab: p.join(dir, punctuationModel.vocab),
      );

      final puncConfig = sherpa.OnlinePunctuationConfig(model: config);
      punctuation = sherpa.OnlinePunctuation(config: puncConfig);
    }
  }

  @override
  Future<String> applyPunctuation(String text) async {
    return punctuation?.addPunct(text.toLowerCase().trim()) ?? text;
  }

  @override
  void free() {
    recognizer.free();
    punctuation?.free();
  }

  sherpa.OnlineStream createStream() {
    return recognizer.createStream();
  }

  @override
  Future<String> decodeAudioFile(String audioPath) async {
    final stream = recognizer.createStream();

    final samples = await loadWavAsFloat32(audioPath);

    stream.acceptWaveform(samples: samples, sampleRate: 16000);

    recognizer.decode(stream);

    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }

    final text = recognizer.getResult(stream).text;

    stream.free();

    return punctuation?.addPunct(text.toLowerCase().trim()) ?? text;
  }
}
