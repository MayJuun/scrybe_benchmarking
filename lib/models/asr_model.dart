import 'package:path/path.dart' as p;

class AsrModel {
  const AsrModel({
    required this.name,
    required String encoder,
    required String decoder,
    required String joiner,
    required String tokens,
    this.modelType = 'zipformer2',
  })  : _encoder = encoder,
        _decoder = decoder,
        _joiner = joiner,
        _tokens = tokens;

  final String name;
  final String _encoder;
  final String _decoder;
  final String _joiner;
  final String _tokens;
  final String modelType;

  String get encoder => p.join(name, _encoder);
  String get decoder => p.join(name, _decoder);
  String get joiner => p.join(name, _joiner);
  String get tokens => p.join(name, _tokens);

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'encoder': _encoder,
      'decoder': _decoder,
      'joiner': _joiner,
      'tokens': _tokens,
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
      encoder: encoder ?? _encoder,
      decoder: decoder ?? _decoder,
      joiner: joiner ?? _joiner,
      tokens: tokens ?? _tokens,
      modelType: modelType ?? this.modelType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AsrModel &&
        other.name == name &&
        other._encoder == _encoder &&
        other._decoder == _decoder &&
        other._joiner == _joiner &&
        other._tokens == _tokens &&
        other.modelType == modelType;
  }

  @override
  int get hashCode {
    return Object.hash(
      name,
      _encoder,
      _decoder,
      _joiner,
      _tokens,
      modelType,
    );
  }
}