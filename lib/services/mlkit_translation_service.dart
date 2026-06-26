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
    'ar': 'العربية',
    'be': 'Беларуская',
    'bg': 'Български',
    'bn': 'বাংলা',
    'ca': 'Català',
    'cs': 'Čeština',
    'cy': 'Cymraeg',
    'da': 'Dansk',
    'de': 'Deutsch',
    'el': 'Ελληνικά',
    'en': 'English',
    'eo': 'Esperanto',
    'es': 'Español',
    'et': 'Eesti',
    'fa': 'فارسی',
    'fi': 'Suomi',
    'fr': 'Français',
    'ga': 'Gaeilge',
    'gl': 'Galego',
    'gu': 'ગુજરાતી',
    'he': 'עברית',
    'hi': 'हिन्दी',
    'hr': 'Hrvatski',
    'ht': 'Kreyòl ayisyen',
    'hu': 'Magyar',
    'id': 'Bahasa Indonesia',
    'is': 'Íslenska',
    'it': 'Italiano',
    'ja': '日本語',
    'ka': 'ქართული',
    'kn': 'ಕನ್ನಡ',
    'ko': '한국어',
    'lt': 'Lietuvių',
    'lv': 'Latviešu',
    'mk': 'Македонски',
    'mr': 'मराठी',
    'ms': 'Bahasa Melayu',
    'mt': 'Malti',
    'nl': 'Nederlands',
    'no': 'Norsk',
    'pl': 'Polski',
    'pt': 'Português',
    'ro': 'Română',
    'ru': 'Русский',
    'sk': 'Slovenčina',
    'sl': 'Slovenščina',
    'sq': 'Shqip',
    'sr': 'Српски',
    'sv': 'Svenska',
    'sw': 'Kiswahili',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'th': 'ไทย',
    'tl': 'Filipino',
    'tr': 'Türkçe',
    'uk': 'Українська',
    'ur': 'اردو',
    'vi': 'Tiếng Việt',
    'zh': '中文',
  };

  // ── In-memory state ───────────────────────────────────────────────────────

  /// Registry of all codes ever successfully downloaded on this device.
  Set<String> _everDownloaded = {};

  List<String> get configuredLanguages {
    final codes = Set<String>.from(defaultLanguageCodes);
    codes.addAll(_everDownloaded);
    return codes.toList();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load ever-downloaded registry
    final everList = prefs.getStringList(_everDownloadedKey) ?? [];
    _everDownloaded = Set<String>.from(everList);
  }

  Future<void> setConfiguredLanguages(List<String> codes) async {
    // No-op now, we compute it dynamically.
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

  /// Batch marks codes as ever-downloaded and persists the registry once.
  Future<void> _markEverDownloadedBatch(List<String> codes) async {
    bool changed = false;
    for (final code in codes) {
      if (!_everDownloaded.contains(code)) {
        _everDownloaded.add(code);
        changed = true;
      }
    }
    if (changed) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_everDownloadedKey, _everDownloaded.toList());
    }
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

  final Map<String, bool> _modelCache = {};

  /// Checks whether the model binary is currently on disk (live ML Kit query).
  /// Results are cached in memory to prevent platform channel flooding when
  /// scrolling long lists of languages.
  Future<bool> isModelDownloaded(String langCode) async {
    if (_modelCache.containsKey(langCode)) return _modelCache[langCode]!;
    try {
      final res = await _modelManager.isModelDownloaded(_bcpCode(langCode));
      _modelCache[langCode] = res;
      return res;
    } catch (_) {
      return false;
    }
  }

  /// Downloads the model for [langCode], marks it in the ever-downloaded
  /// registry on success, and returns true/false.
  Future<bool> downloadModel(String langCode, {bool skipRegistry = false}) async {
    try {
      final bcp = _bcpCode(langCode);
      await _modelManager.downloadModel(bcp, isWifiRequired: false);
      final ok = await _modelManager.isModelDownloaded(bcp);
      if (ok && !skipRegistry) await _markEverDownloaded(langCode);
      _modelCache[langCode] = ok;
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
      _modelCache[langCode] = false;
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
    List<String>? alreadyMissing,
  }) async {
    // If the caller already determined which models are missing (e.g. from a
    // parallel pre-check in _checkModels), skip re-checking to avoid
    // redundant sequential ML Kit calls.
    List<String> missing;
    if (alreadyMissing != null) {
      missing = alreadyMissing;
    } else {
      // Parallel check — all 4 calls fire at the same time instead of one by one.
      final checks = await Future.wait(
        defaultLanguageCodes.map((code) async {
          final onDisk = await isModelDownloaded(code);
          final everHad = wasEverDownloaded(code);
          return (!onDisk && !everHad) ? code : null;
        }),
      );
      missing = checks.whereType<String>().toList();
    }

    if (missing.isEmpty) return;

    int completed = 0;
    final downloadedCodes = <String>[];
    
    await Future.wait(missing.map((code) async {
      final ok = await downloadModel(code, skipRegistry: true);
      if (ok) downloadedCodes.add(code);
      
      completed++;
      onProgress?.call(code, completed, missing.length);
    }));

    if (downloadedCodes.isNotEmpty) {
      await _markEverDownloadedBatch(downloadedCodes);
    }
  }

  /// Silently kick off background downloads for configured (non-default) languages.
  void preloadConfiguredModels() {
    for (final code in configuredLanguages) {
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
      for (final code in configuredLanguages) {
        results[code] = text;
      }
      return results;
    }

    final futures = configuredLanguages.map((code) async {
      final translated = await _translateOne(text, code);
      return MapEntry(code, translated);
    });
    
    final entries = await Future.wait(futures);
    for (final entry in entries) {
      results[entry.key] = entry.value;
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
    if (targetCode == 'en') return text;
    
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

  /// Batch translate UI strings (e.g. from en.json) to the target language.
  /// Skips translation for 'app_name' and empty strings.
  Future<Map<String, String>> translateUIStrings(Map<String, String> sourceMap, String targetCode) async {
    if (targetCode == 'en') return sourceMap;

    final targetLang = _toMlKitLang(targetCode);
    if (targetLang == null) return sourceMap;

    if (!await isModelDownloaded(targetCode)) {
      final ok = await downloadModel(targetCode);
      if (!ok) throw Exception('Model failed to download for $targetCode');
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: targetLang,
    );

    final resultMap = <String, String>{};
    try {
      final entriesToTranslate = sourceMap.entries
          .where((e) => e.key != 'app_name' && e.value.isNotEmpty)
          .toList();

      // ── First pass: translate sequentially ───────────────────────────────
      // Processing concurrently on a single MLKit engine instance can cause
      // silent hangs/deadlocks on some Android devices. Sequential is safer
      // and still fast for UI strings.
      for (final entry in entriesToTranslate) {
        try {
          final translated = await _robustTranslate(translator, entry.value);
          resultMap[entry.key] = translated.trim().isNotEmpty ? translated : entry.value;
        } catch (_) {
          resultMap[entry.key] = entry.value;
        }
      }

      // ── Second pass: retry any entry still identical to English source ────
      // Some ML Kit language models (notably Japanese) silently return the
      // input unchanged for short lowercase noun-phrases. Detect these and
      // retry with a forced full-sentence frame that anchors the engine.
      final failedEntries = entriesToTranslate
          .where((e) => resultMap[e.key] == e.value)
          .toList();

      for (final entry in failedEntries) {
        try {
          final retried = await _sentenceFrameTranslate(translator, entry.value);
          if (retried.trim().isNotEmpty && retried != entry.value) {
            resultMap[entry.key] = retried;
          }
        } catch (_) {
          // Keep the original fallback already in resultMap
        }
      }

      // ── Copy through skipped keys (app_name, empty) ──────────────────────
      for (final entry in sourceMap.entries) {
        if (entry.key == 'app_name' || entry.value.isEmpty) {
          resultMap[entry.key] = entry.value;
        }
      }

      return resultMap;
    } finally {
      translator.close();
    }
  }

  /// Standard robust translation with four escalating strategies.
  Future<String> _robustTranslate(OnDeviceTranslator translator, String text) async {
    // Strategy 1 — plain translation.
    String t = await translator.translateText(text);
    if (t.trim().isNotEmpty && t != text) return t;

    // Strategy 2 — strip trailing punctuation (helps some models).
    if (text.length < 50) {
      final stripped = text.replaceAll(RegExp(r'[.?!]'), '').trim();
      if (stripped.isNotEmpty && stripped != text) {
        t = await translator.translateText(stripped);
        if (t.trim().isNotEmpty && t != stripped) return t;
      }
    }

    // Strategy 3 — sentence-case (helps when model expects a capital).
    if (text.isNotEmpty) {
      final firstChar = text[0];
      if (firstChar.toLowerCase() == firstChar && firstChar.toUpperCase() != firstChar) {
        final sentenceCase = text[0].toUpperCase() + text.substring(1);
        t = await translator.translateText(sentenceCase);
        if (t.trim().isNotEmpty && t != sentenceCase) return t;
      }
    }

    // Strategy 4 — context-prefix ("Note: …").
    // Japanese (and a few other models) silently skip short lowercase noun-
    // phrases. Wrapping with a neutral prefix forces the model to parse the
    // phrase as part of a real sentence.
    final prefixed = 'Note: $text';
    t = await translator.translateText(prefixed);
    if (t.trim().isNotEmpty && t != prefixed) {
      // Strip any translated version of the prefix (keep only the payload).
      final colonIdx = t.indexOf(':');
      if (colonIdx != -1 && colonIdx < t.length - 1) {
        return t.substring(colonIdx + 1).trim();
      }
      return t.trim();
    }

    // Strategy 5 — trailing dot (last resort).
    final dotted = '$text.';
    t = await translator.translateText(dotted);
    if (t.trim().isNotEmpty && t != dotted) {
      return t.endsWith('.') ? t.substring(0, t.length - 1).trim() : t;
    }

    return text; // give up — keep English
  }

  /// Second-pass retry for strings that returned unchanged after _robustTranslate.
  /// Uses a full declarative sentence frame to force the model to translate.
  Future<String> _sentenceFrameTranslate(OnDeviceTranslator translator, String text) async {
    // Wrap in a grammatical frame: "The message reads: <text>."
    final framed = 'The message reads: $text.';
    String t = await translator.translateText(framed);

    if (t.trim().isNotEmpty && t != framed) {
      // Strip the translated frame — keep only the payload after the last colon.
      final colonIdx = t.lastIndexOf(':');
      if (colonIdx != -1 && colonIdx < t.length - 1) {
        final payload = t.substring(colonIdx + 1).trim();
        // Remove trailing period that we injected.
        return payload.endsWith('.') ? payload.substring(0, payload.length - 1).trim() : payload;
      }
      return t.trim();
    }

    // Plain sentence fallback.
    final plain = '${text[0].toUpperCase()}${text.substring(1)}.';
    t = await translator.translateText(plain);
    if (t.trim().isNotEmpty && t != plain) {
      return t.endsWith('.') ? t.substring(0, t.length - 1).trim() : t;
    }

    return text; // still unchanged — keep English
  }

  // ── Status helpers ────────────────────────────────────────────────────────

  Future<Map<String, bool>> getDownloadStatus() async {
    final status = <String, bool>{};
    for (final code in configuredLanguages) {
      status[code] = await isModelDownloaded(code);
    }
    return status;
  }

  /// Returns the native display name of a language code.
  String displayName(String code) {
    return allSupportedLanguages[code] ?? code.toUpperCase();
  }
}