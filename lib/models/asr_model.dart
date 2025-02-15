/// The recognized model types that your code handles.
enum SherpaModelType {
  // offline/online Transducer
  transducer, // -> 'transducer'
  nemoTransducer, // -> 'nemo_transducer'

  // offline CTC
  nemoCtc, // -> 'nemo_ctc'
  tdnn, // -> 'tdnn'
  zipformer2Ctc, // -> 'zipformer2_ctc'
  wenetCtc, // -> 'wenet_ctc'
  telespeechCtc, // -> 'telespeech_ctc'

  // others
  moonshine, // -> 'moonshine'
  paraformer, // -> 'paraformer'
  whisper, // -> 'whisper'

  // streaming transducer
  conformer, // -> 'conformer' (if you like)
  lstm, // -> 'lstm'
  zipformer, // -> 'zipformer'
  zipformer2, // -> 'zipformer2'
  ;

  @override
  String toString() {
    switch (this) {
      case transducer:
        return 'transducer';
      case nemoTransducer:
        return 'nemo_transducer';
      case nemoCtc:
        return 'nemo_ctc';
      case tdnn:
        return 'tdnn';
      case zipformer2Ctc:
        return 'zipformer2_ctc';
      case wenetCtc:
        return 'wenet_ctc';
      case telespeechCtc:
        return 'telespeech_ctc';
      case moonshine:
        return 'moonshine';
      case paraformer:
        return 'paraformer';
      case whisper:
        return 'whisper';

      // Streaming transducer
      case conformer:
        return 'conformer';
      case lstm:
        return 'lstm';
      case zipformer:
        return 'zipformer';
      case zipformer2:
        return 'zipformer2';
    }
  }

  static SherpaModelType fromString(String value) {
    switch (value) {
      case 'transducer':
        return SherpaModelType.transducer;
      case 'nemo_transducer':
        return SherpaModelType.nemoTransducer;
      case 'nemo_ctc':
        return SherpaModelType.nemoCtc;
      case 'tdnn':
        return SherpaModelType.tdnn;
      case 'zipformer2_ctc':
        return SherpaModelType.zipformer2Ctc;
      case 'wenet_ctc':
        return SherpaModelType.wenetCtc;
      case 'telespeech_ctc':
        return SherpaModelType.telespeechCtc;
      case 'moonshine':
        return SherpaModelType.moonshine;
      case 'paraformer':
        return SherpaModelType.paraformer;
      case 'whisper':
        return SherpaModelType.whisper;

      // Streaming transducer
      case 'conformer':
        return SherpaModelType.conformer;
      case 'lstm':
        return SherpaModelType.lstm;
      case 'zipformer':
        return SherpaModelType.zipformer;
      case 'zipformer2':
        return SherpaModelType.zipformer2;
      default:
        throw ArgumentError('Unknown SherpaModelType: $value');
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
