import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/saved_text.dart';
import '../services/data_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import '../widgets/font_size_slider.dart';
import '../widgets/language_selector.dart';
import 'voice_selection_screen.dart';

class ResultScreen extends StatefulWidget {
  final SavedText savedText;
  final String langCode;
  final bool isNew;

  // ── [IMAGE SIZE DEBUG] Added imageSizeInfo optional parameter ───────────────
  // To remove: delete this one line
  final ({int originalKb, int? compressedKb, Uint8List bytes})? imageSizeInfo;
  // ── [IMAGE SIZE DEBUG END] ──────────────────────────────────────────────────

  const ResultScreen({
    super.key,
    required this.savedText,
    required this.langCode,
    required this.isNew,
    // ── [IMAGE SIZE DEBUG] Added imageSizeInfo to constructor ──────────────────
    // To remove: delete this one line
    this.imageSizeInfo,
    // ── [IMAGE SIZE DEBUG END] ─────────────────────────────────────────────────
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final DataService _dataService = DataService();
  final AppTranslations _tr = AppTranslations();
  final TtsService _tts = TtsService();

  late String _currentLang;
  late double _fontSize;
  bool _saved = false;

  // ── TTS highlighting state ────────────────────────────────────────────────
  bool _playing = false;
  int _highlightedLine = -1;

  List<_Segment> _segments = [];
  bool _stopRequested = false;

  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _segmentKeys = [];

  @override
  void initState() {
    super.initState();
    _currentLang = widget.langCode;
    _fontSize = _dataService.getFontSize();
    _saved = !widget.isNew;
    _buildSegments();
  }

  @override
  void dispose() {
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

    _segmentKeys
      ..clear()
      ..addAll(List.generate(_segments.length, (_) => GlobalKey()));
  }

  // ── TTS control ───────────────────────────────────────────────────────────

  Future<void> _startReading() async {
    if (_segments.isEmpty) return;
    setState(() {
      _playing = true;
      _stopRequested = false;
      _highlightedLine = 0;
    });

    for (int i = 0; i < _segments.length; i++) {
      if (_stopRequested) break;
      setState(() => _highlightedLine = i);
      _scrollToSegment(i);
      await _tts.speakAndWait(_segments[i].text, langCode: _currentLang);
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
    if (index < 0 || index >= _segmentKeys.length) return;
    final key = _segmentKeys[index];
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.25,
    );
  }

  Future<void> _changeLanguage(String langCode) async {
    await _stopReading();
    await _tr.load(langCode);
    setState(() {
      _currentLang = langCode;
      _buildSegments();
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    await _dataService.saveText(widget.savedText);
    setState(() => _saved = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr.t('saved_success'))),
    );
    Navigator.pop(context, true);
  }

  // ── Voice selection ───────────────────────────────────────────────────────

  Future<void> _openVoiceSelection() async {
    await _stopReading();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VoiceSelectionScreen()),
    );
    // Re-apply voice in case it changed
    await _tts.applyPreferredVoice();
    if (mounted) setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_tr.t('result_title')),
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
          // Font size slider
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: FontSizeSlider(
              onChanged: (v) => setState(() => _fontSize = v),
            ),
          ),
          const Divider(height: 1),

          // ── [IMAGE SIZE DEBUG] Image size info banner ────────────────────────
          // To remove: delete from here...
          if (widget.imageSizeInfo != null) _buildImageSizeBanner(),
          // ...to here (1 line total, plus the _buildImageSizeBanner method below)
          // ── [IMAGE SIZE DEBUG END] ────────────────────────────────────────────

          // Highlighted text area
          Expanded(
            child: _segments.isEmpty
                ? Center(
              child: Text(
                '—',
                style: TextStyle(
                  fontSize: AppTheme.fontMD * _fontSize,
                  color: AppTheme.textLight,
                ),
              ),
            )
                : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildHighlightedSegments(),
              ),
            ),
          ),

          // Bottom controls
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAudioRow(),
                const SizedBox(height: 14),
                if (widget.isNew && !_saved)
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.bookmark_add_rounded, size: 28),
                    label: Text(_tr.t('save')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      minimumSize: const Size(double.infinity, 64),
                    ),
                  )
                else if (_saved)
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.bookmark_rounded, size: 26),
                    label: Text(_tr.t('already_saved')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── [IMAGE SIZE DEBUG] Banner widget showing original/compressed sizes ───────
  // To remove: delete this entire method (_buildImageSizeBanner)
  Widget _buildImageSizeBanner() {
    final info = widget.imageSizeInfo!;
    final wasCompressed = info.compressedKb != null;

    return Container(
      width: double.infinity,
      color: wasCompressed
          ? AppTheme.accent.withOpacity(0.10)
          : AppTheme.success.withOpacity(0.10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            wasCompressed ? Icons.compress_rounded : Icons.check_circle_rounded,
            size: 20,
            color: wasCompressed ? AppTheme.accent : AppTheme.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textDark,
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: '[DEBUG] Image: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: 'Original ${info.originalKb} KB'),
                  if (wasCompressed) ...[
                    const TextSpan(text: '  →  Compressed '),
                    TextSpan(
                      text: '${info.compressedKb} KB',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                      ),
                    ),
                    TextSpan(
                      text:
                      '  (saved ${info.originalKb - info.compressedKb!} KB)',
                      style: const TextStyle(color: AppTheme.textMedium),
                    ),
                  ] else
                    const TextSpan(
                      text: '  — under 500 KB, no compression needed',
                      style: TextStyle(color: AppTheme.textMedium),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ── [IMAGE SIZE DEBUG END] ────────────────────────────────────────────────────

  // ── Segment widgets ───────────────────────────────────────────────────────

  List<Widget> _buildHighlightedSegments() {
    final widgets = <Widget>[];
    final allLines = _displayText.split('\n');

    final Map<int, List<int>> lineToSegments = {};
    for (int si = 0; si < _segments.length; si++) {
      final origIdx = _segments[si].origLineIdx;
      lineToSegments.putIfAbsent(origIdx, () => []).add(si);
    }

    final emittedLines = <int>{};

    for (int origIdx = 0; origIdx < allLines.length; origIdx++) {
      final rawLine = allLines[origIdx];

      if (rawLine.trim().isEmpty) {
        widgets.add(const SizedBox(height: 16));
        continue;
      }

      final segIndices = lineToSegments[origIdx] ?? [];
      if (segIndices.isEmpty || emittedLines.contains(origIdx)) continue;
      emittedLines.add(origIdx);

      for (final si in segIndices) {
        final seg = _segments[si];
        final isHighlighted = si == _highlightedLine;

        widgets.add(
          KeyedSubtree(
            key: _segmentKeys[si],
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 6),
              padding: isHighlighted
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                  : const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? AppTheme.accent.withOpacity(0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isHighlighted
                    ? Border(
                  left: BorderSide(color: AppTheme.accent, width: 4),
                )
                    : null,
              ),
              child: SelectableText(
                seg.text,
                style: TextStyle(
                  fontSize: AppTheme.fontMD * _fontSize,
                  color: isHighlighted
                      ? AppTheme.textDark
                      : AppTheme.textDark.withOpacity(0.75),
                  height: 1.7,
                  fontWeight:
                  isHighlighted ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  // ── Audio row: Play/Stop button + Voice selector button ───────────────────

  Widget _buildAudioRow() {
    final voiceName = _dataService.getPreferredVoiceName();
    final hasCustomVoice = voiceName != null;

    return Row(
      children: [
        // Main play/stop button — takes most of the width
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _playing ? _stopReading : _startReading,
            style: ElevatedButton.styleFrom(
              backgroundColor: _playing ? AppTheme.danger : AppTheme.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 68),
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: _playing ? 6 : 2,
            ),
            icon: Icon(
              _playing ? Icons.stop_rounded : Icons.volume_up_rounded,
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
        // Voice selection button
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
                    'Voice',
                    style: TextStyle(
                      fontSize: 11,
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