/// The recognized model types that your code handles.
enum SherpaModelType {
  whisper,
  zipformer,
  transducer,
  moonshine,
  lstm,
  paraformer,
  telespeechCtc,
  zipformer2;

  static SherpaModelType fromString(String value) {
    switch (value) {
      case 'whisper':
        return whisper;
      case 'zipformer':
        return zipformer;
      case 'transducer':
        return transducer;
      case 'moonshine':
        return moonshine;
      case 'lstm':
        return lstm;
      case 'paraformer':
        return paraformer;
      case 'telespeech-ctc':
        return telespeechCtc;
      case 'zipformer2':
        return zipformer2;
      default:
        throw ArgumentError('Unknown model type: $value');
    }
  }

  @override
  String toString() {
    switch (this) {
      case whisper:
        return 'whisper';
      case zipformer:
        return 'zipformer';
      case transducer:
        return 'transducer';
      case moonshine:
        return 'moonshine';
      case lstm:
        return 'lstm';
      case paraformer:
        return 'paraformer';
      case telespeechCtc:
        return 'telespeech-ctc';
      case zipformer2:
        return 'zipformer2';
    }
  }
}

class AsrModel {
  const AsrModel({
    required this.name,
    required this.encoder,
    required this.decoder,
    required this.preprocessor,
    required this.uncachedDecoder,
    required this.cachedDecoder,
    required this.joiner,
    required this.tokens,
    required this.modelType,
  });

  final String name;
  final String encoder;
  final String decoder;
  final String preprocessor;
  final String uncachedDecoder;
  final String cachedDecoder;
  final String joiner;
  final String tokens;
  final SherpaModelType modelType;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'encoder': encoder,
      'decoder': decoder,
      'preprocessor': preprocessor,
      'uncachedDecoder': uncachedDecoder,
      'cachedDecoder': cachedDecoder,
      'joiner': joiner,
      'tokens': tokens,
      'modelType': modelType.toString(),
    };
  }

  factory AsrModel.fromJson(Map<String, dynamic> json) {
    return AsrModel(
      name: json['name'] as String,
      encoder: json['encoder'] as String,
      decoder: json['decoder'] as String,
      preprocessor: json['preprocessor'] as String,
      uncachedDecoder: json['uncachedDecoder'] as String,
      cachedDecoder: json['cachedDecoder'] as String,
      joiner: json['joiner'] as String,
      tokens: json['tokens'] as String,
      modelType: SherpaModelType.fromString(json['modelType'] as String),
    );
  }

  @override
  String toString() => 'AsrModel($name)';

  AsrModel copyWith({
    String? name,
    String? encoder,
    String? decoder,
    String? preprocessor,
    String? uncachedDecoder,
    String? cachedDecoder,
    String? joiner,
    String? tokens,
    SherpaModelType? modelType,
  }) {
    return AsrModel(
      name: name ?? this.name,
      encoder: encoder ?? this.encoder,
      decoder: decoder ?? this.decoder,
      preprocessor: preprocessor ?? this.preprocessor,
      uncachedDecoder: uncachedDecoder ?? this.uncachedDecoder,
      cachedDecoder: cachedDecoder ?? this.cachedDecoder,
      joiner: joiner ?? this.joiner,
      tokens: tokens ?? this.tokens,
      modelType: modelType ?? this.modelType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AsrModel &&
        other.name == name &&
        other.encoder == encoder &&
        other.decoder == decoder &&
        other.joiner == joiner &&
        other.tokens == tokens &&
        other.modelType == modelType;
  }

  @override
  int get hashCode {
    return Object.hash(
      name,
      encoder,
      decoder,
      joiner,
      tokens,
      modelType,
    );
  }
}
