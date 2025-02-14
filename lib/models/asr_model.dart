class WhisperModel extends AsrModel {
  WhisperModel(
      {required super.name,
      required super.encoder,
      required super.decoder,
      required super.joiner,
      required super.tokens});
}

class AsrModel {
  const AsrModel({
    required this.name,
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
    this.modelType = 'zipformer2',
  });

  final String name;
  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;
  final String modelType;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'encoder': encoder,
      'decoder': decoder,
      'joiner': joiner,
      'tokens': tokens,
      'modelType': modelType,
    };
  }

  factory AsrModel.fromJson(Map<String, dynamic> json) {
    return AsrModel(
      name: json['name'] as String,
      encoder: json['encoder'] as String,
      decoder: json['decoder'] as String,
      joiner: json['joiner'] as String,
      tokens: json['tokens'] as String,
      modelType: json['modelType'] as String? ?? 'zipformer2',
    );
  }

  @override
  String toString() => 'AsrModel($name)';

  AsrModel copyWith({
    String? name,
    String? encoder,
    String? decoder,
    String? joiner,
    String? tokens,
    String? modelType,
  }) {
    return AsrModel(
      name: name ?? this.name,
      encoder: encoder ?? this.encoder,
      decoder: decoder ?? this.decoder,
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
