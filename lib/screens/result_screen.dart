import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/saved_text.dart';
import '../services/data_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import '../widgets/audio_button.dart';
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

  @override
  void initState() {
    super.initState();
    _currentLang = widget.langCode;
    _fontSize = _dataService.getFontSize();
    _saved = !widget.isNew;
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  String get _displayText => widget.savedText.forLanguage(_currentLang);

  Future<void> _save() async {
    await _dataService.saveText(widget.savedText);
    setState(() => _saved = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr.t('saved_success'))),
    );
    Navigator.pop(context, true);
  }

  Future<void> _changeLanguage(String langCode) async {
    await _tts.stop();
    await _tr.load(langCode);
    setState(() => _currentLang = langCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_tr.t('result_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 30),
          onPressed: () {
            _tts.stop();
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
          // Font size control
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: FontSizeSlider(
              onChanged: (v) => setState(() => _fontSize = v),
            ),
          ),
          const Divider(height: 1),

          // Main text display
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                _displayText.isEmpty ? '—' : _displayText,
                style: TextStyle(
                  fontSize: AppTheme.fontMD * _fontSize,
                  color: AppTheme.textDark,
                  height: 1.7,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Bottom action area
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
                AudioButton(text: _displayText, langCode: _currentLang),
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
}
