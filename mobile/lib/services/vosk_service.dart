import 'dart:async';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

/// Bọc gọn API của `vosk_flutter_2` để nhận diện giọng nói offline.
///
/// Cách dùng trong 1 màn hình:
/// ```dart
/// final vosk = VoskService();
/// await vosk.loadModel(modelUrl);
/// await vosk.startListening(
///   onResult: (text) => print('Câu hoàn chỉnh: $text'),
///   onPartial: (text) => print('Đang nói: $text'),
/// );
/// ...
/// await vosk.stopListening();
/// await vosk.dispose();
/// ```
class VoskService {
  static const int _sampleRate = 16000;

  final _vosk = VoskFlutterPlugin.instance();
  final _modelLoader = ModelLoader();

  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  String? _loadedModelUrl;

  StreamSubscription<String>? _resultSubscription;
  StreamSubscription<String>? _partialSubscription;

  bool get isModelLoaded => _speechService != null;
  bool get isListening => _isListening;
  bool _isListening = false;

  // Tăng dần mỗi lần loadModel()/dispose() được gọi. Dùng để nhận biết 1 lệnh
  // loadModel() đang chạy dở có còn "hợp lệ" không sau khi 1 lệnh khác (ví dụ
  // teardown do người dùng bấm Dừng giữa chừng) đã xen vào - tránh việc model
  // tải xong muộn vẫn bị gán vào state, gây "hồi sinh" 1 phiên đã bị huỷ.
  int _operationId = 0;

  /// Xin quyền truy cập microphone. Trả về true nếu được cấp quyền.
  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Tải (nếu cần tải qua mạng) và nạp model Vosk.
  /// [modelUrl] là link file .zip - lấy từ `ModelService().getDownloadUrl(voskModel)`.
  /// Không tải lại nếu model với cùng URL này đã được nạp sẵn từ trước.
  ///
  /// Có timeout (mặc định 3 phút) cho bước tải qua mạng - nếu mạng chập
  /// chờn/URL không phản hồi, hàm sẽ ném lỗi thay vì treo UI vô thời hạn.
  ///
  /// Nếu trong lúc đang tải, `dispose()`/`loadModel()` khác được gọi (vd người
  /// dùng bấm Dừng rồi Bắt đầu lại), lệnh tải cũ sẽ tự huỷ kết quả (không gán
  /// vào state) thay vì "hồi sinh" 1 phiên đã lỗi thời.
  Future<void> loadModel(
    String modelUrl, {
    Duration timeout = const Duration(minutes: 3),
  }) async {
    if (_loadedModelUrl == modelUrl && _speechService != null) return;

    await _teardown();
    final myOperationId = ++_operationId;

    try {
      // ModelLoader tự tải model .zip qua mạng, cache lại, và giải nén sẵn.
      final modelPath = await _modelLoader.loadFromNetwork(modelUrl).timeout(
        timeout,
        onTimeout: () => throw Exception(
          'Tải model quá lâu (quá ${timeout.inSeconds}s) - kiểm tra lại mạng',
        ),
      );
      final model = await _vosk.createModel(modelPath);
      final recognizer = await _vosk.createRecognizer(model: model, sampleRate: _sampleRate);
      final speechService = await _vosk.initSpeechService(recognizer);

      if (myOperationId != _operationId) {
        // Đã có 1 thao tác khác (teardown/loadModel mới) xen vào trong lúc
        // đang tải - bỏ kết quả này, dọn tài nguyên vừa tạo để tránh rò rỉ.
        await speechService.dispose();
        return;
      }

      _model = model;
      _recognizer = recognizer;
      _speechService = speechService;
      _loadedModelUrl = modelUrl;
    } catch (e) {
      if (myOperationId == _operationId) {
        await _teardown();
      }
      throw Exception('Không nạp được model Vosk: $e');
    }
  }

  /// Bắt đầu nghe mic và nhận diện liên tục.
  /// [onResult] được gọi mỗi khi có 1 câu hoàn chỉnh (final result).
  /// [onPartial] (tùy chọn) được gọi liên tục trong lúc đang nói (partial result),
  /// hữu ích để hiển thị "đang nói..." theo thời gian thực.
  Future<void> startListening({
    required void Function(String text) onResult,
    void Function(String text)? onPartial,
  }) async {
    final service = _speechService;
    if (service == null) {
      throw Exception('Model Vosk chưa được nạp - gọi loadModel() trước khi startListening()');
    }
    if (_isListening) return;

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
  Future<void> stopListening() async {
    if (!_isListening) return;
    await _speechService?.stop();
    await _resultSubscription?.cancel();
    await _partialSubscription?.cancel();
    _resultSubscription = null;
    _partialSubscription = null;
    _isListening = false;
  }

  /// Tạm dừng nhận diện (không đóng mic hẳn) - dùng để tránh mic bắt lại
  /// chính tiếng loa đang phát (TTS đọc bản dịch), gây nhận diện lặp/nhiễu.
  /// Gọi [resumeListening] ngay sau khi phát xong.
  Future<void> pauseListening() async {
    if (!_isListening) return;
    await _speechService?.setPause(paused: true);
  }

  Future<void> resumeListening() async {
    if (!_isListening) return;
    await _speechService?.setPause(paused: false);
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
    _operationId++; // huỷ hiệu lực mọi loadModel() đang chạy dở
    await stopListening();
    final oldSpeechService = _speechService;
    _speechService = null;
    _recognizer = null;
    _model = null;
    _loadedModelUrl = null;
    await oldSpeechService?.dispose();
  }

  Future<void> dispose() async {
    await _teardown();
  }
}
