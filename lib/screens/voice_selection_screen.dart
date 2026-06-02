import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/tts_service.dart';
import '../services/data_service.dart';
import '../services/hokkien_tts_service.dart';
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

class _VoiceSelectionScreenState extends State<VoiceSelectionScreen> {
  final TtsService _tts = TtsService();
  final DataService _data = DataService();
  final AppTranslations _tr = AppTranslations();
  final OnDeviceTranslationService _mlkit = OnDeviceTranslationService();

  // The configured languages drive the tabs — reactive, not hardcoded.
  late List<String> _configuredLangs;

  String? _selectedLang;

  // All device voices, loaded once.
  List<Map<String, String>> _allVoices = [];
  bool _loading = true;

  // Which voice is currently being previewed (by name).
  String? _previewingVoice;

  // The currently viewed Chinese dialect sub-tab
  String _viewedDialect = 'mandarin';
  bool _hokkienInitializing = false;
  bool _previewingHokkien = false;

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
    if (_configuredLangs.isNotEmpty) {
      _selectedLang = _configuredLangs.first;
    }
    _viewedDialect = _data.getChineseDialect();
    if (_viewedDialect == 'hokkien') {
      _viewedDialect = 'mandarin'; // Fallback to avoid hidden state
    }
    _loadVoices();
  }

  @override
  void dispose() {
    _tts.stop();
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
      final translated =
          await _mlkit.translateSingleTo(_basePreviewEn, langCode);
      _previewCache[langCode] =
          translated.isNotEmpty ? translated : _basePreviewEn;
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

  /// Returns system voices filtered by Chinese dialect.
  List<Map<String, String>> _voicesForChineseDialect(String dialect) {
    const mandarinPrefixes = ['zh-cn', 'cmn'];
    const cantonesePrefixes = ['zh-hk', 'zh-mo', 'yue'];
    final prefixes =
        dialect == 'cantonese' ? cantonesePrefixes : mandarinPrefixes;
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

  Future<void> _select(
      Map<String, String> voice, String langCode, String friendlyName) async {
    await _tts.stop();
    await _data.setVoiceForLang(langCode, voice['name']!, voice['locale']!);
    if (langCode == 'zh') {
      await _data.setChineseDialect(_viewedDialect);
    }
    if (!mounted) return;
    setState(() {}); // Refresh checkmarks
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_friendlyLangName(langCode)}: ${_tr.t('voice_set')} $friendlyName',
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _getRegionLabel(String locale) {
    final parts = locale.split(RegExp(r'[-_]'));
    if (parts.length > 1) {
      String region = parts[1];
      for (int i = 1; i < parts.length; i++) {
        if (parts[i].length == 2) {
          region = parts[i];
          break;
        }
      }
      region = region.toUpperCase();
      if (region == 'GB') return 'UK';
      return region;
    }
    return parts.first.toUpperCase();
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
            : PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLang,
                        dropdownColor: AppTheme.primary,
                        icon: const Icon(Icons.arrow_drop_down_rounded,
                            color: Colors.white),
                        isExpanded: true,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSM,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        items: _configuredLangs.map((code) {
                          return DropdownMenuItem<String>(
                            value: code,
                            child: Text(_tabLabel(code)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null && mounted) {
                            setState(() => _selectedLang = val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
      ),
      body: _loading
          ? _buildLoading()
          : Column(
              children: [
                _buildInfoBanner(),
                if (_selectedLang == 'zh') _buildChineseDialectTabs(),
                if (_selectedLang != null)
                  Expanded(
                    child: _selectedLang == 'zh'
                        ? _buildChineseVoiceContent()
                        : _buildVoiceListForLang(_selectedLang!),
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
            const CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 4),
            const SizedBox(height: 24),
            Text(
              _tr.t('voice_loading_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontMD,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _tr.t('voice_loading_desc'),
              textAlign: TextAlign.center,
              style: const TextStyle(
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

    final Map<String, int> regionCounts = {};
    final List<String> friendlyNames = [];

    for (var voice in voices) {
      String rLabel = _getRegionLabel(voice['locale'] ?? '');
      int count = (regionCounts[rLabel] ?? 0) + 1;
      regionCounts[rLabel] = count;
      friendlyNames.add('$rLabel ${_tr.t('voice_number')} $count');
    }

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
              friendlyNames[i],
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
                  tooltip:
                      isPreviewing ? _tr.t('stop_audio') : _tr.t('play_audio'),
                  onPressed: () => _preview(voice, langCode),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: isSelected
                      ? null
                      : () => _select(voice, langCode, friendlyNames[i]),
                  style: TextButton.styleFrom(
                    backgroundColor: isSelected
                        ? AppTheme.success.withOpacity(0.12)
                        : AppTheme.primary.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: Text(
                    isSelected ? _tr.t('already_saved') : _tr.t('voice_select'),
                    style: TextStyle(
                      fontSize: AppTheme.fontXS,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.success : AppTheme.primary,
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

  // ── Chinese dialect sub-tabs ───────────────────────────────────────────────

  /// Three-segment toggle: Mandarin | Cantonese | Hokkien
  Widget _buildChineseDialectTabs() {
    final tabs = [
      ('mandarin', 'Mandarin\n普通話'),
      ('cantonese', 'Cantonese\n廣東話'),
      // ('hokkien', 'Hokkien\n閩南語'),
    ];
    return Container(
      color: AppTheme.primary.withOpacity(0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: tabs.map((t) {
          final isActive = _viewedDialect == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (mounted) setState(() => _viewedDialect = t.$1);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? AppTheme.primary
                        : AppTheme.primary.withOpacity(0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  t.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontXS,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? Colors.white : AppTheme.primary,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Routes to the correct content widget based on the selected dialect.
  Widget _buildChineseVoiceContent() {
    if (_viewedDialect == 'hokkien') return _buildHokkienCard();

    // Mandarin or Cantonese — show matching system voices.
    final voices = _voicesForChineseDialect(_viewedDialect);
    final savedVoice = _data.getVoiceNameForLang('zh');
    final savedDialect = _data.getChineseDialect();

    final Map<String, int> regionCounts = {};
    final List<String> friendlyNames = [];
    for (final voice in voices) {
      final rLabel = _getRegionLabel(voice['locale'] ?? '');
      final count = (regionCounts[rLabel] ?? 0) + 1;
      regionCounts[rLabel] = count;
      friendlyNames.add('$rLabel ${_tr.t('voice_number')} $count');
    }

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
        final isSelected = name == savedVoice && _viewedDialect == savedDialect;
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
              friendlyNames[i],
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
                  tooltip:
                      isPreviewing ? _tr.t('stop_audio') : _tr.t('play_audio'),
                  onPressed: () => _preview(voice, 'zh'),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: isSelected
                      ? null
                      : () => _select(voice, 'zh', friendlyNames[i]),
                  style: TextButton.styleFrom(
                    backgroundColor: isSelected
                        ? AppTheme.success.withOpacity(0.12)
                        : AppTheme.primary.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: Text(
                    isSelected ? _tr.t('already_saved') : _tr.t('voice_select'),
                    style: TextStyle(
                      fontSize: AppTheme.fontXS,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.success : AppTheme.primary,
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

  /// Card shown when Hokkien dialect is selected — no system voices,
  /// uses the bundled offline VITS model.
  Widget _buildHokkienCard() {
    final isSelected = _data.getChineseDialect() == 'hokkien';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : AppTheme.primary.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.primary.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.check_rounded
                        : Icons.record_voice_over_rounded,
                    color: isSelected ? Colors.white : AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tr.t('voice_hokkien'),
                        style: const TextStyle(
                          fontSize: AppTheme.fontSM,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tr.t('voice_hokkien_desc'),
                        style: const TextStyle(
                          fontSize: AppTheme.fontXS,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Uses an offline Hokkien (閩南語 / Southern Min) neural TTS '
              'model bundled with the app. Works without an internet connection.',
              style: TextStyle(
                fontSize: AppTheme.fontXS,
                color: AppTheme.textMedium,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(
                      _previewingHokkien
                          ? Icons.stop_circle_rounded
                          : Icons.volume_up_rounded,
                      color: _previewingHokkien
                          ? AppTheme.danger
                          : AppTheme.accent,
                    ),
                    label: Text(
                      _previewingHokkien
                          ? _tr.t('stop_audio')
                          : _tr.t('play_audio'),
                      style: TextStyle(
                        color: _previewingHokkien
                            ? AppTheme.danger
                            : AppTheme.accent,
                      ),
                    ),
                    onPressed: _hokkienInitializing ? null : _previewHokkien,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _previewingHokkien
                            ? AppTheme.danger
                            : AppTheme.accent,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(
                      isSelected ? Icons.check_rounded : Icons.save_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      isSelected
                          ? _tr.t('already_saved')
                          : _tr.t('voice_select'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    onPressed: isSelected ? null : _selectHokkien,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isSelected ? AppTheme.success : AppTheme.primary,
                      disabledBackgroundColor:
                          AppTheme.success.withOpacity(0.7),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            // Loading indicator while model initialises
            if (_hokkienInitializing) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _tr.t('voice_hokkien_loading'),
                    style: const TextStyle(
                      fontSize: AppTheme.fontXS,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Hokkien-specific actions ───────────────────────────────────────────────

  Future<void> _previewHokkien() async {
    if (_previewingHokkien) {
      await HokkienTtsService().stop();
      if (mounted) setState(() => _previewingHokkien = false);
      return;
    }

    final hokkien = HokkienTtsService();
    setState(() {
      _previewingHokkien = true;
      _hokkienInitializing = !hokkien.isReady;
    });

    if (!hokkien.isReady) {
      await hokkien.init();
      if (mounted) setState(() => _hokkienInitializing = false);
    }

    if (!hokkien.isReady) {
      if (mounted) {
        setState(() => _previewingHokkien = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr.t('voice_hokkien_not_ready')),
          ),
        );
      }
      return;
    }

    // Use a short Hokkien preview sentence in POJ (Pe̍h-ōe-jī).
    // The Meta MMS Hokkien model requires romanised input, not Chinese characters.
    const previewText = 'Lí hó! Che sī góa ê siaⁿ-im. Hi-bāng lí ē huān-hí.';
    await hokkien.speak(previewText);
    if (mounted) setState(() => _previewingHokkien = false);
  }

  Future<void> _selectHokkien() async {
    await _data.setChineseDialect('hokkien');
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_friendlyLangName('zh')}: ${_tr.t('voice_dialect_saved')}',
        ),
      ),
    );
  }
}
