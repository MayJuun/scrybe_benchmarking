import 'package:path/path.dart' as p;

class PunctuationModel {
  const PunctuationModel({
    required this.name,
    required String model,
    required String vocab,
  })  : _model = model,
        _vocab = vocab;

  final String name;
  final String _model;
  final String _vocab;

  String get model => p.join(name, _model);
  String get vocab => p.join(name, _vocab);

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'model': _model,
      'vocab': _vocab,
    };
  }

  factory PunctuationModel.fromJson(Map<String, dynamic> json) {
    return PunctuationModel(
      name: json['name'] as String,
      model: json['model'] as String,
      vocab: json['vocab'] as String,
    );
  }

  @override
  String toString() => 'PunctuationModel($name)';

  PunctuationModel copyWith({
    String? name,
    String? model,
    String? vocab,
  }) {
    return PunctuationModel(
      name: name ?? this.name,
      model: model ?? _model,
      vocab: vocab ?? _vocab,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PunctuationModel &&
        other.name == name &&
        other._model == _model &&
        other._vocab == _vocab;
  }

  @override
  int get hashCode => Object.hash(name, _model, _vocab);
}