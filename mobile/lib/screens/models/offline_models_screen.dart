import 'package:flutter/material.dart';
import '../../core/backend_status.dart';
import '../../core/builtin_models.dart';
import '../../core/offline_packs.dart';
import '../../core/theme.dart';
import '../../models/language.dart';
import '../../models/model_config.dart';
import '../../services/language_service.dart';
import '../../services/model_service.dart';
import '../../services/translation_service.dart';
import '../../services/vosk_service.dart';

/// "Offline packs": download the language packs once (needs internet), then
/// translation and speech recognition run fully on the device, with no backend
/// or network access.
///
///  - ML Kit packs power text translation (any Android / iOS device).
///  - Vosk packs power speech-to-text (Android only).
class OfflineModelsScreen extends StatefulWidget {
  const OfflineModelsScreen({super.key});

  @override
  State<OfflineModelsScreen> createState() => _OfflineModelsScreenState();
}

class _OfflineModelsScreenState extends State<OfflineModelsScreen> {
  final _languageService = LanguageService();
  final _translation = TranslationService();
  final _vosk = VoskService();
  final _models = ModelService();

  List<LanguageModel> _languages = [];
  final Map<String, bool> _mlkitReady = {};
  final Map<String, bool> _voskReady = {};
  final Map<String, ModelConfig> _voskConfig = {};
  // Mỗi gói đang tải/xóa có 1 "job": tải thì có % + nút Hủy, xóa thì chỉ xoay.
  final Map<String, _PackJob> _jobs = {};
  bool _loading = true; // chỉ khi đang lấy danh sách ngôn ngữ
  bool _checking = false; // đang kiểm tra gói nào đã tải
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // Chạy sau khung hình đầu: không đụng setState ngay trong initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    for (final job in _jobs.values) {
      job.cancel.cancel(); // rời màn hình thì dừng các lượt tải đang chạy
    }
    _translation.dispose();
    super.dispose();
  }

  /// Hiện danh sách ngôn ngữ NGAY, rồi kiểm tra trạng thái từng gói song song.
  /// Mỗi bước tự bắt lỗi nên một gói lỗi/chậm không làm cả màn bị trống.
  Future<void> _load() async {
    try {
      await _loadImpl();
    } catch (e, st) {
      // Bất kỳ lỗi nào cũng hiện ra màn hình (thay vì để màn trống).
      debugPrint('OfflineModelsScreen._load lỗi: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _checking = false;
        _loadError = 'Lỗi khi tải màn này: $e';
        if (_languages.isEmpty) _languages = BuiltinModels.languages();
      });
    }
  }

  Future<void> _loadImpl() async {
    setState(() {
      _loading = _languages.isEmpty;
      _loadError = null;
    });
    List<LanguageModel> langs;
    try {
      langs = await _languageService
          .getLanguages()
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      langs = BuiltinModels.languages();
    }
    if (!mounted) return;
    setState(() {
      _languages = langs;
      _loading = false;
      _checking = true;
    });
    await Future.wait(langs.map((lang) async {
      try {
        await _refreshStatus(lang.code);
      } catch (e) {
        _loadError ??= '$e';
      }
      if (mounted) setState(() {});
    }));
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _refreshStatus(String code) async {
    // ML Kit và Vosk tách riêng: lỗi bên này không làm mất trạng thái bên kia.
    try {
      if (_translation.isSupported(code)) {
        _mlkitReady[code] = await _translation.isModelDownloaded(code);
      }
    } catch (e) {
      _mlkitReady[code] = false;
      _loadError ??= 'Không kiểm tra được gói dịch: $e';
    }
    try {
      if (VoskService.isSupported) {
        final config = await _models.getActiveVoskModel(code);
        if (config != null) {
          _voskConfig[code] = config;
          final url = _models.getDownloadUrl(config);
          _voskReady[code] = url != null && await _vosk.isModelDownloaded(url);
        } else {
          _voskConfig.remove(code);
          _voskReady.remove(code);
        }
      }
    } catch (e) {
      _loadError ??= 'Không kiểm tra được gói giọng nói: $e';
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toastError(Object e) {
    if (e is DownloadCancelled) {
      _toast('Đã hủy tải');
    } else if (e is NoInternetException) {
      _toast(e.message);
    } else {
      _toast('Không thực hiện được, thử lại sau ($e)');
    }
  }

  void _cancelJob(String key) => _jobs[key]?.cancel.cancel();

  Future<void> _toggleMlkit(LanguageModel lang) async {
    final key = 'mlkit_${lang.code}';
    if (_jobs.containsKey(key)) return;
    final deleting = _mlkitReady[lang.code] == true;
    final job = _PackJob(deleting: deleting);
    setState(() => _jobs[key] = job);
    try {
      if (deleting) {
        await _translation.deleteModel(lang.code);
      } else {
        BackendStatus.reset();
        await _translation.downloadModel(lang.code, cancel: job.cancel);
      }
      await _refreshStatus(lang.code);
      OfflinePacks.notifyChanged();
    } catch (e) {
      _toastError(e);
    } finally {
      if (mounted) setState(() => _jobs.remove(key));
    }
  }

  Future<void> _toggleVosk(LanguageModel lang) async {
    final config = _voskConfig[lang.code];
    if (config == null) return;
    final url = _models.getDownloadUrl(config);
    if (url == null || url.isEmpty) return;
    final key = 'vosk_${lang.code}';
    if (_jobs.containsKey(key)) return;
    final deleting = _voskReady[lang.code] == true;
    final job = _PackJob(deleting: deleting);
    setState(() => _jobs[key] = job);
    try {
      if (deleting) {
        await _vosk.deleteModel(url);
        await _models.unmarkVoskInstalled(lang.code);
      } else {
        await _vosk.downloadModel(
          url,
          cancel: job.cancel,
          onProgress: (p) {
            if (mounted) setState(() => job.progress = p);
          },
        );
        await _models.markVoskInstalled(lang.code, config);
      }
      await _refreshStatus(lang.code);
      OfflinePacks.notifyChanged();
    } catch (e) {
      _toastError(e);
    } finally {
      if (mounted) setState(() => _jobs.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mlkitLangs = _languages.where((l) => _translation.isSupported(l.code)).toList();
    final voskLangs = _languages.where((l) => _voskConfig.containsKey(l.code)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Gói ngoại tuyến')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd, 8, AppTheme.spaceMd, 32,
              ),
              children: [
                if (_checking)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                if (_loadError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    decoration: BoxDecoration(
                      color: AppTheme.coralTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _loadError!,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            BackendStatus.reset();
                            _load();
                          },
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: AppTheme.sand,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Tải một lần khi có mạng. Sau đó dịch và nhận diện giọng nói '
                    'chạy hoàn toàn trên máy — không cần mạng hay máy chủ.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 20),
                Text('Dịch văn bản (ML Kit)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final lang in mlkitLangs)
                        _packTile(
                          title: lang.name,
                          ready: _mlkitReady[lang.code] == true,
                          checking: _checking && !_mlkitReady.containsKey(lang.code),
                          job: _jobs['mlkit_${lang.code}'],
                          onPressed: () => _toggleMlkit(lang),
                          onCancel: () => _cancelJob('mlkit_${lang.code}'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Nhận diện giọng nói (Vosk)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (!VoskService.isSupported)
                  Text(
                    'Chỉ hỗ trợ trên Android.',
                    style: TextStyle(color: AppTheme.moss.withValues(alpha: .6)),
                  )
                else if (voskLangs.isEmpty)
                  Text(
                    _checking
                        ? 'Đang kiểm tra…'
                        : 'Chưa có model giọng nói nào cho các ngôn ngữ hiện có.',
                    style: TextStyle(color: AppTheme.moss.withValues(alpha: .6)),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final lang in voskLangs)
                          _packTile(
                            title: lang.name,
                            ready: _voskReady[lang.code] == true,
                            job: _jobs['vosk_${lang.code}'],
                            onPressed: () => _toggleVosk(lang),
                            onCancel: () => _cancelJob('vosk_${lang.code}'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _packTile({
    required String title,
    required bool ready,
    bool checking = false,
    required _PackJob? job,
    required VoidCallback onPressed,
    required VoidCallback onCancel,
  }) {
    final downloading = job != null && !job.deleting;
    final deleting = job != null && job.deleting;

    final Widget subtitle;
    if (downloading) {
      final p = job!.progress;
      subtitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p == null ? 'Đang tải…' : 'Đang tải… ${(p * 100).clamp(0, 100).round()}%',
            style: TextStyle(fontSize: 12, color: AppTheme.moss),
          ),
          const SizedBox(height: 6),
          // p == null: chưa biết dung lượng (vd ML Kit) -> thanh chạy.
          LinearProgressIndicator(value: p, minHeight: 4),
        ],
      );
    } else {
      subtitle = Text(
        checking
            ? 'Đang kiểm tra…'
            : (ready ? 'Đã tải · dùng được ngoại tuyến' : 'Chưa tải về máy'),
        style: TextStyle(
          fontSize: 12,
          color: ready ? AppTheme.moss : AppTheme.moss.withValues(alpha: .5),
        ),
      );
    }

    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: subtitle,
      trailing: deleting
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : downloading
              ? TextButton(
                  onPressed: job!.cancel.isCancelled ? null : onCancel,
                  child: const Text('Hủy'),
                )
              : (ready
                  ? IconButton(
                      tooltip: 'Xóa khỏi máy',
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: AppTheme.cranberry,
                      onPressed: onPressed,
                    )
                  : FilledButton.tonal(
                      // Theme app đặt minimumSize rộng vô hạn; trong ListTile.trailing
                      // (chiều rộng không giới hạn) nó làm vỡ layout -> màn trống.
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      onPressed: checking ? null : onPressed,
                      child: const Text('Tải'),
                    )),
    );
  }
}

class _PackJob {
  final bool deleting;
  final CancelToken cancel = CancelToken();
  double? progress; // null = chưa biết

  _PackJob({required this.deleting});
}
