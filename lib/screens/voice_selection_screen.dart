import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/tts_service.dart';
import '../services/data_service.dart';
import '../services/translation_service.dart';

/// VoiceSelectionScreen — lets the user pick their preferred TTS voice
/// from the voices installed on the device, filtered by language.
class VoiceSelectionScreen extends StatefulWidget {
  const VoiceSelectionScreen({super.key});

  @override
  State<VoiceSelectionScreen> createState() => _VoiceSelectionScreenState();
}

class _VoiceSelectionScreenState extends State<VoiceSelectionScreen> {
  final TtsService _tts = TtsService();
  final DataService _data = DataService();
  final AppTranslations _tr = AppTranslations();

  List<Map<String, String>> _allVoices = [];
  String? _filterLang;
  bool _loading = true;
  String? _previewingVoice;

  static const Map<String, List<String>> _langPrefixes = {
    'en': ['en'],
    'zh': ['zh', 'cmn', 'yue'],
    'ms': ['ms', 'id'],
    'ta': ['ta'],
  };

  // Tab labels use the language code; friendly name from translations
  static const List<String?> _tabLangs = ['en', 'zh', 'ms', 'ta', null];

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

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
    if (mounted) {
      setState(() {
        _allVoices = voices;
        _loading = false;
      });
    }
  }

  List<Map<String, String>> get _filteredVoices {
    if (_filterLang == null) return _allVoices;
    final prefixes = _langPrefixes[_filterLang!] ?? [_filterLang!];
    return _allVoices.where((v) {
      final locale = v['locale']!.toLowerCase();
      return prefixes.any((p) => locale.startsWith(p));
    }).toList();
  }

  String _langForVoice(Map<String, String> voice) {
    final locale = voice['locale']!.toLowerCase();
    for (final entry in _langPrefixes.entries) {
      if (entry.value.any((p) => locale.startsWith(p))) return entry.key;
    }
    return 'other';
  }

  String _previewSentence(Map<String, String> voice) {
    // Use the translated preview sentence for the voice's language
    return _tr.t('voice_preview_en');
  }

  Future<void> _preview(Map<String, String> voice) async {
    if (_previewingVoice == voice['name']) {
      await _tts.stop();
      setState(() => _previewingVoice = null);
      return;
    }
    setState(() => _previewingVoice = voice['name']);
    await _tts.speakWithVoice(
      _previewSentence(voice),
      voice['name']!,
      voice['locale']!,
    );
    if (mounted) setState(() => _previewingVoice = null);
  }

  Future<void> _select(Map<String, String> voice) async {
    await _tts.stop();
    await _data.setPreferredVoice(voice['name']!, voice['locale']!);
    await _tts.applyPreferredVoice();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_tr.t('voice_set')} ${_friendlyName(voice['name']!)}'),
      ),
    );
    Navigator.pop(context);
  }

  String _friendlyName(String raw) {
    return raw
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _tabLabel(String? lang) {
    if (lang == null) return _tr.t('voice_tab_all');
    // Use the existing language name keys from translations
    switch (lang) {
      case 'en': return _tr.t('english');
      case 'zh': return _tr.t('chinese');
      case 'ms': return _tr.t('malay');
      case 'ta': return _tr.t('tamil');
      default: return lang.toUpperCase();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedVoice = _data.getPreferredVoiceName();

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
      ),
      body: _loading
          ? _buildLoading()
          : Column(
              children: [
                _buildInfoBanner(),
                _buildLangTabs(),
                const Divider(height: 1),
                Expanded(child: _buildVoiceList(savedVoice)),
              ],
            ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 4),
          const SizedBox(height: 20),
          Text(
            _tr.t('processing'),
            style: const TextStyle(
                fontSize: AppTheme.fontSM, color: AppTheme.textMedium),
          ),
        ],
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

  Widget _buildLangTabs() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _tabLangs.map((lang) {
            final isSelected = _filterLang == lang;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filterLang = lang),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _tabLabel(lang),
                    style: TextStyle(
                      fontSize: AppTheme.fontXS,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppTheme.textMedium,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildVoiceList(String? savedVoice) {
    final voices = _filteredVoices;

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
                  onPressed: () => _preview(voice),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: isSelected ? null : () => _select(voice),
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
}
