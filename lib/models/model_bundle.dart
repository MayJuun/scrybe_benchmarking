import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:wav/wav.dart';

abstract class ModelBundle {
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
  });

  final sherpa.OfflineRecognizer recognizer;
  final sherpa.OfflinePunctuation? punctuation;

  @override
  void free() {
    recognizer.free();
  }

  @override
  Future<String> decodeAudioFile(
    String audioPath,
  ) async {
    print('Decoding file: $audioPath');
    final stream = recognizer.createStream();

    final samples = await loadWavAsFloat32(audioPath);

    print('Loaded ${samples.length} samples');

    stream.acceptWaveform(samples: samples, sampleRate: 16000);

    recognizer.decode(stream);

    final text = recognizer.getResult(stream).text;
    stream.free();
    return punctuation?.addPunct(text.toLowerCase().trim()) ?? text;
  }
}

class WhisperModelBundle extends ModelBundle {
  WhisperModelBundle({required this.recognizer});

  factory WhisperModelBundle.fromModel(AsrModel asrModel, String modelDir) {
    final whisperConfig = sherpa.OfflineWhisperModelConfig(
      encoder: p.join(modelDir, asrModel.name, asrModel.encoder),
      decoder: p.join(modelDir, asrModel.name, asrModel.decoder),
    );
    final modelConfig = sherpa.OfflineModelConfig(
      whisper: whisperConfig,
      tokens: p.join(modelDir, asrModel.name, asrModel.tokens),
      modelType: 'whisper',
      debug: false,
      numThreads: 1,
    );

    final config = sherpa.OfflineRecognizerConfig(model: modelConfig);
    final recognizer = sherpa.OfflineRecognizer(config);
    return WhisperModelBundle(recognizer: recognizer);
  }

  final sherpa.OfflineRecognizer recognizer;

  @override
  void free() {
    recognizer.free();
  }

  @override
  Future<String> decodeAudioFile(
    String audioPath,
  ) async {
    print('Decoding file: $audioPath');
    final stream = recognizer.createStream();

    final samples = await loadWavAsFloat32(audioPath);

    print('Loaded ${samples.length} samples');

    stream.acceptWaveform(samples: samples, sampleRate: 16000);

    recognizer.decode(stream);

    final text = recognizer.getResult(stream).text;
    stream.free();
    return text;
  }
}

class OnlineModelBundle extends ModelBundle {
  OnlineModelBundle({
    required this.recognizer,
    this.punctuation,
  });

  factory OnlineModelBundle.fromModel(
    AsrModel asrModel,
    String modelDir,
  ) {
    final asrConfig = sherpa.OnlineRecognizerConfig(
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: p.join(modelDir, asrModel.name, asrModel.encoder),
          decoder: p.join(modelDir, asrModel.name, asrModel.decoder),
          joiner: p.join(modelDir, asrModel.name, asrModel.joiner),
        ),
        tokens: p.join(modelDir, asrModel.name, asrModel.tokens),
        numThreads: 1,
        modelType: asrModel.modelType,
        debug: false,
      ),
    );
    final asrRecognizer = sherpa.OnlineRecognizer(asrConfig);

    return OnlineModelBundle(
      recognizer: asrRecognizer,
      punctuation: null,
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
    print('Decoding file: $audioPath');
    final stream = recognizer.createStream();

    final samples = await loadWavAsFloat32(audioPath);

    print('Loaded ${samples.length} samples');

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
