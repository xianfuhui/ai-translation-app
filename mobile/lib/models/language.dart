class LanguageModel {
  final String id;
  final String code;
  final String name;

  LanguageModel({
    required this.id,
    required this.code,
    required this.name,
  });

  factory LanguageModel.fromJson(Map<String, dynamic> json) {
    return LanguageModel(
      id: json['_id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
    );
  }
}
