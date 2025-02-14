class PunctuationModel {
  const PunctuationModel({
    required this.name,
    required this.model,
    required this.vocab,
  });

  final String name;
  final String model;
  final String vocab;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'model': model,
      'vocab': vocab,
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
      model: model ?? this.model,
      vocab: vocab ?? this.vocab,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PunctuationModel &&
        other.name == name &&
        other.model == model &&
        other.vocab == vocab;
  }

  @override
  int get hashCode => Object.hash(name, model, vocab);
}
