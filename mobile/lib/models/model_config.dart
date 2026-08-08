class ModelConfig {
  final String id;
  final String type; // 'vosk' | 'mlkit'
  final String name;
  final String languageCode;
  final String identifier;
  final String? downloadUrl;
  final String? fileUrl; // đường dẫn tương đối file đã Admin upload trên backend (nếu có)
  final String? originalFileName;
  final double? sizeMB;
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
      sizeMB: (json['sizeMB'] as num?)?.toDouble(),
      description: json['description'],
      isActive: json['isActive'] ?? true,
    );
  }

  /// Dùng để cache config này xuống máy (xem `ModelService`), phục vụ lúc
  /// không gọi được backend (offline / tắt backend) nhưng đã từng lấy được
  /// config này thành công trước đó.
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type,
      'name': name,
      'languageCode': languageCode,
      'identifier': identifier,
      'downloadUrl': downloadUrl,
      'fileUrl': fileUrl,
      'originalFileName': originalFileName,
      'sizeMB': sizeMB,
      'description': description,
      'isActive': isActive,
    };
  }
}