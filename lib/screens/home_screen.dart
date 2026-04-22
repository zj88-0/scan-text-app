import 'dart:io'; // covers File and Directory
// ── [IMAGE SIZE DEBUG] Added dart:typed_data for Uint8List ──────────────────
import 'dart:typed_data';
// ────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// ── [IMAGE SIZE DEBUG] Added flutter_image_compress import ──────────────────
import 'package:flutter_image_compress/flutter_image_compress.dart';
// ────────────────────────────────────────────────────────────────────────────
import '../app_theme.dart';
import '../models/saved_text.dart';
import '../services/api_service.dart';
import '../services/data_service.dart';
import '../services/mlkit_translation_service.dart';
import '../services/translation_service.dart';
import '../widgets/language_selector.dart';
import '../widgets/saved_text_card.dart';
import 'result_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLanguageChanged;

  const HomeScreen({super.key, required this.onLanguageChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  final DataService _dataService = DataService();
  final AppTranslations _tr = AppTranslations();
  final OnDeviceTranslationService _mlkit = OnDeviceTranslationService();

  List<SavedText> _savedTexts = [];
  bool _loading = false;
  String _loadingStep = '';
  String _currentLang = 'en';

  @override
  void initState() {
    super.initState();
    _currentLang = _dataService.getLanguage();
    _loadSavedTexts();
  }

  Future<void> _loadSavedTexts() async {
    final texts = await _dataService.getSavedTexts();
    if (mounted) setState(() => _savedTexts = texts);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (picked == null) return;
      await _processImage(File(picked.path));
    } catch (e) {
      _showError(_tr.t('error_generic'));
    }
  }

  // ── [IMAGE SIZE DEBUG] Helper: check size and compress if over 500 KB ──────
  // To remove: delete this entire method (_getOptimizedImage)
  Future<({Uint8List bytes, int originalKb, int? compressedKb})>
  _getOptimizedImage(File file) async {
    final int originalSize = file.lengthSync();
    final int originalKb = (originalSize / 1024).round();

    if (originalSize < 500 * 1024) {
      // Under 500 KB — no compression needed
      return (
      bytes: await file.readAsBytes(),
      originalKb: originalKb,
      compressedKb: null,
      );
    }

    // Over 500 KB — compress
    final Uint8List? result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 1024,
      minHeight: 1024,
      quality: 75,
      format: CompressFormat.jpeg,
    );

    if (result != null) {
      final int compressedKb = (result.length / 1024).round();
      return (
      bytes: result,
      originalKb: originalKb,
      compressedKb: compressedKb,
      );
    }

    // Fallback if compression fails
    return (
    bytes: await file.readAsBytes(),
    originalKb: originalKb,
    compressedKb: null,
    );
  }
  // ── [IMAGE SIZE DEBUG END] ──────────────────────────────────────────────────

  Future<void> _processImage(File imageFile) async {
    setState(() {
      _loading = true;
      _loadingStep = _tr.t('processing');
    });

    try {
      // ── [IMAGE SIZE DEBUG] Run size check + compression before OCR ──────────
      // To remove: delete from here...
      setState(() => _loadingStep = 'Checking image size...');
      final imageInfo = await _getOptimizedImage(imageFile);

      // Write compressed bytes to a temp file so the API receives the
      // compressed image when compression was applied, otherwise use original.
      File fileToSend = imageFile;
      if (imageInfo.compressedKb != null) {
        final tempDir = await Directory.systemTemp.createTemp('ocr_compressed_');
        final tempFile = File('${tempDir.path}/compressed.jpg');
        await tempFile.writeAsBytes(imageInfo.bytes);
        fileToSend = tempFile;
      }
      // ...to here (and the imageSizeInfo: parameter below)
      // ── [IMAGE SIZE DEBUG END] ───────────────────────────────────────────────

      // Step 1: OCR from backend
      setState(() => _loadingStep = _tr.t('processing'));
      // ── [IMAGE SIZE DEBUG] Use fileToSend (compressed if applicable) ─────────
      // To remove: change fileToSend back to imageFile on the next line
      final originalText = await _apiService.processImage(fileToSend);
      // ── [IMAGE SIZE DEBUG END] ───────────────────────────────────────────────

      // Step 2: Translate locally using ML Kit
      setState(() => _loadingStep = 'Translating...');
      final translations = await _mlkit.translateToAllConfigured(originalText);

      setState(() => _loading = false);

      if (!mounted) return;

      // Build a SavedText with the on-device translations (not yet saved)
      final result = SavedText(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        originalText: originalText,
        translations: Map<String, String>.from(translations),
        createdAt: DateTime.now(),
      );

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            savedText: result,
            langCode: _currentLang,
            isNew: true,
            // ── [IMAGE SIZE DEBUG] Pass size info to ResultScreen ──────────────
            // To remove: delete this imageSizeInfo: line
            imageSizeInfo: imageInfo,
            // ── [IMAGE SIZE DEBUG END] ─────────────────────────────────────────
          ),
        ),
      );

      if (saved == true) await _loadSavedTexts();
    } catch (e) {
      setState(() => _loading = false);
      _showError(e.toString().contains('connect')
          ? _tr.t('error_server')
          : _tr.t('error_generic'));
    }
  }

  Future<void> _deleteText(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_tr.t('delete_confirm'),
            style: const TextStyle(fontSize: AppTheme.fontMD, fontWeight: FontWeight.bold)),
        content: Text(_tr.t('delete_message'),
            style: const TextStyle(fontSize: AppTheme.fontSM)),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(minimumSize: const Size(100, 52)),
            child: Text(_tr.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              minimumSize: const Size(100, 52),
            ),
            child: Text(_tr.t('confirm_delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _dataService.deleteText(id);
      await _loadSavedTexts();
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.danger,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _changeLanguage(String langCode) async {
    await _tr.load(langCode);
    setState(() => _currentLang = langCode);
    widget.onLanguageChanged();
    await _loadSavedTexts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr.t('home_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, size: 30),
            tooltip: _tr.t('settings'),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              // Refresh language in case it changed
              setState(() => _currentLang = _dataService.getLanguage());
              await _loadSavedTexts();
            },
          ),
          const SizedBox(width: 8),
        ],
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
      body: _loading ? _buildLoading() : _buildBody(),
      bottomNavigationBar: _loading ? null : _buildBottomButtons(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppTheme.accent,
            strokeWidth: 5,
          ),
          const SizedBox(height: 28),
          Text(
            _loadingStep,
            style: const TextStyle(
              fontSize: AppTheme.fontLG,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_savedTexts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_search_rounded,
                  size: 90, color: AppTheme.primary.withOpacity(0.25)),
              const SizedBox(height: 24),
              Text(
                _tr.t('no_saved_texts'),
                style: const TextStyle(
                  fontSize: AppTheme.fontMD,
                  color: AppTheme.textMedium,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Text(
            _tr.t('saved_texts'),
            style: const TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _savedTexts.length,
            itemBuilder: (ctx, i) {
              final text = _savedTexts[i];
              return SavedTextCard(
                savedText: text,
                langCode: _currentLang,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResultScreen(
                        savedText: text,
                        langCode: _currentLang,
                        isNew: false,
                      ),
                    ),
                  );
                  setState(() => _currentLang = _dataService.getLanguage());
                },
                onDelete: () => _deleteText(text.id),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded, size: 30),
                label: Text(_tr.t('take_photo')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size(0, 68),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded, size: 30),
                label: Text(_tr.t('upload_image')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  minimumSize: const Size(0, 68),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}