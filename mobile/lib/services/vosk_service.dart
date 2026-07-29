import 'dart:async';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

/// Bọc gọn API của `vosk_flutter` để nhận diện giọng nói offline.
///
/// Cách dùng trong 1 màn hình:
/// ```dart
/// final vosk = VoskService();
/// await vosk.loadModel(modelUrl, languageCode: 'en');
/// await vosk.start(
///   onResult: (text) => print('Câu hoàn chỉnh: $text'),
///   onPartial: (text) => print('Đang nói: $text'),
/// );
/// ...
/// await vosk.stop();
/// await vosk.dispose();
/// ```
class VoskService {
  static const int _sampleRate = 16000;

  final _vosk = VoskFlutterPlugin.instance();
  final _modelLoader = ModelLoader();

  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  String? _loadedLanguageCode;

  StreamSubscription<String>? _resultSubscription;
  StreamSubscription<String>? _partialSubscription;

  bool get isModelLoaded => _speechService != null;
  bool get isListening => _isListening;
  bool _isListening = false;

  /// Xin quyền truy cập microphone. Trả về true nếu được cấp quyền.
  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Tải (nếu cần tải qua mạng) và nạp model Vosk cho 1 ngôn ngữ.
  /// [modelUrl] là link file .zip - lấy từ `ModelService().getDownloadUrl(voskModel)`.
  /// Không tải lại nếu ngôn ngữ này đã được nạp sẵn từ trước.
  Future<void> loadModel(String modelUrl, {required String languageCode}) async {
    if (_loadedLanguageCode == languageCode && _model != null) return;

    await _teardown();

    // ModelLoader tự tải model .zip qua mạng, cache lại, và giải nén sẵn.
    final modelPath = await _modelLoader.loadFromNetwork(modelUrl);
    _model = await _vosk.createModel(modelPath);
    _recognizer = await _vosk.createRecognizer(model: _model!, sampleRate: _sampleRate);
    _speechService = await _vosk.initSpeechService(_recognizer!);
    _loadedLanguageCode = languageCode;
  }

  /// Bắt đầu nghe mic và nhận diện liên tục.
  /// [onResult] được gọi mỗi khi có 1 câu hoàn chỉnh (final result).
  /// [onPartial] (tùy chọn) được gọi liên tục trong lúc đang nói (partial result),
  /// hữu ích để hiển thị "đang nói..." theo thời gian thực.
  Future<void> start({
    required void Function(String text) onResult,
    void Function(String text)? onPartial,
  }) async {
    final service = _speechService;
    if (service == null) {
      throw Exception('Model Vosk chưa được nạp - gọi loadModel() trước khi start()');
    }

    final granted = await requestMicPermission();
    if (!granted) {
      throw Exception('Chưa được cấp quyền truy cập microphone');
    }

    await _resultSubscription?.cancel();
    await _partialSubscription?.cancel();

    _resultSubscription = service.onResult().listen((resultJson) {
      final text = _extractField(resultJson, 'text');
      if (text.isNotEmpty) onResult(text);
    });

    if (onPartial != null) {
      _partialSubscription = service.onPartial().listen((partialJson) {
        final text = _extractField(partialJson, 'partial');
        if (text.isNotEmpty) onPartial(text);
      });
    }

    await service.start();
    _isListening = true;
  }

  /// Dừng nghe mic (giữ nguyên model đã nạp để dùng lại lần sau, không cần tải lại).
  Future<void> stop() async {
    await _speechService?.stop();
    await _resultSubscription?.cancel();
    await _partialSubscription?.cancel();
    _resultSubscription = null;
    _partialSubscription = null;
    _isListening = false;
  }

  String _extractField(String json, String key) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return (map[key] as String?)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _teardown() async {
    await stop();
    _speechService = null;
    _recognizer = null;
    _model = null;
    _loadedLanguageCode = null;
  }

  Future<void> dispose() async {
    await _teardown();
  }
}
