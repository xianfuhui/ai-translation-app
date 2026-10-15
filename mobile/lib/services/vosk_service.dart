import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, FileSystemEntity, HttpException, Platform, SocketException;
import 'dart:isolate' show Isolate;
import 'package:archive/archive_io.dart' show extractFileToDisk;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import '../core/offline_packs.dart';

/// Giải nén trong isolate riêng cho khỏi giật UI. Phải là hàm độc lập: closure
/// ở đây chỉ được chụp 2 chuỗi đường dẫn — nếu viết thẳng trong hàm tải thì
/// nó kéo theo cả http.Client (không gửi qua isolate được) và báo lỗi
/// "object is unsendable".
Future<void> _extractZipInIsolate(String zipPath, String outPath) {
  return Isolate.run(() => extractFileToDisk(zipPath, outPath));
}

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

  /// `vosk_flutter` chỉ có native code cho Android — trên iOS,
  /// `VoskFlutterPlugin.instance()` ném UnsupportedError ngay khi gọi.
  /// Vì vậy: (1) cờ này cho UI biết để ẩn tính năng giọng nói,
  /// (2) hai field dưới là `late` để việc TẠO VoskService không đụng plugin
  /// (trước đây field initializer chạy lúc tạo State → đỏ cả màn Dịch trên iOS).
  static final bool isSupported = Platform.isAndroid;

  late final _vosk = VoskFlutterPlugin.instance();
  late final _modelLoader = ModelLoader();

  // Giữ tham chiếu để model/recognizer không bị GC trong lúc SpeechService
  // còn dùng chúng phía native — analyzer coi là "unused" nhưng là chủ đích.
  // ignore: unused_field
  Model? _model;
  // ignore: unused_field
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

  // ===== On-device model management (no recognizer is created) =====

  /// Folder name `ModelLoader` derives from a URL: last path segment without
  /// its extension (`.../vosk-model-small-en-us-0.15.zip` -> `vosk-model-small-en-us-0.15`).
  String modelNameFromUrl(String modelUrl) {
    final segments = Uri.parse(modelUrl).pathSegments;
    final last = segments.isEmpty ? modelUrl : segments.last;
    final dot = last.lastIndexOf('.');
    return dot > 0 ? last.substring(0, dot) : last;
  }

  /// True when the model behind [modelUrl] is already unpacked on the device,
  /// i.e. [loadModel] will work without any network access.
  Future<bool> isModelDownloaded(String modelUrl) async {
    if (!isSupported) return false;
    try {
      return await _modelLoader.isModelAlreadyLoaded(modelNameFromUrl(modelUrl));
    } catch (_) {
      return false;
    }
  }

  /// Downloads and unpacks a model without loading it into memory.
  ///
  /// Không còn giới hạn thời gian: tải bao lâu cũng được cho tới khi xong hoặc
  /// người dùng huỷ qua [cancel]. [onProgress] nhận 0.0–1.0 (null = chưa biết
  /// dung lượng, hiện thanh chạy). Mạng lỗi -> [NoInternetException].
  Future<void> downloadModel(
    String modelUrl, {
    void Function(double? progress)? onProgress,
    CancelToken? cancel,
  }) async {
    if (!isSupported) {
      throw Exception('Nhận diện giọng nói offline (Vosk) chưa hỗ trợ iOS');
    }
    final name = modelNameFromUrl(modelUrl);
    if (await isModelDownloaded(modelUrl)) {
      onProgress?.call(1);
      return;
    }

    final target = await _modelLoader.modelPath(name);
    final staging = Directory('$target.downloading');
    final tmp = await Directory.systemTemp.createTemp('vosk_dl_');
    final zipFile = File('${tmp.path}/$name.zip');
    final client = http.Client();
    // Huỷ = đóng kết nối ngay, `await for` bên dưới sẽ ném lỗi.
    unawaited(cancel?.whenCancelled.then((_) => client.close()));

    try {
      onProgress?.call(0);
      final res = await client.send(http.Request('GET', Uri.parse(modelUrl)));
      if (res.statusCode != 200) {
        throw HttpException('Máy chủ trả về mã ${res.statusCode}');
      }
      final total = res.contentLength;
      var received = 0;
      final sink = zipFile.openWrite();
      try {
        await for (final chunk in res.stream) {
          cancel?.throwIfCancelled();
          sink.add(chunk);
          received += chunk.length;
          // 0–95% = tải về, 95–100% = giải nén.
          onProgress?.call(
            total != null && total > 0 ? (received / total * 0.95) : null,
          );
        }
      } finally {
        await sink.close();
      }
      cancel?.throwIfCancelled();

      // Giải nén vào thư mục tạm cạnh đích rồi đổi tên -> không bao giờ để lại
      // model dở dang bị coi là "đã tải".
      if (await staging.exists()) await staging.delete(recursive: true);
      await staging.create(recursive: true);
      final zipPath = zipFile.path;
      final outPath = staging.path;
      await _extractZipInIsolate(zipPath, outPath);
      cancel?.throwIfCancelled();

      final entries = staging.listSync();
      final Directory source =
          (entries.length == 1 && entries.first is Directory)
              ? entries.first as Directory
              : staging;
      final targetDir = Directory(target);
      if (await targetDir.exists()) await targetDir.delete(recursive: true);
      await source.rename(target);
      onProgress?.call(1);
    } on DownloadCancelled {
      rethrow;
    } catch (e) {
      if (cancel?.isCancelled == true) throw const DownloadCancelled();
      if (e is SocketException || e is http.ClientException || e is HttpException) {
        throw const NoInternetException(
          'Không có mạng hoặc không kết nối được máy chủ để tải model. '
          'Hãy kiểm tra kết nối rồi thử lại.',
        );
      }
      rethrow;
    } finally {
      client.close();
      await _deleteQuietly(tmp);
      await _deleteQuietly(staging);
    }
  }

  Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) await entity.delete(recursive: true);
    } catch (_) {}
  }

  /// Removes the unpacked model folder from the device.
  Future<void> deleteModel(String modelUrl) async {
    if (!isSupported) return;
    if (_loadedModelUrl == modelUrl) await _teardown();
    final path = await _modelLoader.modelPath(modelNameFromUrl(modelUrl));
    final dir = Directory(path);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Xin quyền truy cập microphone. Trả về true nếu được cấp quyền.
  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Tải (nếu chưa có trên máy) và nạp model Vosk.
  /// [modelUrl] là link file .zip - lấy từ `ModelService().getDownloadUrl(voskModel)`.
  /// Không tải lại nếu model với cùng URL này đã được nạp sẵn từ trước.
  ///
  /// Không còn timeout: bước tải hiện % qua [onProgress] và dừng được bằng
  /// [cancel] (ném [DownloadCancelled]); mất mạng ném [NoInternetException].
  ///
  /// Nếu trong lúc đang tải, `dispose()`/`loadModel()` khác được gọi (vd người
  /// dùng bấm Dừng rồi Bắt đầu lại), lệnh tải cũ sẽ tự huỷ kết quả (không gán
  /// vào state) thay vì "hồi sinh" 1 phiên đã lỗi thời.
  Future<void> loadModel(
    String modelUrl, {
    void Function(double? progress)? onProgress,
    CancelToken? cancel,
  }) async {
    if (!isSupported) {
      throw Exception('Nhận diện giọng nói offline (Vosk) chưa hỗ trợ iOS');
    }
    if (_loadedModelUrl == modelUrl && _speechService != null) return;

    await _teardown();
    final myOperationId = ++_operationId;

    try {
      // Bước 1: tải + giải nén (có % và huỷ được). Đã có sẵn thì bỏ qua ngay.
      await downloadModel(modelUrl, onProgress: onProgress, cancel: cancel);
      // Bước 2: model đã nằm trên máy nên ModelLoader trả về đường dẫn ngay.
      final modelPath = await _modelLoader.loadFromNetwork(modelUrl);
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
    } on DownloadCancelled {
      rethrow;
    } on NoInternetException {
      rethrow;
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
