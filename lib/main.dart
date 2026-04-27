import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/data_service.dart';
import 'services/mlkit_translation_service.dart';
import 'services/premium_service.dart';
import 'services/translation_service.dart';
import 'services/tts_service.dart';
import 'services/wifi_check_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await Firebase.initializeApp();
  await AuthService().restoreEncryptionIfSignedIn();

  await DataService().init();
  await AppTranslations().loadSaved();
  await TtsService().init();
  await OnDeviceTranslationService().init();
  await PremiumService().init();

  runApp(const ElderlyReaderApp());
}

class ElderlyReaderApp extends StatefulWidget {
  const ElderlyReaderApp({super.key});

  @override
  State<ElderlyReaderApp> createState() => _ElderlyReaderAppState();
}

class _ElderlyReaderAppState extends State<ElderlyReaderApp> {
  void _onLanguageChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppTranslations().t('app_name'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: AppRoot(onLanguageChanged: _onLanguageChanged),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// AppRoot owns all top-level state: auth + model setup + home.
// No pushReplacement is used for the main flow — swapping state here
// guarantees sign-out always returns to LoginScreen cleanly.
// ════════════════════════════════════════════════════════════════════════════

enum _Screen { loading, signedOut, awaitingVerification, modelSetup, home }

class AppRoot extends StatefulWidget {
  final VoidCallback onLanguageChanged;
  const AppRoot({super.key, required this.onLanguageChanged});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  _Screen _screen = _Screen.loading;

  final OnDeviceTranslationService _mlkit = OnDeviceTranslationService();

  // Model-download progress
  bool _checking = true;
  bool _downloading = false;
  bool _done = false;
  bool _waitingForWifi = false;
  String _statusText = 'Checking language models…';
  int _current = 0;
  int _total = 0;
  bool _modelSetupStarted = false;

  // Email-verification polling
  Timer? _verificationTimer;
  StreamSubscription<User?>? _tokenSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FirebaseAuth.instance.userChanges().listen(_onAuthChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _screen == _Screen.awaitingVerification) {
      _checkVerificationNow(); // fire and forget — result handled inside
    }
  }

  /// One-shot check: reloads the Firebase user and advances if verified.
  /// Returns true if the user was verified (and navigation was triggered),
  /// false if not verified yet.
  Future<bool> _checkVerificationNow() async {
    final verified = await AuthService().reloadAndCheckVerified();
    if (!mounted) return true; // widget gone, treat as navigated
    if (verified) {
      _verificationTimer?.cancel();
      _verificationTimer = null;
      _tokenSub?.cancel();
      _tokenSub = null;
      // Re-read currentUser AFTER reload so emailVerified is fresh.
      final freshUser = FirebaseAuth.instance.currentUser;
      _onAuthChanged(freshUser);
      return true;
    }
    return false;
  }

  void _onAuthChanged(User? user) {
    if (!mounted) return;
    if (user == null) {
      // Signed out — cancel any verification polling and reset to login
      _verificationTimer?.cancel();
      _verificationTimer = null;
      _tokenSub?.cancel();
      _tokenSub = null;
      setState(() {
        _screen = _Screen.signedOut;
        _modelSetupStarted = false;
        _checking = true;
        _downloading = false;
        _done = false;
        _waitingForWifi = false;
        _statusText = 'Checking language models…';
        _current = 0;
        _total = 0;
      });
    } else {
      // Google users are always considered verified.
      // Email/password users must verify before proceeding.
      final isEmailProvider = user.providerData
          .any((p) => p.providerId == 'password');
      if (isEmailProvider && !user.emailVerified) {
        setState(() => _screen = _Screen.awaitingVerification);
        _startVerificationPolling();
        return;
      }
      _verificationTimer?.cancel();
      _verificationTimer = null;
      // Guard: don't regress from home if userChanges fires again after setup.
      if (_screen == _Screen.home) return;
      setState(() => _screen = _Screen.modelSetup);
      if (!_modelSetupStarted) {
        _modelSetupStarted = true;
        _checkModels();
      }
    }
  }

  void _startVerificationPolling() {
    _verificationTimer?.cancel();
    _tokenSub?.cancel();

    // idTokenChanges fires the moment Firebase pushes a refreshed token —
    // which happens as soon as the backend marks the email verified.
    // This is the fast path: often arrives within a second of the user
    // clicking the link, with no reload() call needed.
    _tokenSub = FirebaseAuth.instance.idTokenChanges().listen((user) {
      if (user != null && user.emailVerified) _checkVerificationNow();
    });

    // Fallback poll every 2 s: reloads the user record in case the push
    // stream is unavailable (poor connectivity, etc.).
    _verificationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_screen == _Screen.awaitingVerification) _checkVerificationNow();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _verificationTimer?.cancel();
    _tokenSub?.cancel();
    super.dispose();
  }

  Future<void> _checkModels() async {
    int missing = 0;
    for (final code in OnDeviceTranslationService.defaultLanguageCodes) {
      if (!await _mlkit.isModelDownloaded(code)) missing++;
    }
    if (!mounted) return;

    if (missing == 0) {
      _goNext();
      return;
    }

    setState(() {
      _checking = false;
      _waitingForWifi = true;
      _statusText = 'Checking your connection…';
    });

    if (!mounted) return;
    final proceed = await WiFiCheckService().checkAndConfirm(context);
    if (!mounted) return;

    if (!proceed) {
      setState(() {
        _waitingForWifi = false;
        _checking = true;
        _statusText = 'Connect to Wi-Fi and reopen the app to continue.';
      });
      return;
    }

    setState(() {
      _waitingForWifi = false;
      _downloading = true;
      _total = missing;
      _statusText = 'Setting up translation…';
    });

    await _mlkit.ensureDefaultModels(
      onProgress: (code, current, total) {
        if (!mounted) return;
        setState(() {
          _current = current;
          _total = total;
          _statusText =
          'Downloading ${_mlkit.displayName(code)} ($current of $total)…';
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _done = true;
      _statusText = 'All set! Starting app…';
    });

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) _goNext();
  }

  Future<void> _goNext() async {
    // Guarantee the Firestore document exists — this is the definitive write
    // point. It runs after email verification for new users, and on every
    // sign-in for returning users. merge:true means it never downgrades tier.
    try {
      await AuthService().ensureUserDocument();
    } catch (e) {
      debugPrint('[AppRoot] ensureUserDocument failed: $e');
    }

    // Sync the authoritative scan count from Firestore into local cache so
    // HomeScreen's synchronous getFreeScanCount() is accurate from the start.
    DataService().syncScanCountFromRemote().catchError((_) {});

    final seen = await OnboardingScreen.hasBeenSeen();
    if (!mounted) return;
    if (!seen) {
      await OnboardingScreen.markSeen();
    }
    setState(() => _screen = _Screen.home);
  }

  @override
  Widget build(BuildContext context) {
    switch (_screen) {
      case _Screen.loading:
        return const _SplashLoading();
      case _Screen.signedOut:
        return const LoginScreen();
      case _Screen.awaitingVerification:
        return _buildVerificationWaiting();
      case _Screen.modelSetup:
        return _buildModelSetup();
      case _Screen.home:
        return PopScope(
          canPop: false,
          child: HomeScreen(onLanguageChanged: widget.onLanguageChanged),
        );
    }
  }

  Widget _buildVerificationWaiting() {
    return _VerificationWaitingScreen(
      onCheckNow: _checkVerificationNow,
      onResend: () async {
        await AuthService().sendVerificationEmail();
      },
      onSignOut: () async {
        await AuthService().signOut();
      },
    );
  }

  Widget _buildModelSetup() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.translate_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Text Scanner',
                style: TextStyle(
                  fontSize: AppTheme.fontXL,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              if (_checking)
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textMedium,
                    height: 1.5,
                  ),
                ),
              if (_waitingForWifi)
                const Text(
                  'Checking your connection…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textMedium,
                  ),
                ),
              if (_downloading || _done) ...[
                const SizedBox(height: 6),
                const Text(
                  'Downloading translation models.\nThis only happens once.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textMedium,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 40),
              if (_checking || _downloading) ...[
                LinearProgressIndicator(
                  value: (_total > 0 && _current > 0)
                      ? _current / _total
                      : null,
                  backgroundColor: AppTheme.cardBorder,
                  color: AppTheme.accent,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 20),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_done) ...[
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.success, size: 56),
                const SizedBox(height: 16),
                Text(
                  _statusText,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 48),
              if (_downloading || _done)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: OnDeviceTranslationService.defaultLanguageCodes
                      .map((code) {
                    final name = _mlkit.displayName(code);
                    return Chip(
                      avatar: const Icon(Icons.language_rounded,
                          size: 18, color: AppTheme.primary),
                      label: Text(name,
                          style: const TextStyle(
                              fontSize: 16, color: AppTheme.primary)),
                      backgroundColor: AppTheme.surface,
                      side: const BorderSide(color: AppTheme.cardBorder),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Verification waiting screen — shown after sign-up until email is confirmed.
// Auto-advance is handled by AppRoot (lifecycle observer + 4s poll).
// The "I've Verified" button is a manual fallback.
// ════════════════════════════════════════════════════════════════════════════
class _VerificationWaitingScreen extends StatefulWidget {
  final Future<bool> Function() onCheckNow; // true = verified+navigated
  final Future<void> Function() onResend;
  final Future<void> Function() onSignOut;

  const _VerificationWaitingScreen({
    required this.onCheckNow,
    required this.onResend,
    required this.onSignOut,
  });

  @override
  State<_VerificationWaitingScreen> createState() =>
      _VerificationWaitingScreenState();
}

class _VerificationWaitingScreenState
    extends State<_VerificationWaitingScreen> {
  bool _checking = false;
  bool _notVerifiedYet = false;

  Future<void> _handleProceed() async {
    if (!mounted) return;
    setState(() {
      _checking = true;
      _notVerifiedYet = false;
    });

    final navigated = await widget.onCheckNow();

    // If navigated == true, AppRoot has already swapped screens.
    // Don't touch state — this widget is about to be replaced.
    if (navigated) return;

    // Still not verified — show the amber nudge.
    if (mounted) {
      setState(() {
        _checking = false;
        _notVerifiedYet = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _notVerifiedYet = false);
      });
    }
  }

  Future<void> _handleResend() async {
    await widget.onResend();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification email resent.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email =
        FirebaseAuth.instance.currentUser?.email ?? 'your email';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Icon ─────────────────────────────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: AppTheme.fontXL,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to\n$email\n\n'
                    'Open the link in that email, then tap the button below.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppTheme.fontSM,
                  color: AppTheme.textMedium,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 36),

              // ── Auto-polling indicator ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Checking automatically…',
                    style: TextStyle(
                      fontSize: AppTheme.fontSM,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── "I've Verified" proceed button ────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _checking ? null : _handleProceed,
                  icon: _checking
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _checking ? 'Checking…' : "I've Verified — Continue",
                    style: const TextStyle(
                      fontSize: AppTheme.fontSM,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              // ── "Not verified yet" nudge ──────────────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: _notVerifiedYet
                    ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Color(0xFFD97706), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Email not verified yet. Please click the link in your inbox first.',
                            style: TextStyle(
                              color: Color(0xFFD97706),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 20),

              // ── Resend button ─────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: _checking ? null : _handleResend,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Resend Email'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: AppTheme.primary, width: 1.5),
                  foregroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Sign out link ─────────────────────────────────────────────
              TextButton(
                onPressed: _checking ? null : widget.onSignOut,
                child: const Text(
                  'Use a different account',
                  style: TextStyle(color: AppTheme.textMedium),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashLoading extends StatelessWidget {
  const _SplashLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      ),
    );
  }
}