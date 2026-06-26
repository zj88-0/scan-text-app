import 'dart:async';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/saved_text.dart';
import '../services/data_service.dart';
import '../services/groq_translation_service.dart';
import '../services/mlkit_translation_service.dart';
import '../services/premium_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import '../widgets/font_size_slider.dart';
import '../widgets/language_selector.dart';
import 'voice_selection_screen.dart';

class ResultScreen extends StatefulWidget {
  final SavedText savedText;
  final String langCode;
  final bool isNew;

  // kept for API compatibility — no longer displayed
  final ({int originalKb, int? compressedKb, Uint8List bytes})? imageSizeInfo;

  const ResultScreen({
    super.key,
    required this.savedText,
    required this.langCode,
    required this.isNew,
    this.imageSizeInfo,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
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

  // Controls whether the bottom action panel is expanded or collapsed
  bool _panelExpanded = true;

  // ── TTS highlighting state ────────────────────────────────────────────────
  bool _playing = false;
  int _highlightedLine = -1;

  List<_Segment> _segments = [];
  bool _stopRequested = false;

  final ScrollController _scrollController = ScrollController();
  // Single key on the one SelectableText that holds all the text
  final GlobalKey _fullTextKey = GlobalKey();

  bool _muted = false;
  bool _replayCurrent = false;

  // ── Connectivity / offline-banner state ───────────────────────────────────
  /// True when the device currently has no internet.
  bool _isOffline = false;
  /// True when the current displayed translation was done offline (MLKit)
  /// for a premium user who would normally get Groq AI translation.
  bool _wasTranslatedOffline = false;
  /// True once we have successfully re-translated via Groq after reconnecting.
  bool _retranslatedOnline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _currentLang = widget.langCode;
    _fontSize = _dataService.getFontSize();
    _saved = !widget.isNew;
    _buildSegments();

    if (_premium.isPremium && widget.isNew && _currentLang != 'en') {
      _ensurePremiumTranslation(_currentLang);
    }

    _muted = _dataService.getStartMuted();
    _checkAutoRead();
    _initConnectivity();
  }

  // ── Connectivity helpers ───────────────────────────────────────────────────

  Future<void> _initConnectivity() async {
    // Check initial state.
    final initial = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOffline = _hasNoInternet(initial));
    }
    // Listen for changes.
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
  }

  bool _hasNoInternet(List<ConnectivityResult> results) {
    return results.isEmpty || results.every((r) => r == ConnectivityResult.none);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final nowOffline = _hasNoInternet(results);
    if (!mounted) return;
    final wasOffline = _isOffline;
    setState(() => _isOffline = nowOffline);

    // Came back online: retranslate if we had used MLKit as a fallback.
    if (wasOffline && !nowOffline && _wasTranslatedOffline && !_retranslatedOnline) {
      _retranslateOnline();
    }
  }

  /// Silently re-translates using Groq AI after reconnecting.
  Future<void> _retranslateOnline() async {
    if (!_premium.isPremium) return;
    if (_retranslatedOnline) return;
    final langCode = _currentLang;
    if (langCode == 'en') return;

    setState(() => _translating = true);
    try {
      final translated = await _groqTranslation.translateSmart(
        widget.savedText.originalText,
        langCode,
      );
      if (translated.isNotEmpty && translated != widget.savedText.originalText) {
        widget.savedText.translations[langCode] = translated;
        _retranslatedOnline = true;
        _wasTranslatedOffline = false;
        if (_saved) await _dataService.updateText(widget.savedText);
        if (mounted) {
          setState(() {
            _buildSegments();
            _translating = false;
          });
        }
        return;
      }
    } catch (_) {
      // Silently fall through — keep the offline translation.
    }
    if (mounted) setState(() => _translating = false);
  }

  Future<void> _checkAutoRead() async {
    if (_dataService.getAutoRead()) {
      while (_translating) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
      }
      if (!_playing && mounted) {
        await _startReading();
      }
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _tts.stop();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Text preparation ──────────────────────────────────────────────────────

  String get _displayText => widget.savedText.forLanguage(_currentLang);

  void _buildSegments() {
    _segments = [];
    final allLines = _displayText.split('\n');

    for (int lineIdx = 0; lineIdx < allLines.length; lineIdx++) {
      final line = allLines[lineIdx].trim();
      if (line.isEmpty) continue;

      final sentencePattern = RegExp(r'(?<=[.!?。！？])\s+');
      final sentences = line.split(sentencePattern);

      for (final sentence in sentences) {
        final trimmed = sentence.trim();
        if (trimmed.isNotEmpty) {
          _segments.add(_Segment(text: trimmed, origLineIdx: lineIdx));
        }
      }
    }


  }

  // ── TTS control ───────────────────────────────────────────────────────────

  int _estimateDurationMs(String text, String langCode) {
    if (text.isEmpty) return 0;
    if (langCode == 'zh') {
      return text.length * 200; // ~5 chars per sec
    }
    return text.length * 65; // ~15 chars per sec
  }

  Future<void> _startReading() async {
    if (_segments.isEmpty) return;
    setState(() {
      _playing = true;
      _stopRequested = false;
      _highlightedLine = 0;
    });

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
      
      if (_replayCurrent) {
        i--; // Replay this segment instantly with the new volume/state
        continue;
      }
      
      if (_stopRequested) break;
    }

    if (mounted) {
      setState(() {
        _playing = false;
        _highlightedLine = -1;
      });
    }
  }

  Future<void> _stopReading() async {
    _stopRequested = true;
    await _tts.stop();
    if (mounted) {
      setState(() {
        _playing = false;
        _highlightedLine = -1;
      });
    }
  }

  void _scrollToSegment(int index) {
    if (index < 0 || index >= _segments.length || !_scrollController.hasClients) return;
    // Estimate the scroll offset based on how far through the segments we are.
    final fraction = _segments.length > 1 ? index / (_segments.length - 1) : 0.0;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final target = (maxExtent * fraction).clamp(0.0, maxExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  // ── Language switching ────────────────────────────────────────────────────

  Future<void> _changeLanguage(String langCode) async {
    await _stopReading();
    await _tr.load(langCode);

    final existing = widget.savedText.translations[langCode];
    // If the translation is missing, OR if a previous translation failed and cached the original English text.
    final needsTranslation = existing == null || 
                             existing.isEmpty || 
                             (langCode != 'en' && existing == widget.savedText.originalText);

    if (needsTranslation) {
      setState(() => _translating = true);
      try {
        if (_premium.isPremium) {
          if (_isOffline) {
            // Offline fallback: use MLKit and mark that we need to retranslate later.
            final translated = await _mlkit.translateSingleTo(
              widget.savedText.originalText,
              langCode,
            );
            if (translated.isNotEmpty) {
              widget.savedText.translations[langCode] = translated;
              _wasTranslatedOffline = true;
              _retranslatedOnline = false;
              if (_saved) await _dataService.updateText(widget.savedText);
            }
            if (mounted) setState(() => _translating = false);
          } else {
            await _ensurePremiumTranslation(langCode);
          }
        } else {
          final translated = await _mlkit.translateSingleTo(
            widget.savedText.originalText,
            langCode,
          );
          if (translated.isNotEmpty) {
            widget.savedText.translations[langCode] = translated;
            if (_saved) await _dataService.updateText(widget.savedText);
          }
        }
      } catch (_) {
        // Silently fall back
      } finally {
        if (mounted) setState(() => _translating = false);
      }
    }

    setState(() {
      _currentLang = langCode;
      _buildSegments();
    });
  }

  Future<void> _ensurePremiumTranslation(String langCode) async {
    final existing = widget.savedText.translations[langCode];
    if (existing != null && existing.isNotEmpty) return;

    if (!mounted) return;

    // If offline, fall back to MLKit and flag for later retranslation.
    if (_isOffline) {
      setState(() => _translating = true);
      try {
        final translated = await _mlkit.translateSingleTo(
          widget.savedText.originalText,
          langCode,
        );
        if (translated.isNotEmpty) {
          widget.savedText.translations[langCode] = translated;
          _wasTranslatedOffline = true;
          _retranslatedOnline = false;
          if (_saved) await _dataService.updateText(widget.savedText);
        }
      } catch (_) {
        // Silently fall back
      } finally {
        if (mounted) setState(() { _translating = false; _buildSegments(); });
      }
      return;
    }

    setState(() => _translating = true);
    try {
      final translated = await _groqTranslation.translateSmart(
        widget.savedText.originalText,
        langCode,
      );
      if (translated.isNotEmpty) {
        widget.savedText.translations[langCode] = translated;
        if (_saved) await _dataService.updateText(widget.savedText);
      }
    } catch (_) {
      // Groq failed — fall back to MLKit silently.
      try {
        final fallback = await _mlkit.translateSingleTo(
          widget.savedText.originalText,
          langCode,
        );
        if (fallback.isNotEmpty) {
          widget.savedText.translations[langCode] = fallback;
          _wasTranslatedOffline = true;
          _retranslatedOnline = false;
          if (_saved) await _dataService.updateText(widget.savedText);
        }
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          _translating = false;
          _buildSegments();
        });
      }
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            _tr.t('disclaimer_title'),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.danger,
            ),
          ),
          content: Text(
            _tr.t('disclaimer_body'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: AppTheme.textDark,
              height: 1.5,
            ),
          ),
          actionsPadding: const EdgeInsets.all(16),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(minimumSize: const Size(100, 52)),
              child: Text(_tr.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(100, 52),
              ),
              child: Text(_tr.t('save')),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _dataService.saveText(widget.savedText);
      setState(() => _saved = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr.t('saved_success'))),
      );
      Navigator.pop(context, true);
    }
  }

  // ── Voice selection ───────────────────────────────────────────────────────

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
        title: Text(_tr.t('result_title'), maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 30),
          onPressed: () {
            _stopReading();
            Navigator.pop(context, _saved);
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
          // ── Offline banner (premium only, when MLKit was used as fallback) ─
          if (_isOffline && _premium.isPremium && _currentLang != 'en')
            _buildOfflineBanner(),

          // ── Font size slider always at top ────────────────────────────────
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: FontSizeSlider(
              onChanged: (v) => setState(() => _fontSize = v),
            ),
          ),
          const Divider(height: 1),

          // ── Main scrollable text area ─────────────────────────────────────
          Expanded(
            child: _translating
                ? _buildTranslatingPlaceholder()
                : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: SelectableText.rich(
                _buildFullSpan(),
                key: _fullTextKey,
                style: TextStyle(
                  fontSize: AppTheme.fontMD * _fontSize,
                  color: AppTheme.textDark.withOpacity(0.75),
                  height: 1.7,
                ),
              ),
            ),
          ),

          // ── Sticky bottom panel ───────────────────────────────────────────
          _buildStickyPanel(),
        ],
      ),
    );
  }

  // ── Offline banner ────────────────────────────────────────────────────────

  Widget _buildOfflineBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      color: const Color(0xFFF59E0B).withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tr.t('result_offline_banner'),
              style: const TextStyle(
                fontSize: AppTheme.fontXS,
                color: Color(0xFFB45309),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sticky bottom panel with collapse arrow ───────────────────────────────

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
          // ── Collapse / expand arrow ───────────────────────────────────────
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

          // ── Expandable content ────────────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _panelExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Audio row ─────────────────────────────────────────────
                  _buildAudioRow(),

                  // ── Save button (only if not yet saved) ───────────────────
                  if (!_saved) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded, size: 28),
                      label: Text(_tr.t('save')),
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

  Widget _buildTranslatingPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              color: AppTheme.accent, strokeWidth: 4),
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

  // ── Build one TextSpan tree for the entire text ──────────────────────────
  // All segments live in a single SelectableText.rich so the user can select
  // across paragraph boundaries. The highlighted segment gets a background
  // colour and bold weight; everything else is plain.

  TextSpan _buildFullSpan() {
    final allSpans = <InlineSpan>[];

    for (int si = 0; si < _segments.length; si++) {
      final seg = _segments[si];
      final isHighlighted = si == _highlightedLine;

      // Add a blank line before a segment that starts a new source line
      // (except for the very first segment).
      final isFirstInLine = si == 0 ||
          _segments[si - 1].origLineIdx != seg.origLineIdx;
      if (si > 0 && isFirstInLine) {
        allSpans.add(const TextSpan(text: '\n\n'));
      } else if (si > 0 && !isFirstInLine) {
        // Space between sentences on the same line
        allSpans.add(const TextSpan(text: ' '));
      }

      allSpans.add(TextSpan(
        text: seg.text,
        style: TextStyle(
          fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
          color: isHighlighted ? AppTheme.textDark : null, // null = inherit
          backgroundColor: isHighlighted
              ? AppTheme.accent.withOpacity(0.22)
              : Colors.transparent,
        ),
      ));
    }

    return TextSpan(children: allSpans);
  }

  // ── Audio row ─────────────────────────────────────────────────────────────

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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: _playing ? 6 : 2,
            ),
            icon: Icon(
              _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 32,
            ),
            label: Text(
              _playing ? _tr.t('stop_audio') : _tr.t('play_audio'),
              style: const TextStyle(
                  fontSize: AppTheme.fontMD, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: _muted ? _tr.t('unmute') : _tr.t('mute'),
          child: InkWell(
            onTap: () async {
              setState(() => _muted = !_muted);
              await _tts.setMuted(_muted);
              if (_playing) {
                if (_muted) {
                  // Muting: stop the active engine so the loop instantly replays into the fake timer
                  // Set _replayCurrent to true BEFORE interrupting, because interrupt will unblock the loop instantly!
                  _replayCurrent = true;
                  await _tts.interruptCurrent();
                } else {
                  // Unmuting: the fake timer is currently running, so we break it to replay aloud
                  _replayCurrent = true;
                }
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 64,
              height: 68,
              decoration: BoxDecoration(
                color: _muted
                    ? AppTheme.primary.withOpacity(0.10)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _muted
                      ? AppTheme.primary
                      : AppTheme.cardBorder,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: _muted
                        ? AppTheme.primary
                        : AppTheme.textLight,
                    size: 26,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _muted ? _tr.t('muted') : _tr.t('mute'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTheme.fontXS,
                      color: _muted
                          ? AppTheme.primary
                          : AppTheme.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: hasCustomVoice ? 'Change voice' : 'Select voice',
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
                  color: hasCustomVoice
                      ? AppTheme.primary
                      : AppTheme.cardBorder,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.record_voice_over_rounded,
                    color: hasCustomVoice
                        ? AppTheme.primary
                        : AppTheme.textLight,
                    size: 26,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _tr.t('voice_btn'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTheme.fontXS,
                      color: hasCustomVoice
                          ? AppTheme.primary
                          : AppTheme.textLight,
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

// ── Data class ────────────────────────────────────────────────────────────────

class _Segment {
  final String text;
  final int origLineIdx;
  const _Segment({required this.text, required this.origLineIdx});
}