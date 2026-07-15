class LanguageModel {
  final String id;
  final String code;
  final String name;
  final String? translationModel;
  final String? voskModelName;

  LanguageModel({
    required this.id,
    required this.code,
    required this.name,
    this.translationModel,
    this.voskModelName,
  });

  factory LanguageModel.fromJson(Map<String, dynamic> json) {
    return LanguageModel(
      id: json['_id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      translationModel: json['translationModel'],
      voskModelName: json['voskModelName'],
    );
  }
}
