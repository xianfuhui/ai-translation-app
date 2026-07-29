class ModelConfig {
  final String id;
  final String type; // 'vosk' | 'mlkit'
  final String name;
  final String languageCode;
  final String identifier;
  final String? downloadUrl;
  final String? fileUrl; // đường dẫn tương đối file đã Admin upload trên backend (nếu có)
  final String? originalFileName;
  final int? sizeMB;
  final String? description;
  final bool isActive;

  ModelConfig({
    required this.id,
    required this.type,
    required this.name,
    required this.languageCode,
    required this.identifier,
    this.downloadUrl,
    this.fileUrl,
    this.originalFileName,
    this.sizeMB,
    this.description,
    this.isActive = true,
  });

  /// Có file thật (Admin upload) để tải trực tiếp từ backend hay không
  bool get hasUploadedFile => fileUrl != null && fileUrl!.isNotEmpty;

  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    return ModelConfig(
      id: json['_id'] ?? '',
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      languageCode: json['languageCode'] ?? '',
      identifier: json['identifier'] ?? '',
      downloadUrl: json['downloadUrl'],
      fileUrl: json['fileUrl'],
      originalFileName: json['originalFileName'],
      sizeMB: json['sizeMB'],
      description: json['description'],
      isActive: json['isActive'] ?? true,
    );
  }
}
