import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../app_theme.dart';
import '../models/saved_text.dart';
import '../services/ad_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/local_ocr_service.dart';
import '../services/mlkit_translation_service.dart';
import '../services/premium_service.dart';
import '../services/groq_translation_service.dart';
import '../services/translation_service.dart';
import '../widgets/language_selector.dart';
import 'result_screen.dart';
import 'feedback_screen.dart';
import 'settings_screen.dart';
import 'upgrade_screen.dart';
import 'saved_text_screen.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:html2md/html2md.dart' as html2md;
import '../models/qr_saved_text.dart';
import 'qr_result_screen.dart';
import '../widgets/language_selection_helper.dart';

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
  final PremiumService _premium = PremiumService();
  final LocalOcrService _localOcr = LocalOcrService();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<SavedText> _savedTexts = [];
  bool _loading = false;
  String _loadingStep = '';
  String _currentLang = 'en';

  bool _searchActive = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  static const int _freeDailyLimit = 3;

  // ── Guest helper ──────────────────────────────────────────────────────────

  bool get _isGuest => FirebaseAuth.instance.currentUser?.isAnonymous ?? false;

  // ── Scan mode helper ──────────────────────────────────────────────────────

  /// Returns true when the user has chosen the local (offline) scan mode.
  bool get _useLocalScan => _dataService.getScanMode() == 'local';

  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  bool _isProcessingQr = false;

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  bool _showZoomSlider = false;

  @override
  void initState() {
    super.initState();
    _currentLang = _dataService.getLanguage();
    _loadSavedTexts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCamera();
      // Pre-load the rewarded ad so it is ready when the limit dialog shows.
      AdService().preload();
    });
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
        );
        await _cameraController!.initialize();
        _minZoom = await _cameraController!.getMinZoomLevel();
        _maxZoom = await _cameraController!.getMaxZoomLevel();
        _currentZoom = _minZoom;
        if (mounted) {
          setState(() => _isCameraInitialized = true);
          _cameraController!.startImageStream(_processCameraImage);
        }
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessingQr) return;
    if (_cameraController == null) return;
    
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    
    _isProcessingQr = true;
    try {
      final barcodes = await _barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        final barcode = barcodes.first;
        final url = barcode.rawValue;
        if (url != null && (url.startsWith('http://') || url.startsWith('https://'))) {
          await _cameraController!.stopImageStream();
          await _showQrDialog(url);
          if (mounted && _cameraController != null && _cameraController!.value.isInitialized) {
            _cameraController!.startImageStream(_processCameraImage);
          }
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) _isProcessingQr = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null || _cameras == null || _cameras!.isEmpty) return null;
    final camera = _cameras![0];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _showQrDialog(String url) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _tr.t('qr_dialog_title'),
                style: const TextStyle(
                  fontSize: AppTheme.fontMD,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tr.t('qr_dialog_body'),
              style: const TextStyle(fontSize: AppTheme.fontSM),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Text(
                url,
                style: const TextStyle(
                  fontSize: AppTheme.fontXS,
                  color: AppTheme.textMedium,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(_tr.t('cancel')),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'open'),
            child: Text(_tr.t('qr_open_webpage')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'summarise'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
            ),
            child: Text(_tr.t('qr_summarise_page')),
          ),
        ],
      ),
    );

    if (result == 'open') {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (result == 'summarise') {
      await _summariseUrl(url);
    }
  }

  Future<void> _summariseUrl(String url) async {
    if (!_canScan()) {
      _showScanLimitDialog(
        onAdRewarded: () => _executeSummariseUrl(url),
      );
      return;
    }
    await _executeSummariseUrl(url);
  }

  Future<void> _executeSummariseUrl(String url) async {
    // ── Phase 1 loading dialog — we update the message text via a ValueNotifier
    final phaseNotifier = ValueNotifier<String>(_tr.t('qr_summarising'));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<String>(
        valueListenable: phaseNotifier,
        builder: (_, msg, __) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.accent),
                const SizedBox(height: 16),
                Text(
                  msg,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    decoration: TextDecoration.none,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 1. Fetch website HTML
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Failed to load webpage');
      }

      // 2. Convert HTML to clean markdown text
      final markdownText = html2md.convert(response.body);
      if (markdownText.trim().isEmpty) {
        throw Exception('No readable text found');
      }

      // 3. Summarise via backend Groq API (English summary)
      final summary = await _apiService.summariseText(url, markdownText);
      if (!mounted) return;

      // 4. Pre-translate into the 4 default languages
      phaseNotifier.value = _tr.t('home_translating');
      final translations = await _mlkit.translateToAllConfigured(summary);
      translations['en'] = summary; // always keep English

      if (!mounted) return;

      // 5. Record the scan against their limit (only for free users)
      if (_premium.isFree) {
        await _dataService.incrementFreeScanCount();
      }

      Navigator.pop(context); // close loading

      final userId = AuthService().currentUser?.uid ?? '';

      final qrScan = QrSavedText(
        id: const Uuid().v4(),
        userId: userId,
        url: url,
        summary: summary,
        translations: translations,
        createdAt: DateTime.now(),
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QrResultScreen(
            qrScan: qrScan,
            isNew: true,
            initialLang: _currentLang,
          ),
        ),
      );
      
      // Update the UI (like scan limit) after returning from the result screen
      if (mounted) {
        await _loadSavedTexts();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr.t('qr_error_summary')),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      phaseNotifier.dispose();
    }
  }


  @override
  void dispose() {
    _barcodeScanner.close();
    _cameraController?.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSavedTexts() async {
    // Guest users have no saved texts persisted (UID is ephemeral),
    // so the list will simply be empty — no change needed.
    final texts = await _dataService.getSavedTexts();
    if (mounted) setState(() => _savedTexts = texts);
  }

  // ── Search helpers ────────────────────────────────────────────────────────

  List<SavedText> get _filteredTexts {
    if (!_searchActive || _searchQuery.isEmpty) return _savedTexts;
    final q = _searchQuery.toLowerCase();
    return _savedTexts.where((t) {
      if (t.name == null || t.name!.trim().isEmpty) return false;
      return t.name!.toLowerCase().contains(q);
    }).toList();
  }

  void _openSearch() {
    if (_scaffoldKey.currentState?.isEndDrawerOpen == true) {
      Navigator.pop(context);
    }
    setState(() {
      _searchActive = true;
      _searchQuery = '';
    });
    _searchController.clear();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    setState(() {
      _searchActive = false;
      _searchQuery = '';
    });
    _searchController.clear();
    _searchFocus.unfocus();
  }

  // ── Free-tier scan limit ──────────────────────────────────────────────────

  bool _canScan() {
    if (_premium.isPremium) return true;
    return _dataService.getFreeScanCount() < _freeDailyLimit;
  }

  /// Three actions are always available:
  ///   1. Watch a rewarded video ad → grants +1 scan
  ///   2. Continue with free offline scan
  ///   3. Cancel
  void _showScanLimitDialog({ImageSource? source, VoidCallback? onAdRewarded}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ScanLimitDialog(
        isGuest: _isGuest,
        translations: _tr,
        onWatchAd: () async {
          // Dialog closes itself inside the callback
          if (!AdService().isRewardedAdReady) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_tr.t('home_ad_not_ready')),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            return;
          }
          Navigator.pop(ctx);
          AdService().showRewardedAd(
            onRewarded: () async {
              await _dataService.decrementFreeScanCount();
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_tr.t('home_ad_reward_granted')),
                    backgroundColor: AppTheme.success,
                    duration: const Duration(seconds: 3),
                  ),
                );
                
                // Automatically proceed with the scan now that they have a free scan
                if (onAdRewarded != null) {
                  onAdRewarded();
                } else if (source != null) {
                  try {
                    final picked = await _picker.pickImage(
                      source: source,
                      imageQuality: 90,
                      maxWidth: 2048,
                      maxHeight: 2048,
                    );
                    if (picked != null && mounted) {
                      await _processImage(File(picked.path), useLocalOcr: false);
                    }
                  } catch (e) {
                    if (mounted) _showError(_tr.t('error_generic'));
                  }
                } else if (_selectedImage != null) {
                  await _processImage(_selectedImage!, useLocalOcr: false);
                }
              }
            },
            onFailed: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_tr.t('home_ad_not_ready')),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          );
        },
        onContinueOffline: () async {
          Navigator.pop(ctx);
          if (_selectedImage != null) {
            await _processImage(_selectedImage!, useLocalOcr: true);
          }
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  // ── Upgrade dialog for guests trying to access premium ────────────────────

  /// Shows a dialog asking the guest to log in before accessing premium.
  void _showGuestUpgradeBlockedDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 48,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _tr.t('home_sign_in_required'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontLG,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        content: Text(
          _tr.t('home_sign_in_required_desc'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: AppTheme.fontSM,
            color: AppTheme.textDark,
            height: 1.6,
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().signOut();
              // AppRoot listens → navigates to LoginScreen
            },
            icon: const Icon(Icons.login_rounded, size: 24),
            label: Text(
              _tr.t('home_sign_in_create'),
              style: const TextStyle(
                fontSize: AppTheme.fontSM,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size(double.infinity, 64),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(
              _tr.t('home_not_now'),
              style: const TextStyle(
                fontSize: AppTheme.fontXS,
                color: AppTheme.textMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Image helpers ─────────────────────────────────────────────────────────

  File? _selectedImage;

  Future<void> _takePictureWithCamera() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final image = await _cameraController!.takePicture();
      setState(() {
        _selectedImage = File(image.path);
      });
    } catch (e) {
      _showError(_tr.t('error_generic'));
    }
  }

  void _retakePicture() {
    setState(() {
      _selectedImage = null;
    });
  }

  /// Main entry point when the user taps Gallery.
  /// Routes to the local OCR path or the AI path depending on the user's
  /// setting.  If the AI scan quota is exhausted the limit dialog is shown.

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
        });
      }
    } catch (e) {
      _showError(_tr.t('error_generic'));
    }
  }

  Future<void> _confirmScan() async {
    if (_selectedImage == null) return;
    
    if (_useLocalScan) {
      await _processImage(_selectedImage!, useLocalOcr: true);
      return;
    }

    final netResults = await Connectivity().checkConnectivity();
    if (netResults.contains(ConnectivityResult.none) || netResults.isEmpty) {
      await _processImage(_selectedImage!, useLocalOcr: true);
      return;
    }

    if (!_canScan()) {
      _showScanLimitDialog(source: null);
      return;
    }
    
    await _processImage(_selectedImage!, useLocalOcr: false);
  }

  /// Picks an image and processes it using the offline ML Kit OCR.
  /// Does NOT count against the AI daily quota.
  Future<void> _pickImageWithLocalOcr(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (picked == null) return;
      await _processImage(File(picked.path), useLocalOcr: true);
    } catch (e) {
      _showError(_tr.t('error_generic'));
    }
  }

  Future<({Uint8List bytes, int originalKb, int? compressedKb})>
  _getOptimizedImage(File file) async {
    final int originalSize = file.lengthSync();
    final int originalKb = (originalSize / 1024).round();

    if (originalSize < 500 * 1024) {
      return (
      bytes: await file.readAsBytes(),
      originalKb: originalKb,
      compressedKb: null,
      );
    }

    final Uint8List? result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 1024,
      minHeight: 1024,
      quality: 75,
      format: CompressFormat.jpeg,
    );

    if (result != null) {
      return (
      bytes: result,
      originalKb: originalKb,
      compressedKb: (result.length / 1024).round(),
      );
    }

    return (
    bytes: await file.readAsBytes(),
    originalKb: originalKb,
    compressedKb: null,
    );
  }

  Future<void> _processImage(File imageFile, {bool useLocalOcr = false}) async {
    setState(() {
      _loading = true;
      _loadingStep = _tr.t('processing');
    });

    try {
      String originalText;

      if (useLocalOcr) {
        // ── Offline ML Kit path ───────────────────────────────────────────
        setState(() => _loadingStep = _tr.t('home_local_scan_reading'));
        originalText = await _localOcr.recognize(imageFile);
      } else {
        // ── AI / remote server path ───────────────────────────────────────
        setState(() => _loadingStep = _tr.t('home_checking_size'));
        final imageInfo = await _getOptimizedImage(imageFile);

        File fileToSend = imageFile;
        if (imageInfo.compressedKb != null) {
          final tempDir =
          await Directory.systemTemp.createTemp('ocr_compressed_');
          final tempFile = File('${tempDir.path}/compressed.jpg');
          await tempFile.writeAsBytes(imageInfo.bytes);
          fileToSend = tempFile;
        }

        setState(() => _loadingStep = _tr.t('processing'));
        try {
          originalText = await _apiService.processImage(fileToSend);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr.t('error_server_fallback')),
              backgroundColor: AppTheme.accent,
              duration: const Duration(seconds: 3),
            ),
          );
          await _processImage(imageFile, useLocalOcr: true);
          return;
        }

        // Only increment the AI quota counter for non-local scans.
        if (_premium.isFree) {
          await _dataService.incrementFreeScanCount();
        }

        if (originalText.trim().isEmpty) {
          setState(() => _loading = false);
          _showError(_tr.t('error_generic'));
          return;
        }

        Map<String, String> translations = {};
        if (_premium.isFree) {
          setState(() => _loadingStep = _tr.t('home_translating'));
          translations = await _mlkit.translateToAllConfigured(originalText);
        } else {
          // Fast heuristic to decide if we need Groq translation before showing
          bool needsTranslation(String text, String targetLang) {
            if (text.trim().isEmpty) return false;
            final hasZh = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
            final hasTa = RegExp(r'[\u0B80-\u0BFF]').hasMatch(text);
            if (targetLang == 'zh') return !hasZh;
            if (targetLang == 'ta') return !hasTa;
            if (targetLang == 'en') return hasZh || hasTa;
            // For ms (Malay), if it has Chinese or Tamil it definitely needs translation.
            // If it's Latin, we just pass it through to avoid slowing down the majority of scans.
            if (targetLang == 'ms') return hasZh || hasTa;
            return false;
          }

          if (needsTranslation(originalText, _currentLang)) {
            setState(() => _loadingStep = _tr.t('home_translating'));
            final translated = await GroqTranslationService().translateSmart(originalText, _currentLang);
            translations[_currentLang] = translated;
          } else {
            translations[_currentLang] = originalText;
          }
        }

        if (!mounted) return;
        setState(() => _loading = false);

        final result = SavedText(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: AuthService().currentUser?.uid ?? '',
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
              imageSizeInfo: imageInfo,
            ),
          ),
        );

        if (saved == true) await _loadSavedTexts();
        return;
      }

      // ── Shared tail for local OCR path ────────────────────────────────────
      if (originalText.trim().isEmpty) {
        setState(() => _loading = false);
        _showError(_tr.t('error_no_text'));
        return;
      }

      setState(() => _loadingStep = _tr.t('home_translating'));
      final translations = await _mlkit.translateToAllConfigured(originalText);

      if (!mounted) return;
      setState(() => _loading = false);

      final result = SavedText(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: AuthService().currentUser?.uid ?? '',
        originalText: originalText,
        translations: Map<String, String>.from(translations),
        createdAt: DateTime.now(),
      );

      // Local-scan results don't have an imageInfo compression report.
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            savedText: result,
            langCode: _currentLang,
            isNew: true,
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

  // ── CRUD helpers ──────────────────────────────────────────────────────────

  Future<void> _editTextName(SavedText text) async {
    String? result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final innerController = TextEditingController(text: text.name ?? '');
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            _tr.t('home_name_entry'),
            style: const TextStyle(
              fontSize: AppTheme.fontMD,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr.t('home_name_entry_desc'),
                  style: const TextStyle(
                    fontSize: AppTheme.fontXS,
                    color: AppTheme.textMedium,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: innerController,
                  autofocus: true,
                  maxLength: 60,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: _tr.t('home_name_hint'),
                    counterStyle: const TextStyle(fontSize: AppTheme.fontXS),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.all(16),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(minimumSize: const Size(100, 52)),
              child: Text(_tr.t('cancel'),
                  style: const TextStyle(fontSize: AppTheme.fontXS)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, innerController.text),
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 52)),
              child: Text(_tr.t('home_save_name'),
                  style: const TextStyle(fontSize: AppTheme.fontXS)),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final newName = result.trim();
      text.name = newName.isEmpty ? null : newName;
      await _dataService.updateText(text);
      await _loadSavedTexts();
    }
  }

  Future<void> _deleteText(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_tr.t('delete_confirm'),
            style: const TextStyle(
                fontSize: AppTheme.fontMD, fontWeight: FontWeight.bold)),
        content: Text(_tr.t('delete_message'),
            style: const TextStyle(fontSize: AppTheme.fontSM)),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(minimumSize: const Size(100, 52)),
            child: Text(_tr.t('cancel'),
                style: const TextStyle(fontSize: AppTheme.fontXS)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              minimumSize: const Size(100, 52),
            ),
            child: Text(_tr.t('confirm_delete'),
                style: const TextStyle(fontSize: AppTheme.fontXS)),
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
        content: Text(msg, style: const TextStyle(fontSize: AppTheme.fontXS)),
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: _searchActive
              ? _buildSearchField()
              : Row(
            children: [
              Expanded(
                child: Text(
                  _tr.t('home_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: _buildAppBarActions(),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              color: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: LanguageSelector(
                currentLang: _currentLang,
                onChanged: _changeLanguage,
              ),
            ),
          ),
        ),
        endDrawer: _buildEndDrawer(),
        body: _loading ? _buildLoading() : _buildBody(),
        bottomNavigationBar: null,
      ),
    );
  }

  // ── Right-panel drawer ────────────────────────────────────────────────────

  Widget _buildEndDrawer() {
    final isPremium = _premium.isPremium;
    final scansUsed = _dataService.getFreeScanCount();
    final scansLeft = (_freeDailyLimit - scansUsed).clamp(0, _freeDailyLimit);

    return Drawer(
      width: 280,
      backgroundColor: AppTheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              color: AppTheme.primary,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.translate_rounded, color: Colors.white, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    _tr.t('app_name'),
                    style: const TextStyle(
                      fontSize: AppTheme.fontLG,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isGuest
                          ? Colors.white.withValues(alpha: 0.20)
                          : isPremium
                          ? AppTheme.accent
                          : Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isGuest
                              ? Icons.person_outline_rounded
                              : isPremium
                              ? Icons.auto_awesome_rounded
                              : Icons.phone_android_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isGuest
                              ? _tr.t('home_guest')
                              : isPremium
                              ? _tr.t('home_premium')
                              : _tr.t('home_free_plan'),
                          style: const TextStyle(
                            fontSize: AppTheme.fontXS,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Saved Texts button ────────────────────────────────────────────
            _drawerButton(
              icon: Icons.history_rounded,
              label: _tr.t('saved_texts'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SavedTextScreen(onLanguageChanged: widget.onLanguageChanged)),
                );
                setState(() => _currentLang = _dataService.getLanguage());
                await _loadSavedTexts();
              },
            ),

            const SizedBox(height: 4),

            // ── Upgrade button (guests see "Sign In to Upgrade") ─────────
            _drawerButton(
              icon: _isGuest ? Icons.login_rounded : Icons.auto_awesome_rounded,
              label: _isGuest
                  ? _tr.t('home_sign_in_upgrade')
                  : isPremium
                  ? _tr.t('home_manage_plan')
                  : _tr.t('home_upgrade_premium'),
              onTap: () async {
                Navigator.pop(context);
                if (_isGuest) {
                  _showGuestUpgradeBlockedDialog();
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                  );
                  setState(() {});
                }
              },
              highlight: !isPremium,
            ),

            const SizedBox(height: 4),

            // ── Settings button ──────────────────────────────────────────
            _drawerButton(
              icon: Icons.settings_rounded,
              label: _tr.t('settings'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                setState(() => _currentLang = _dataService.getLanguage());
                await _loadSavedTexts();
              },
            ),

            const SizedBox(height: 4),

            // ── Feedback button ──────────────────────────────────────────
            _drawerButton(
              icon: Icons.feedback_rounded,
              label: _tr.t('feedback'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FeedbackScreen(),
                  ),
                );
              },
            ),

            const Spacer(),

            // ── Daily scan usage ─────────────────────────────────────────
            if (!isPremium) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.document_scanner_rounded,
                          size: 20,
                          color: scansLeft == 0
                              ? AppTheme.danger
                              : AppTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _tr.t('home_daily_scans'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppTheme.fontSM,
                              fontWeight: FontWeight.bold,
                              color: scansLeft == 0
                                  ? AppTheme.danger
                                  : AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: scansUsed / _freeDailyLimit,
                        minHeight: 10,
                        backgroundColor: AppTheme.cardBorder,
                        color:
                        scansLeft == 0 ? AppTheme.danger : AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$scansLeft ${_tr.t('home_of')} $_freeDailyLimit ${_tr.t('home_scans_left')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTheme.fontSM,
                        color: scansLeft == 0
                            ? AppTheme.danger
                            : AppTheme.textMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _drawerButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool highlight = false,
    bool enabled = true,
  }) {
    final color = highlight ? AppTheme.accent : AppTheme.primary;
    final bgColor = highlight
        ? AppTheme.accent.withValues(alpha: 0.08)
        : Colors.transparent;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: highlight
                ? Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.5), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar helpers ────────────────────────────────────────────────────────

  Widget _buildSearchField() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        style: const TextStyle(
          color: AppTheme.textDark,
          fontSize: AppTheme.fontSM,
        ),
        cursorColor: AppTheme.primary,
        decoration: InputDecoration(
          hintText: _tr.t('home_search_by_name'),
          hintStyle: const TextStyle(
            color: AppTheme.textLight,
            fontSize: AppTheme.fontSM,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.primary,
            size: 24,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      IconButton(
        icon: const Icon(Icons.menu_rounded),
        iconSize: 42,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        alignment: Alignment.center,
        tooltip: 'Menu',
        onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
      ),
      const SizedBox(width: 4),
    ];
  }

  // ── Body ──────────────────────────────────────────────────────────────────

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
    final isPremium = _premium.isPremium;
    final scansUsed = _dataService.getFreeScanCount();
    final scansLeft = (_freeDailyLimit - scansUsed).clamp(0, _freeDailyLimit);
    final scanModeLabel = _useLocalScan
        ? _tr.t('home_scan_mode_local')
        : _tr.t('home_scan_mode_ai');
    final limitLabel = isPremium
        ? _tr.t('settings_unlimited')
        : '$scansLeft ${_tr.t('home_of')} $_freeDailyLimit ${_tr.t('home_scans_left')}';
    final isAtLimit = !isPremium && scansLeft == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Scan mode banner ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          color: AppTheme.primary.withValues(alpha: 0.07),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _useLocalScan
                    ? Icons.phone_android_rounded
                    : Icons.auto_awesome_rounded,
                size: 18,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${_tr.t('home_current_scan_mode')} $scanModeLabel  •  $limitLabel',
                  style: TextStyle(
                    fontSize: AppTheme.fontXS,
                    fontWeight: FontWeight.w600,
                    color: isAtLimit ? AppTheme.danger : AppTheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        // ── Camera Preview or Image Preview ───────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _selectedImage != null
                  ? Image.file(
                      _selectedImage!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    )
                  : _isCameraInitialized && _cameraController != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_cameraController!),
                            Positioned(
                              bottom: 16,
                              left: 16,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_showZoomSlider)
                                    Container(
                                      height: 150,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: RotatedBox(
                                        quarterTurns: -1,
                                        child: Slider(
                                          value: _currentZoom,
                                          min: _minZoom,
                                          max: _maxZoom,
                                          activeColor: Colors.white,
                                          inactiveColor: Colors.white30,
                                          onChanged: (val) {
                                            setState(() => _currentZoom = val);
                                            _cameraController!.setZoomLevel(val);
                                          },
                                        ),
                                      ),
                                    ),
                                  InkWell(
                                    onTap: () => setState(() => _showZoomSlider = !_showZoomSlider),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black45,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${_currentZoom.toStringAsFixed(1)}x',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: FloatingActionButton(
                                heroTag: 'gallery_btn',
                                backgroundColor: AppTheme.accent,
                                onPressed: () => _pickImage(ImageSource.gallery),
                                child: const Icon(Icons.photo_library_rounded, color: Colors.white),
                              ),
                            ),
                          ],
                        )
                      : const Center(
                          child: CircularProgressIndicator(color: AppTheme.primary),
                        ),
            ),
          ),
        ),

        // ── Bottom Action Button ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: _selectedImage != null
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _retakePicture,
                        icon: const Icon(Icons.refresh_rounded, size: 28),
                        label: Text(_tr.t('retake_photo') == 'retake_photo' ? 'Retake' : _tr.t('retake_photo')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary, width: 2),
                          minimumSize: const Size(0, 72),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _confirmScan,
                        icon: const Icon(Icons.check_circle_rounded, size: 28),
                        label: Text(_tr.t('confirm')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          minimumSize: const Size(0, 72),
                        ),
                      ),
                    ),
                  ],
                )
              : ElevatedButton.icon(
                  onPressed: _takePictureWithCamera,
                  icon: const Icon(Icons.camera_alt_rounded, size: 30),
                  label: Text(_tr.t('take_photo')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size(double.infinity, 72),
                  ),
                ),
        ),

        // ── Banner Ad ────────────────────────────────────────────────────────
        // Only shown for non-premium users; premium benefit = no ads.
        if (!_premium.isPremium)
          const Center(child: BannerAdWidget()),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Scan-limit dialog — separated into its own StatefulWidget so it can
// rebuild when the rewarded-ad readiness state changes.
// ════════════════════════════════════════════════════════════════════════════

class _ScanLimitDialog extends StatefulWidget {
  final bool isGuest;
  final AppTranslations translations;
  final Future<void> Function() onWatchAd;
  final Future<void> Function() onContinueOffline;
  final VoidCallback onCancel;

  const _ScanLimitDialog({
    required this.isGuest,
    required this.translations,
    required this.onWatchAd,
    required this.onContinueOffline,
    required this.onCancel,
  });

  @override
  State<_ScanLimitDialog> createState() => _ScanLimitDialogState();
}

class _ScanLimitDialogState extends State<_ScanLimitDialog> {
  bool _watching = false;

  @override
  Widget build(BuildContext context) {
    final tr = widget.translations;
    final adReady = AdService().isRewardedAdReady;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.document_scanner_rounded,
              size: 32,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr.t('home_daily_limit_title'),
              style: const TextStyle(
                fontSize: AppTheme.fontMD,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        tr.t('home_daily_limit_free'),
        style: const TextStyle(
          fontSize: AppTheme.fontSM,
          color: AppTheme.textMedium,
          height: 1.5,
        ),
      ),
      actions: [
        // ── Watch Ad button (+1 scan) ──────────────────────────────────────
        ElevatedButton.icon(
          onPressed: (_watching || !adReady)
              ? null
              : () async {
                  setState(() => _watching = true);
                  await widget.onWatchAd();
                  if (mounted) setState(() => _watching = false);
                },
          icon: _watching
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.play_circle_rounded, size: 22),
          label: Text(
            adReady ? tr.t('home_watch_ad') : tr.t('home_ad_not_ready'),
            style: const TextStyle(
              fontSize: AppTheme.fontSM,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: adReady ? AppTheme.accent : AppTheme.cardBorder,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // ── Continue with offline scan ─────────────────────────────────────
        OutlinedButton.icon(
          onPressed: _watching ? null : () => widget.onContinueOffline(),
          icon: const Icon(Icons.phone_android_rounded, size: 20),
          label: Text(
            tr.t('home_continue_free_scan'),
            style: const TextStyle(
              fontSize: AppTheme.fontSM,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: const BorderSide(color: AppTheme.primary, width: 1.5),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // ── Cancel ────────────────────────────────────────────────────────
        TextButton(
          onPressed: _watching ? null : widget.onCancel,
          style: TextButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
          ),
          child: Text(
            tr.t('cancel'),
            style: const TextStyle(
              fontSize: AppTheme.fontXS,
              color: AppTheme.textMedium,
            ),
          ),
        ),
      ],
    );
  }
}

