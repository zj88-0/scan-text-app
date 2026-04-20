import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/saved_text.dart';
import '../services/data_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import '../widgets/font_size_slider.dart';
import '../widgets/language_selector.dart';

class ResultScreen extends StatefulWidget {
  final SavedText savedText;
  final String langCode;
  final bool isNew;

  const ResultScreen({
    super.key,
    required this.savedText,
    required this.langCode,
    required this.isNew,
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

  /// Flat list of speakable segments (sentences or short clauses).
  /// Each entry: { 'text': String, 'origLineIdx': int }
  List<_Segment> _segments = [];

  bool _stopRequested = false;

  final ScrollController _scrollController = ScrollController();

  /// One GlobalKey per segment for scroll-to-highlight.
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

  /// Split display text into individual segments for line-by-line reading.
  ///
  /// Strategy:
  ///   1. Split on newlines first to preserve paragraph structure.
  ///   2. Within each non-empty line, split on sentence-ending punctuation
  ///      so long lines don't become one giant highlighted block.
  void _buildSegments() {
    _segments = [];
    final allLines = _displayText.split('\n');

    for (int lineIdx = 0; lineIdx < allLines.length; lineIdx++) {
      final line = allLines[lineIdx].trim();
      if (line.isEmpty) continue;

      // Split on sentence boundaries: . ! ? followed by space or end-of-string.
      // Keep the punctuation attached to the preceding text.
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
      // Keep highlighted segment in the upper-centre of the viewport.
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

          // ── Highlighted text area ─────────────────────────────────────
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

          // ── Bottom controls ───────────────────────────────────────────
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
                _buildAudioButton(),
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

  // ── Segment widgets ───────────────────────────────────────────────────────

  List<Widget> _buildHighlightedSegments() {
    final widgets = <Widget>[];
    final allLines = _displayText.split('\n');

    // Build a lookup: origLineIdx → list of segment indices belonging to that line.
    final Map<int, List<int>> lineToSegments = {};
    for (int si = 0; si < _segments.length; si++) {
      final origIdx = _segments[si].origLineIdx;
      lineToSegments.putIfAbsent(origIdx, () => []).add(si);
    }

    // Track which original lines we've emitted so we don't double-render.
    final emittedLines = <int>{};

    for (int origIdx = 0; origIdx < allLines.length; origIdx++) {
      final rawLine = allLines[origIdx];

      if (rawLine.trim().isEmpty) {
        // Preserve paragraph spacing.
        widgets.add(const SizedBox(height: 16));
        continue;
      }

      final segIndices = lineToSegments[origIdx] ?? [];
      if (segIndices.isEmpty || emittedLines.contains(origIdx)) continue;
      emittedLines.add(origIdx);

      // Render each sentence/segment within this line individually.
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

  // ── Audio button ──────────────────────────────────────────────────────────

  Widget _buildAudioButton() {
    return ElevatedButton.icon(
      onPressed: _playing ? _stopReading : _startReading,
      style: ElevatedButton.styleFrom(
        backgroundColor: _playing ? AppTheme.danger : AppTheme.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 68),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _Segment {
  final String text;
  final int origLineIdx;
  const _Segment({required this.text, required this.origLineIdx});
}