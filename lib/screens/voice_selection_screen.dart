import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/tts_service.dart';
import '../services/data_service.dart';
import '../services/mlkit_translation_service.dart';
import '../services/translation_service.dart';

/// VoiceSelectionScreen — one tab per configured language (reactive to user's
/// active language list). Each language has its own saved voice. The preview
/// sentence is translated into that language before being spoken.
class VoiceSelectionScreen extends StatefulWidget {
  const VoiceSelectionScreen({super.key});

  @override
  State<VoiceSelectionScreen> createState() => _VoiceSelectionScreenState();
}

class _VoiceSelectionScreenState extends State<VoiceSelectionScreen>
    with SingleTickerProviderStateMixin {
  final TtsService _tts = TtsService();
  final DataService _data = DataService();
  final AppTranslations _tr = AppTranslations();
  final OnDeviceTranslationService _mlkit = OnDeviceTranslationService();

  // The configured languages drive the tabs — reactive, not hardcoded.
  late List<String> _configuredLangs;

  late TabController _tabController;

  // All device voices, loaded once.
  List<Map<String, String>> _allVoices = [];
  bool _loading = true;

  // Which voice is currently being previewed (by name).
  String? _previewingVoice;

  // Cached translated preview sentences keyed by langCode.
  final Map<String, String> _previewCache = {};

  // The English base sentence that will be translated for each language.
  static const String _basePreviewEn =
      'Hello! This is how I sound. I hope you enjoy listening to me.';

  // Locale prefix patterns used to match device voices to language codes.
  // Extend this map if you add more languages in Settings.
  static const Map<String, List<String>> _langPrefixes = {
    'en': ['en'],
    'zh': ['zh', 'cmn', 'yue'],
    'ms': ['ms', 'id'],
    'ta': ['ta'],
    'hi': ['hi'],
    'fr': ['fr'],
    'de': ['de'],
    'es': ['es'],
    'ja': ['ja'],
    'ko': ['ko'],
    'ar': ['ar'],
    'ru': ['ru'],
    'pt': ['pt'],
    'it': ['it'],
    'th': ['th'],
    'vi': ['vi'],
    'id': ['id'],
    'tl': ['tl', 'fil'],
    'bn': ['bn'],
    'ur': ['ur'],
  };

  @override
  void initState() {
    super.initState();
    _configuredLangs = List.from(_mlkit.configuredLanguages);
    _tabController = TabController(
      length: _configuredLangs.length,
      vsync: this,
    );
    _loadVoices();
  }

  @override
  void dispose() {
    _tts.stop();
    _tabController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadVoices() async {
    final raw = await _tts.getAvailableVoices();
    final voices = <Map<String, String>>[];
    for (final v in raw) {
      if (v is Map) {
        final name = (v['name'] ?? '').toString();
        final locale = (v['locale'] ?? '').toString();
        if (name.isNotEmpty && locale.isNotEmpty) {
          voices.add({'name': name, 'locale': locale});
        }
      }
    }
    voices.sort((a, b) => a['locale']!.compareTo(b['locale']!));

    // Pre-warm translations for all configured languages in parallel.
    await Future.wait(_configuredLangs.map(_ensurePreview));

    if (mounted) {
      setState(() {
        _allVoices = voices;
        _loading = false;
      });
    }
  }

  /// Translate the base English preview sentence into [langCode] and cache it.
  Future<void> _ensurePreview(String langCode) async {
    if (_previewCache.containsKey(langCode)) return;
    if (langCode == 'en') {
      _previewCache['en'] = _basePreviewEn;
      return;
    }
    try {
      final translated = await _mlkit.translateSingleTo(_basePreviewEn, langCode);
      _previewCache[langCode] = translated.isNotEmpty ? translated : _basePreviewEn;
    } catch (_) {
      _previewCache[langCode] = _basePreviewEn;
    }
  }

  String _previewFor(String langCode) =>
      _previewCache[langCode] ?? _basePreviewEn;

  // ── Voice filtering ───────────────────────────────────────────────────────

  List<Map<String, String>> _voicesForLang(String langCode) {
    final prefixes = _langPrefixes[langCode] ?? [langCode];
    return _allVoices.where((v) {
      final locale = v['locale']!.toLowerCase();
      return prefixes.any((p) => locale.startsWith(p));
    }).toList();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _preview(Map<String, String> voice, String langCode) async {
    if (_previewingVoice == voice['name']) {
      await _tts.stop();
      setState(() => _previewingVoice = null);
      return;
    }

    // Ensure the translation is ready (may already be cached).
    await _ensurePreview(langCode);

    setState(() => _previewingVoice = voice['name']);
    await _tts.speakWithVoice(
      _previewFor(langCode),
      voice['name']!,
      voice['locale']!,
    );
    if (mounted) setState(() => _previewingVoice = null);
  }

  Future<void> _select(Map<String, String> voice, String langCode) async {
    await _tts.stop();
    await _data.setVoiceForLang(langCode, voice['name']!, voice['locale']!);
    if (!mounted) return;
    setState(() {}); // Refresh checkmarks
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_friendlyLangName(langCode)}: ${_tr.t('voice_set')} ${_friendlyName(voice['name']!)}',
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _friendlyName(String raw) {
    return raw
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _friendlyLangName(String langCode) {
    return OnDeviceTranslationService.allSupportedLanguages[langCode] ??
        langCode.toUpperCase();
  }

  String _tabLabel(String langCode) {
    // Use the short UI names from AppTranslations if defined, otherwise full name
    final uiNames = AppTranslations.languageNames;
    return uiNames[langCode] ?? _friendlyLangName(langCode);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_tr.t('voice_choose_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 30),
          onPressed: () {
            _tts.stop();
            Navigator.pop(context);
          },
        ),
        bottom: _loading
            ? null
            : TabBar(
          controller: _tabController,
          isScrollable: _configuredLangs.length > 3,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: AppTheme.fontSM,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: AppTheme.fontSM,
            fontWeight: FontWeight.normal,
          ),
          tabs: _configuredLangs
              .map((code) => Tab(text: _tabLabel(code)))
              .toList(),
        ),
      ),
      body: _loading
          ? _buildLoading()
          : Column(
        children: [
          _buildInfoBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _configuredLangs
                  .map((code) => _buildVoiceListForLang(code))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.record_voice_over_rounded,
                size: 44,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 28),
            const CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 4),
            const SizedBox(height: 24),
            const Text(
              'Loading available voices…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontMD,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Fetching voices from your device\nand preparing translations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontXS,
                color: AppTheme.textMedium,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      color: AppTheme.primary.withOpacity(0.06),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.record_voice_over_rounded,
              color: AppTheme.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _tr.t('voice_preview_hint'),
              style: const TextStyle(
                fontSize: AppTheme.fontXS,
                color: AppTheme.textMedium,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceListForLang(String langCode) {
    final voices = _voicesForLang(langCode);
    final savedVoice = _data.getVoiceNameForLang(langCode);

    if (voices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.voice_over_off_rounded,
                  size: 72, color: AppTheme.primary.withOpacity(0.2)),
              const SizedBox(height: 20),
              Text(
                _tr.t('voice_none'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppTheme.fontSM,
                  color: AppTheme.textMedium,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: voices.length,
      separatorBuilder: (_, __) =>
      const Divider(height: 1, indent: 20, endIndent: 20),
      itemBuilder: (ctx, i) {
        final voice = voices[i];
        final name = voice['name']!;
        final locale = voice['locale']!;
        final isSelected = name == savedVoice;
        final isPreviewing = name == _previewingVoice;

        return Container(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.05)
              : Colors.transparent,
          child: ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary
                    : AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected
                    ? Icons.check_rounded
                    : Icons.record_voice_over_rounded,
                color: isSelected ? Colors.white : AppTheme.primary,
                size: 22,
              ),
            ),
            title: Text(
              _friendlyName(name),
              style: TextStyle(
                fontSize: AppTheme.fontSM,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: AppTheme.textDark,
              ),
            ),
            subtitle: Text(
              locale,
              style: const TextStyle(
                fontSize: AppTheme.fontXS,
                color: AppTheme.textLight,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isPreviewing
                        ? Icons.stop_circle_rounded
                        : Icons.volume_up_rounded,
                    color: isPreviewing ? AppTheme.danger : AppTheme.accent,
                    size: 30,
                  ),
                  tooltip: isPreviewing
                      ? _tr.t('stop_audio')
                      : _tr.t('play_audio'),
                  onPressed: () => _preview(voice, langCode),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: isSelected ? null : () => _select(voice, langCode),
                  style: TextButton.styleFrom(
                    backgroundColor: isSelected
                        ? AppTheme.success.withOpacity(0.12)
                        : AppTheme.primary.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                  child: Text(
                    isSelected
                        ? _tr.t('already_saved')
                        : _tr.t('voice_select'),
                    style: TextStyle(
                      fontSize: AppTheme.fontXS,
                      fontWeight: FontWeight.bold,
                      color:
                      isSelected ? AppTheme.success : AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}