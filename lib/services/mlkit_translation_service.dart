import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages on-device translation using Google ML Kit.
///
/// KEY BEHAVIOUR — "download once" guarantee
/// ─────────────────────────────────────────
/// ML Kit's [isModelDownloaded] only reports whether the binary is currently
/// on disk.  If the user (or the OS) deletes a model file, the method returns
/// false and the splash screen would try to re-download on every cold start —
/// burning mobile data and slowing start-up.
///
/// To prevent this we maintain a **local registry** in SharedPreferences:
///   • [_everDownloadedKey]  →  Set<String> of language codes that have been
///     successfully downloaded at least once.
///
/// [ensureDefaultModels] (called from main.dart's ModelGate) ONLY downloads a
/// default language when it is:
///   (a) not currently on disk  AND
///   (b) not recorded in the ever-downloaded registry.
///
/// In other words: if the user intentionally deletes a model from Settings the
/// app respects that decision and will NOT silently re-download it on the next
/// launch.  The user must tap the Download button in Settings to get it back.
class OnDeviceTranslationService {
  static final OnDeviceTranslationService _instance =
  OnDeviceTranslationService._internal();
  factory OnDeviceTranslationService() => _instance;
  OnDeviceTranslationService._internal();

  final OnDeviceTranslatorModelManager _modelManager =
  OnDeviceTranslatorModelManager();

  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const String _configKey = 'translation_languages';

  /// Stores codes of every language model successfully downloaded at least once.
  static const String _everDownloadedKey = 'models_ever_downloaded';

  // ── Defaults ──────────────────────────────────────────────────────────────
  /// The four default Singapore languages pre-downloaded on first launch.
  static const List<String> defaultLanguageCodes = ['en', 'zh', 'ms', 'ta'];

  // ── ML Kit language map ───────────────────────────────────────────────────
  static const Map<String, TranslateLanguage> _codeToLang = {
    'af': TranslateLanguage.afrikaans,
    'ar': TranslateLanguage.arabic,
    'be': TranslateLanguage.belarusian,
    'bg': TranslateLanguage.bulgarian,
    'bn': TranslateLanguage.bengali,
    'ca': TranslateLanguage.catalan,
    'cs': TranslateLanguage.czech,
    'cy': TranslateLanguage.welsh,
    'da': TranslateLanguage.danish,
    'de': TranslateLanguage.german,
    'el': TranslateLanguage.greek,
    'en': TranslateLanguage.english,
    'eo': TranslateLanguage.esperanto,
    'es': TranslateLanguage.spanish,
    'et': TranslateLanguage.estonian,
    'fa': TranslateLanguage.persian,
    'fi': TranslateLanguage.finnish,
    'fr': TranslateLanguage.french,
    'ga': TranslateLanguage.irish,
    'gl': TranslateLanguage.galician,
    'gu': TranslateLanguage.gujarati,
    'he': TranslateLanguage.hebrew,
    'hi': TranslateLanguage.hindi,
    'hr': TranslateLanguage.croatian,
    'hu': TranslateLanguage.hungarian,
    'id': TranslateLanguage.indonesian,
    'is': TranslateLanguage.icelandic,
    'it': TranslateLanguage.italian,
    'ja': TranslateLanguage.japanese,
    'ka': TranslateLanguage.georgian,
    'kn': TranslateLanguage.kannada,
    'ko': TranslateLanguage.korean,
    'lt': TranslateLanguage.lithuanian,
    'lv': TranslateLanguage.latvian,
    'mk': TranslateLanguage.macedonian,
    'mr': TranslateLanguage.marathi,
    'ms': TranslateLanguage.malay,
    'mt': TranslateLanguage.maltese,
    'nl': TranslateLanguage.dutch,
    'no': TranslateLanguage.norwegian,
    'pl': TranslateLanguage.polish,
    'pt': TranslateLanguage.portuguese,
    'ro': TranslateLanguage.romanian,
    'ru': TranslateLanguage.russian,
    'sk': TranslateLanguage.slovak,
    'sl': TranslateLanguage.slovenian,
    'sq': TranslateLanguage.albanian,
    'sv': TranslateLanguage.swedish,
    'sw': TranslateLanguage.swahili,
    'ta': TranslateLanguage.tamil,
    'te': TranslateLanguage.telugu,
    'th': TranslateLanguage.thai,
    'tl': TranslateLanguage.tagalog,
    'tr': TranslateLanguage.turkish,
    'uk': TranslateLanguage.ukrainian,
    'ur': TranslateLanguage.urdu,
    'vi': TranslateLanguage.vietnamese,
    'zh': TranslateLanguage.chinese,
  };

  /// All supported languages with friendly display names.
  static const Map<String, String> allSupportedLanguages = {
    'af': 'Afrikaans',
    'ar': 'Arabic',
    'be': 'Belarusian',
    'bg': 'Bulgarian',
    'bn': 'Bengali',
    'ca': 'Catalan',
    'cs': 'Czech',
    'cy': 'Welsh',
    'da': 'Danish',
    'de': 'German',
    'el': 'Greek',
    'en': 'English',
    'eo': 'Esperanto',
    'es': 'Spanish',
    'et': 'Estonian',
    'fa': 'Persian',
    'fi': 'Finnish',
    'fr': 'French',
    'ga': 'Irish',
    'gl': 'Galician',
    'gu': 'Gujarati',
    'he': 'Hebrew',
    'hi': 'Hindi',
    'hr': 'Croatian',
    'ht': 'Haitian Creole',
    'hu': 'Hungarian',
    'id': 'Indonesian',
    'is': 'Icelandic',
    'it': 'Italian',
    'ja': 'Japanese',
    'ka': 'Georgian',
    'kn': 'Kannada',
    'ko': 'Korean',
    'lt': 'Lithuanian',
    'lv': 'Latvian',
    'mk': 'Macedonian',
    'mr': 'Marathi',
    'ms': 'Malay',
    'mt': 'Maltese',
    'nl': 'Dutch',
    'no': 'Norwegian',
    'pl': 'Polish',
    'pt': 'Portuguese',
    'ro': 'Romanian',
    'ru': 'Russian',
    'sk': 'Slovak',
    'sl': 'Slovenian',
    'sq': 'Albanian',
    'sr': 'Serbian',
    'sv': 'Swedish',
    'sw': 'Swahili',
    'ta': 'Tamil',
    'te': 'Telugu',
    'th': 'Thai',
    'tl': 'Filipino',
    'tr': 'Turkish',
    'uk': 'Ukrainian',
    'ur': 'Urdu',
    'vi': 'Vietnamese',
    'zh': 'Chinese',
  };

  // ── In-memory state ───────────────────────────────────────────────────────

  /// Active (selected) languages shown in the language bar. Max 4.
  List<String> _configuredLanguages = List.from(defaultLanguageCodes);

  /// Registry of all codes ever successfully downloaded on this device.
  Set<String> _everDownloaded = {};

  List<String> get configuredLanguages => List.unmodifiable(_configuredLanguages);

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load active language list
    final saved = prefs.getStringList(_configKey);
    _configuredLanguages = (saved != null && saved.isNotEmpty)
        ? saved
        : List.from(defaultLanguageCodes);

    // Load ever-downloaded registry
    final everList = prefs.getStringList(_everDownloadedKey) ?? [];
    _everDownloaded = Set<String>.from(everList);
  }

  Future<void> setConfiguredLanguages(List<String> codes) async {
    _configuredLanguages = List.from(codes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_configKey, codes);
  }

  // ── Ever-downloaded registry ──────────────────────────────────────────────

  /// Returns true if [langCode] has been successfully downloaded at least once
  /// on this device, regardless of whether the model file still exists.
  bool wasEverDownloaded(String langCode) => _everDownloaded.contains(langCode);

  /// Marks [langCode] as ever-downloaded and persists the registry.
  Future<void> _markEverDownloaded(String langCode) async {
    if (_everDownloaded.contains(langCode)) return; // already recorded
    _everDownloaded.add(langCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_everDownloadedKey, _everDownloaded.toList());
  }

  /// Removes [langCode] from the ever-downloaded registry.
  /// Call this when the user explicitly deletes a model via Settings,
  /// so the splash screen knows it is truly gone and must be re-downloaded
  /// if the language is re-added.
  Future<void> _unmarkEverDownloaded(String langCode) async {
    _everDownloaded.remove(langCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_everDownloadedKey, _everDownloaded.toList());
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  TranslateLanguage? _toMlKitLang(String code) => _codeToLang[code];

  String _bcpCode(String code) {
    final lang = _toMlKitLang(code);
    return lang?.bcpCode ?? code;
  }

  // ── Model management ──────────────────────────────────────────────────────

  /// Checks whether the model binary is currently on disk (live ML Kit query).
  Future<bool> isModelDownloaded(String langCode) async {
    try {
      return await _modelManager.isModelDownloaded(_bcpCode(langCode));
    } catch (_) {
      return false;
    }
  }

  /// Downloads the model for [langCode], marks it in the ever-downloaded
  /// registry on success, and returns true/false.
  Future<bool> downloadModel(String langCode) async {
    try {
      final bcp = _bcpCode(langCode);
      await _modelManager.downloadModel(bcp, isWifiRequired: false);
      final ok = await _modelManager.isModelDownloaded(bcp);
      if (ok) await _markEverDownloaded(langCode);
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Deletes the model binary AND removes [langCode] from the ever-downloaded
  /// registry so the splash screen will offer to re-download it if needed.
  Future<bool> deleteModel(String langCode) async {
    try {
      await _modelManager.deleteModel(_bcpCode(langCode));
      await _unmarkEverDownloaded(langCode);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Downloads default languages that satisfy BOTH conditions:
  ///   1. Not currently on disk ([isModelDownloaded] → false), AND
  ///   2. Never been successfully downloaded ([wasEverDownloaded] → false).
  Future<void> ensureDefaultModels({
    void Function(String langCode, int current, int total)? onProgress,
  }) async {
    final missing = <String>[];
    for (final code in defaultLanguageCodes) {
      final onDisk = await isModelDownloaded(code);
      final everHad = wasEverDownloaded(code);
      if (!onDisk && !everHad) {
        missing.add(code);
      }
    }

    if (missing.isEmpty) return;

    int completed = 0;
    await Future.wait(missing.map((code) async {
      await downloadModel(code);
      completed++;
      onProgress?.call(code, completed, missing.length);
    }));
  }

  /// Silently kick off background downloads for configured (non-default) languages.
  void preloadConfiguredModels() {
    for (final code in _configuredLanguages) {
      if (!defaultLanguageCodes.contains(code)) {
        _silentEnsure(code);
      }
    }
  }

  Future<void> _silentEnsure(String langCode) async {
    if (!await isModelDownloaded(langCode)) {
      await downloadModel(langCode);
    }
  }

  // ── Translation ───────────────────────────────────────────────────────────

  Future<Map<String, String>> translateToAllConfigured(String text) async {
    final results = <String, String>{};
    if (text.isEmpty || text == '[No text found]') {
      for (final code in _configuredLanguages) {
        results[code] = text;
      }
      return results;
    }

    for (final code in _configuredLanguages) {
      results[code] = await _translateOne(text, code);
    }
    return results;
  }

  /// Translate [text] from English to a single [targetCode].
  /// Used for one-off translations such as the voice preview sentence.
  Future<String> translateSingleTo(String text, String targetCode) async {
    if (text.isEmpty) return text;
    if (targetCode == 'en') return text;
    return _translateOne(text, targetCode);
  }

  Future<String> _translateOne(String text, String targetCode) async {
    final targetLang = _toMlKitLang(targetCode);
    if (targetLang == null) return text;

    if (!await isModelDownloaded(targetCode)) {
      final ok = await downloadModel(targetCode);
      if (!ok) return text;
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: targetLang,
    );
    try {
      return await translator.translateText(text);
    } catch (_) {
      return text;
    } finally {
      translator.close();
    }
  }

  // ── Status helpers ────────────────────────────────────────────────────────

  Future<Map<String, bool>> getDownloadStatus() async {
    final status = <String, bool>{};
    for (final code in _configuredLanguages) {
      status[code] = await isModelDownloaded(code);
    }
    return status;
  }

  String displayName(String code) =>
      allSupportedLanguages[code] ?? code.toUpperCase();
}