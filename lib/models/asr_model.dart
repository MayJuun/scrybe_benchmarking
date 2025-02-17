/// The recognized model types that your code handles.
enum SherpaModelType {
  // Offline Transducer
  transducer, // -> 'transducer'
  nemoTransducer, // -> 'nemo_transducer'

  // Offline CTC
  tdnn, // -> 'tdnn'
  wenetCtc, // -> 'wenet_ctc'
  telespeechCtc, // -> 'telespeech_ctc'

  // Nemo CTC, split into offline vs. online
  nemoCtcOffline, // -> 'nemo_ctc'
  nemoCtcOnline, // -> 'nemo_ctc'

  // Zipformer CTC
  zipformer2Ctc, // -> 'zipformer2_ctc'

  // Zipformer Transducer
  zipformer, // -> 'zipformer'   (offline)
  zipformer2, // -> 'zipformer2'  (online streaming)

  // Others
  moonshine, // -> 'moonshine'
  paraformer, // -> 'paraformer'
  whisper, // -> 'whisper'

  // Additional streaming transducer types
  conformer, // -> 'conformer'
  lstm, // -> 'lstm'
  ;

  @override
  String toString() {
    switch (this) {
      case transducer:
        return 'transducer';
      case nemoTransducer:
        return 'nemo_transducer';
      case tdnn:
        return 'tdnn';
      case wenetCtc:
        return 'wenet_ctc';
      case telespeechCtc:
        return 'telespeech_ctc';

      // Nemo CTC, offline and online both map to "nemo_ctc"
      case nemoCtcOffline:
        return 'nemo_ctc';
      case nemoCtcOnline:
        return 'nemo-ctc-model';

      case zipformer2Ctc:
        return 'zipformer2_ctc';
      case zipformer:
        return 'zipformer';
      case zipformer2:
        return 'zipformer2';

      case moonshine:
        return 'moonshine';
      case paraformer:
        return 'paraformer';
      case whisper:
        return 'whisper';

      case conformer:
        return 'conformer';
      case lstm:
        return 'lstm';
    }
  }

  static SherpaModelType fromString(String value) {
    switch (value) {
      case 'transducer':
        return SherpaModelType.transducer;
      case 'nemo_transducer':
        return SherpaModelType.nemoTransducer;
      case 'tdnn':
        return SherpaModelType.tdnn;
      case 'wenet_ctc':
        return SherpaModelType.wenetCtc;
      case 'telespeech_ctc':
        return SherpaModelType.telespeechCtc;

      case 'nemo_ctc':
        // By default, treat 'nemo_ctc' as offline.
        // If needed, you can decide a different approach here.
        return SherpaModelType.nemoCtcOffline;

      case 'zipformer2_ctc':
        return SherpaModelType.zipformer2Ctc;
      case 'zipformer':
        return SherpaModelType.zipformer;
      case 'zipformer2':
        return SherpaModelType.zipformer2;

      case 'moonshine':
        return SherpaModelType.moonshine;
      case 'paraformer':
        return SherpaModelType.paraformer;
      case 'whisper':
        return SherpaModelType.whisper;

      case 'conformer':
        return SherpaModelType.conformer;
      case 'lstm':
        return SherpaModelType.lstm;
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
