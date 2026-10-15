import '../models/language.dart';
import '../models/model_config.dart';

/// Defaults that let the app work with ZERO backend contact (guest mode or a
/// fresh install with the server down). They are only used when neither the
/// backend nor a previously cached config can supply the data.
class BuiltinModels {
  BuiltinModels._();

  /// Languages offered when the backend list was never fetched.
  /// `code` is the BCP-47 code ML Kit expects, `id` simply repeats it.
  static List<LanguageModel> languages() => const [
        ['en', 'Tiếng Anh'],
        ['vi', 'Tiếng Việt'],
        ['ja', 'Tiếng Nhật'],
        ['ko', 'Tiếng Hàn'],
        ['zh', 'Tiếng Trung'],
        ['fr', 'Tiếng Pháp'],
        ['de', 'Tiếng Đức'],
        ['es', 'Tiếng Tây Ban Nha'],
        ['ru', 'Tiếng Nga'],
        ['th', 'Tiếng Thái'],
        ['it', 'Tiếng Ý'],
        ['pt', 'Tiếng Bồ Đào Nha'],
        ['id', 'Tiếng Indonesia'],
      ].map((e) => LanguageModel(id: e[0], code: e[0], name: e[1])).toList();

  static const _voskBase = 'https://alphacephei.com/vosk/models/';

  /// Small Vosk models published by the Vosk project (language code -> zip
  /// name without extension). Downloaded straight from alphacephei.com, no
  /// backend needed.
  static const _vosk = {
    'en': 'vosk-model-small-en-us-0.15',
    'vi': 'vosk-model-small-vn-0.4',
    'ja': 'vosk-model-small-ja-0.22',
    'ko': 'vosk-model-small-ko-0.22',
    'zh': 'vosk-model-small-cn-0.22',
    'fr': 'vosk-model-small-fr-0.22',
    'de': 'vosk-model-small-de-0.15',
    'es': 'vosk-model-small-es-0.42',
    'ru': 'vosk-model-small-ru-0.22',
    'it': 'vosk-model-small-it-0.22',
    'pt': 'vosk-model-small-pt-0.3',
  };

  static ModelConfig? vosk(String languageCode) {
    final name = _vosk[languageCode];
    if (name == null) return null;
    return ModelConfig(
      id: 'builtin_vosk_$languageCode',
      type: 'vosk',
      name: name,
      languageCode: languageCode,
      identifier: languageCode,
      downloadUrl: '$_voskBase$name.zip',
      description: 'Model mặc định (alphacephei.com)',
    );
  }
}
