import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../app_theme.dart';
import '../models/saved_text.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/local_ocr_service.dart';
import '../services/mlkit_translation_service.dart';
import '../services/premium_service.dart';
import '../services/translation_service.dart';
import '../widgets/language_selector.dart';
import '../widgets/saved_text_card.dart';
import 'result_screen.dart';
import 'settings_screen.dart';
import 'upgrade_screen.dart';
import 'login_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _currentLang = _dataService.getLanguage();
    _loadSavedTexts();
  }

  @override
  void dispose() {
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

  /// Shows the limit dialog when the daily AI-scan quota is exhausted.
  ///
  /// - Guest users: offer to sign in OR continue with the free local scan.
  /// - Free (logged-in) users: offer to upgrade OR continue with the free
  ///   local scan.
  ///
  /// [source] is forwarded to [_pickImage] if the user chooses to continue
  /// with the local scan (so we know which camera/gallery to open).
  void _showScanLimitDialog({ImageSource? source}) {
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
                color: AppTheme.accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                size: 48,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _tr.t('home_daily_limit_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontLG,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            _isGuest
                ? _tr.t('home_daily_limit_guest')
                : _tr.t('home_daily_limit_free'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppTheme.fontSM,
              color: AppTheme.textDark,
              height: 1.6,
            ),
          ),
        ),
        actions: [
          if (_isGuest) ...[
            // Primary: Sign In / Create Account
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await AuthService().signOut(); // signs out anonymous user
                // AppRoot listens to authStateChanges → will show LoginScreen
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
            // Secondary: Continue with free local scan
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                if (source != null) {
                  await _pickImageWithLocalOcr(source);
                }
              },
              icon: const Icon(Icons.phone_android_rounded, size: 22),
              label: Text(
                _tr.t('home_continue_free_scan'),
                style: const TextStyle(
                  fontSize: AppTheme.fontSM,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary, width: 1.5),
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              child: Text(
                _tr.t('home_maybe_later'),
                style: const TextStyle(
                  fontSize: AppTheme.fontXS,
                  color: AppTheme.textMedium,
                ),
              ),
            ),
          ] else ...[
            // Primary: Upgrade to Premium
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                );
                setState(() {});
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 22),
              label: Text(
                _tr.t('home_upgrade_premium'),
                style: const TextStyle(
                  fontSize: AppTheme.fontSM,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                minimumSize: const Size(double.infinity, 64),
              ),
            ),
            const SizedBox(height: 10),
            // Secondary: Continue with free local scan
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                if (source != null) {
                  await _pickImageWithLocalOcr(source);
                }
              },
              icon: const Icon(Icons.phone_android_rounded, size: 22),
              label: Text(
                _tr.t('home_continue_free_scan'),
                style: const TextStyle(
                  fontSize: AppTheme.fontSM,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary, width: 1.5),
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              child: Text(
                _tr.t('home_maybe_later'),
                style: const TextStyle(
                  fontSize: AppTheme.fontXS,
                  color: AppTheme.textMedium,
                ),
              ),
            ),
          ],
        ],
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
                color: AppTheme.primary.withOpacity(0.10),
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

  /// Main entry point when the user taps Camera or Gallery.
  /// Routes to the local OCR path or the AI path depending on the user's
  /// setting.  If the AI scan quota is exhausted the limit dialog is shown.
  Future<void> _pickImage(ImageSource source) async {
    // If the user has explicitly chosen local scan in Settings, bypass the
    // AI quota check entirely.
    if (_useLocalScan) {
      await _pickImageWithLocalOcr(source);
      return;
    }

    // Check internet connection; if offline, auto-fallback to local scan.
    final netResults = await Connectivity().checkConnectivity();
    if (netResults.contains(ConnectivityResult.none) || netResults.isEmpty) {
      await _pickImageWithLocalOcr(source);
      return;
    }

    // AI mode: enforce daily limit.
    if (!_canScan()) {
      _showScanLimitDialog(source: source);
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (picked == null) return;
      await _processImage(File(picked.path), useLocalOcr: false);
    } catch (e) {
      _showError(_tr.t('error_generic'));
    }
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
        originalText = await _apiService.processImage(fileToSend);

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
          translations = {'en': originalText};
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
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: LanguageSelector(
                currentLang: _currentLang,
                onChanged: _changeLanguage,
              ),
            ),
          ),
        ),
        endDrawer: _buildEndDrawer(),
        body: _loading ? _buildLoading() : _buildBody(),
        bottomNavigationBar: _loading ? null : _buildBottomButtons(),
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
                  const Icon(Icons.translate_rounded,
                      color: Colors.white, size: 36),
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
                          ? Colors.white.withOpacity(0.20)
                          : isPremium
                              ? AppTheme.accent
                              : Colors.white.withOpacity(0.20),
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

            // ── Search button ────────────────────────────────────────────
            _drawerButton(
              icon: Icons.search_rounded,
              label: _tr.t('home_search'),
              onTap: _savedTexts.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      _openSearch();
                    },
              enabled: _savedTexts.isNotEmpty,
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
    final bgColor =
        highlight ? AppTheme.accent.withOpacity(0.08) : Colors.transparent;

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
                ? Border.all(
                    color: AppTheme.accent.withOpacity(0.4), width: 1.5)
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
                  color: color.withOpacity(0.5), size: 22),
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
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppTheme.primary,
            size: 24,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_searchActive) {
      return [
        if (_searchQuery.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 26),
            tooltip: _tr.t('home_clear'),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
              _searchFocus.requestFocus();
            },
          ),
        IconButton(
          icon: const Icon(Icons.search_off_rounded, size: 28),
          tooltip: _tr.t('home_close_search'),
          onPressed: _closeSearch,
        ),
        const SizedBox(width: 4),
      ];
    }

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
                _isGuest
                    ? _tr.t('home_no_saved_texts_guest')
                    : _tr.t('no_saved_texts'),
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

    final displayed = _filteredTexts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: _searchActive && _searchQuery.isNotEmpty
              ? RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: AppTheme.fontMD,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                    children: [
                      TextSpan(
                        text: displayed.isEmpty
                            ? '${_tr.t('home_no_results')} '
                            : '${displayed.length} ${displayed.length == 1 ? _tr.t('home_result') : _tr.t('home_results')} ',
                      ),
                      TextSpan(
                        text: '"$_searchQuery"',
                        style: const TextStyle(color: AppTheme.accent),
                      ),
                    ],
                  ),
                )
              : Text(
                  _tr.t('saved_texts'),
                  style: const TextStyle(
                    fontSize: AppTheme.fontLG,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
        ),
        Expanded(
          child: displayed.isEmpty
              ? _buildNoResults()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: displayed.length,
                  itemBuilder: (ctx, i) {
                    final text = displayed[i];
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
                        setState(
                            () => _currentLang = _dataService.getLanguage());
                      },
                      onDelete: () => _deleteText(text.id),
                      onEditName: () => _editTextName(text),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.manage_search_rounded,
                size: 80, color: AppTheme.primary.withOpacity(0.20)),
            const SizedBox(height: 20),
            Text(
              '${_tr.t('home_no_named_entries')}\n"$_searchQuery"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontSM,
                color: AppTheme.textMedium,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tr.t('home_only_entries_with_name'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontXS,
                color: AppTheme.textLight,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
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
