import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/qr_saved_text.dart';
import '../services/data_service.dart';
import '../services/groq_translation_service.dart';
import '../services/mlkit_translation_service.dart';
import '../services/premium_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import '../widgets/font_size_slider.dart';
import '../widgets/language_selector.dart';
import 'voice_selection_screen.dart';

/// Displays the AI-generated summary of a QR-scanned URL.
///
/// Mirrors ResultScreen: language selector, TTS, translating placeholder,
/// collapsible bottom panel with play/stop/mute/voice buttons, and Save.
class QrResultScreen extends StatefulWidget {
  final QrSavedText qrScan;
  final bool isNew;

  /// Language to display when the screen first opens.
  final String initialLang;

  const QrResultScreen({
    super.key,
    required this.qrScan,
    this.isNew = true,
    this.initialLang = 'en',
  });

  @override
  State<QrResultScreen> createState() => _QrResultScreenState();
}

class _QrResultScreenState extends State<QrResultScreen> {
  final DataService _dataService = DataService();
  final AppTranslations _tr = AppTranslations();
  final TtsService _tts = TtsService();
  final OnDeviceTranslationService _mlkit = OnDeviceTranslationService();
  final GroqTranslationService _groqTranslation = GroqTranslationService();
  final PremiumService _premium = PremiumService();

  late String _currentLang;
  late double _fontSize;
  bool _saved = false;
  bool _translating = false;
  bool _panelExpanded = true;

  // TTS
  bool _playing = false;
  int _highlightedLine = -1;
  List<_Segment> _segments = [];
  bool _stopRequested = false;
  bool _muted = false;
  bool _replayCurrent = false;

  final ScrollController _scrollController = ScrollController();

  // Connectivity
  bool _isOffline = false;
  bool _wasTranslatedOffline = false;
  bool _retranslatedOnline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _currentLang = widget.initialLang;
    _fontSize = _dataService.getFontSize();
    _saved = !widget.isNew;
    _buildSegments();
    _muted = _dataService.getStartMuted();
    _initConnectivity();
    if (_dataService.getAutoRead()) _checkAutoRead();
  }

  // ── Connectivity ─────────────────────────────────────────────────────────

  Future<void> _initConnectivity() async {
    final initial = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isOffline = _hasNoInternet(initial));
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  bool _hasNoInternet(List<ConnectivityResult> r) =>
      r.isEmpty || r.every((x) => x == ConnectivityResult.none);

  void _onConnectivityChanged(List<ConnectivityResult> r) {
    if (!mounted) return;
    final wasOffline = _isOffline;
    setState(() => _isOffline = _hasNoInternet(r));
    if (wasOffline && !_isOffline && _wasTranslatedOffline && !_retranslatedOnline) {
      _retranslateOnline();
    }
  }

  Future<void> _retranslateOnline() async {
    if (!_premium.isPremium || _retranslatedOnline || _currentLang == 'en') return;
    setState(() => _translating = true);
    try {
      final translated = await _groqTranslation.translateSmart(
          widget.qrScan.summary, _currentLang);
      if (translated.isNotEmpty && translated != widget.qrScan.summary) {
        widget.qrScan.translations[_currentLang] = translated;
        _retranslatedOnline = true;
        _wasTranslatedOffline = false;
        if (_saved) await _dataService.updateQrScan(widget.qrScan);
        if (mounted) setState(() { _buildSegments(); _translating = false; });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _translating = false);
  }

  Future<void> _checkAutoRead() async {
    while (_translating) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }
    if (!_playing && mounted) await _startReading();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _tts.stop();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Text ─────────────────────────────────────────────────────────────────

  String get _displayText => widget.qrScan.forLanguage(_currentLang);

  void _buildSegments() {
    _segments = [];
    final allLines = _displayText.split('\n');
    for (int li = 0; li < allLines.length; li++) {
      final line = allLines[li].trim();
      if (line.isEmpty) continue;
      final sentences =
          line.split(RegExp(r'(?<=[.!?。！？])\s+'));
      for (final s in sentences) {
        final t = s.trim();
        if (t.isNotEmpty) _segments.add(_Segment(text: t, origLineIdx: li));
      }
    }
  }

  // ── TTS ───────────────────────────────────────────────────────────────────

  int _estimateDurationMs(String text, String lang) {
    if (text.isEmpty) return 0;
    return lang == 'zh' ? text.length * 200 : text.length * 65;
  }

  Future<void> _startReading() async {
    if (_segments.isEmpty) return;
    setState(() { _playing = true; _stopRequested = false; _highlightedLine = 0; });
    await _tts.setMuted(_muted);
    for (int i = 0; i < _segments.length; i++) {
      if (_stopRequested) break;
      setState(() => _highlightedLine = i);
      _scrollToSegment(i);
      _replayCurrent = false;
      if (_muted) {
        final fakeMs = _estimateDurationMs(_segments[i].text, _currentLang);
        int elapsed = 0;
        while (elapsed < fakeMs) {
          await Future.delayed(const Duration(milliseconds: 50));
          elapsed += 50;
          if (_stopRequested || _replayCurrent) break;
        }
      } else {
        await _tts.speakAndWait(_segments[i].text, langCode: _currentLang);
      }
      if (_replayCurrent) { i--; continue; }
      if (_stopRequested) break;
    }
    if (mounted) setState(() { _playing = false; _highlightedLine = -1; });
  }

  Future<void> _stopReading() async {
    _stopRequested = true;
    await _tts.stop();
    if (mounted) setState(() { _playing = false; _highlightedLine = -1; });
  }

  void _scrollToSegment(int index) {
    if (index < 0 || index >= _segments.length || !_scrollController.hasClients) return;
    final fraction = _segments.length > 1 ? index / (_segments.length - 1) : 0.0;
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      (max * fraction).clamp(0.0, max),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  // ── Language ──────────────────────────────────────────────────────────────

  Future<void> _changeLanguage(String langCode) async {
    await _stopReading();
    await _tr.load(langCode);

    final existing = widget.qrScan.translations[langCode];
    final needsTranslation = existing == null ||
        existing.isEmpty ||
        (langCode != 'en' && existing == widget.qrScan.summary);

    if (needsTranslation) {
      setState(() => _translating = true);
      try {
        if (_premium.isPremium) {
          if (_isOffline) {
            final t = await _mlkit.translateSingleTo(widget.qrScan.summary, langCode);
            if (t.isNotEmpty) {
              widget.qrScan.translations[langCode] = t;
              _wasTranslatedOffline = true;
              _retranslatedOnline = false;
              if (_saved) await _dataService.updateQrScan(widget.qrScan);
            }
          } else {
            await _ensurePremiumTranslation(langCode);
          }
        } else {
          final t = await _mlkit.translateSingleTo(widget.qrScan.summary, langCode);
          if (t.isNotEmpty) {
            widget.qrScan.translations[langCode] = t;
            if (_saved) await _dataService.updateQrScan(widget.qrScan);
          }
        }
      } catch (_) {
      } finally {
        if (mounted) setState(() => _translating = false);
      }
    }

    setState(() { _currentLang = langCode; _buildSegments(); });
  }

  Future<void> _ensurePremiumTranslation(String langCode) async {
    final existing = widget.qrScan.translations[langCode];
    if (existing != null && existing.isNotEmpty) return;
    if (!mounted) return;

    if (_isOffline) {
      setState(() => _translating = true);
      try {
        final t = await _mlkit.translateSingleTo(widget.qrScan.summary, langCode);
        if (t.isNotEmpty) {
          widget.qrScan.translations[langCode] = t;
          _wasTranslatedOffline = true;
          _retranslatedOnline = false;
          if (_saved) await _dataService.updateQrScan(widget.qrScan);
        }
      } catch (_) {
      } finally {
        if (mounted) setState(() { _translating = false; _buildSegments(); });
      }
      return;
    }

    setState(() => _translating = true);
    try {
      final t = await _groqTranslation.translateSmart(widget.qrScan.summary, langCode);
      if (t.isNotEmpty) {
        widget.qrScan.translations[langCode] = t;
        if (_saved) await _dataService.updateQrScan(widget.qrScan);
      }
    } catch (_) {
      try {
        final fallback = await _mlkit.translateSingleTo(widget.qrScan.summary, langCode);
        if (fallback.isNotEmpty) {
          widget.qrScan.translations[langCode] = fallback;
          _wasTranslatedOffline = true;
          _retranslatedOnline = false;
          if (_saved) await _dataService.updateQrScan(widget.qrScan);
        }
      } catch (_) {}
    } finally {
      if (mounted) setState(() { _translating = false; _buildSegments(); });
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    await _dataService.saveQrScan(widget.qrScan);
    setState(() => _saved = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr.t('qr_saved_success'))),
    );
  }

  Future<void> _openVoiceSelection() async {
    await _stopReading();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VoiceSelectionScreen()),
    );
    await _tts.applyPreferredVoice();
    if (mounted) setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _tr.t('qr_summary_title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 30),
          onPressed: () {
            _stopReading();
            Navigator.pop(context);
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: AppTheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: LanguageSelector(
              currentLang: _currentLang,
              onChanged: _changeLanguage,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Font size slider ───────────────────────────────────────────────
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: FontSizeSlider(
              onChanged: (v) => setState(() => _fontSize = v),
            ),
          ),
          const Divider(height: 1),

          // ── Scrollable summary text (or translating spinner) ───────────────
          Expanded(
            child: _translating
                ? _buildTranslatingPlaceholder()
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: SelectableText.rich(
                      _buildFullSpan(),
                      style: TextStyle(
                        fontSize: AppTheme.fontMD * _fontSize,
                        color: AppTheme.textDark.withOpacity(0.80),
                        height: 1.7,
                      ),
                    ),
                  ),
          ),

          // ── Sticky bottom panel ────────────────────────────────────────────
          _buildStickyPanel(),
        ],
      ),
    );
  }

  Widget _buildTranslatingPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 4),
          const SizedBox(height: 20),
          Text(
            _premium.isPremium ? _tr.t('translating_ai') : _tr.t('home_translating'),
            style: const TextStyle(
              fontSize: AppTheme.fontMD,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _buildFullSpan() {
    final spans = <InlineSpan>[];
    for (int si = 0; si < _segments.length; si++) {
      final seg = _segments[si];
      final isHighlighted = si == _highlightedLine;
      final isFirstInLine =
          si == 0 || _segments[si - 1].origLineIdx != seg.origLineIdx;
      if (si > 0 && isFirstInLine) {
        spans.add(const TextSpan(text: '\n\n'));
      } else if (si > 0 && !isFirstInLine) {
        spans.add(const TextSpan(text: ' '));
      }
      spans.add(TextSpan(
        text: seg.text,
        style: TextStyle(
          fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
          color: isHighlighted ? AppTheme.textDark : null,
          backgroundColor: isHighlighted
              ? AppTheme.accent.withOpacity(0.22)
              : Colors.transparent,
        ),
      ));
    }
    return TextSpan(children: spans);
  }

  Widget _buildStickyPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _panelExpanded = !_panelExpanded),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: AnimatedRotation(
                  turns: _panelExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 40,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _panelExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAudioRow(),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(widget.qrScan.url),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 28),
                    label: Text(_tr.t('qr_open_webpage')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      side: const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                  if (!_saved) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded, size: 28),
                      label: Text(_tr.t('qr_save_summary')),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                ],
              ),
            ),
            secondChild: SizedBox(
              height: MediaQuery.of(context).padding.bottom + 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioRow() {
    final voiceName = _dataService.getPreferredVoiceName();
    final hasCustomVoice = voiceName != null;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _playing ? _stopReading : _startReading,
            style: ElevatedButton.styleFrom(
              backgroundColor: _playing ? AppTheme.danger : AppTheme.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 68),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: _playing ? 6 : 2,
            ),
            icon: Icon(
              _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 32,
            ),
            label: Text(
              _playing ? _tr.t('stop_audio') : _tr.t('play_audio'),
              style: const TextStyle(fontSize: AppTheme.fontMD, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Mute toggle
        Tooltip(
          message: _muted ? _tr.t('unmute') : _tr.t('mute'),
          child: InkWell(
            onTap: () async {
              setState(() => _muted = !_muted);
              await _tts.setMuted(_muted);
              if (_playing) {
                _replayCurrent = true;
                if (_muted) await _tts.interruptCurrent();
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 64,
              height: 68,
              decoration: BoxDecoration(
                color: _muted ? AppTheme.primary.withOpacity(0.10) : AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _muted ? AppTheme.primary : AppTheme.cardBorder,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: _muted ? AppTheme.primary : AppTheme.textLight,
                    size: 26,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _muted ? _tr.t('muted') : _tr.t('mute'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTheme.fontXS,
                      color: _muted ? AppTheme.primary : AppTheme.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Voice selector
        Tooltip(
          message: hasCustomVoice ? _tr.t('voice_btn') : _tr.t('voice_btn'),
          child: InkWell(
            onTap: _openVoiceSelection,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 64,
              height: 68,
              decoration: BoxDecoration(
                color: hasCustomVoice
                    ? AppTheme.primary.withOpacity(0.10)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasCustomVoice ? AppTheme.primary : AppTheme.cardBorder,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.record_voice_over_rounded,
                    color: hasCustomVoice ? AppTheme.primary : AppTheme.textLight,
                    size: 26,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _tr.t('voice_btn'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTheme.fontXS,
                      color: hasCustomVoice ? AppTheme.primary : AppTheme.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Segment {
  final String text;
  final int origLineIdx;
  const _Segment({required this.text, required this.origLineIdx});
}
