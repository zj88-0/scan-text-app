import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
import 'services/ad_service.dart';
import 'widgets/global_language_icon.dart';
import 'widgets/language_selection_helper.dart';

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

  // Initialise AdMob SDK early so banner ads load as soon as the home screen
  // is displayed. This is the recommended approach per AdMob documentation.
  unawaited(AdService().initialize());

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

enum _Screen {
  loading,
  signedOut,
  awaitingVerification,
  modelSetup,
  onboarding,
  home
}

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
  String _statusText = '';
  String _statusKey = '';
  int _current = 0;
  int _total = 0;
  bool _modelSetupStarted = false;
  Set<String> _completedModels = {};
  bool _pausedForWifi = false;
  List<String> _missingCodes = [];
  int _downloadSessionId = 0;
  bool _startedOnMobile = false;

  bool _guestSeenOnboarding = false;

  // Email-verification polling
  Timer? _verificationTimer;
  StreamSubscription<User?>? _tokenSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FirebaseAuth.instance.userChanges().listen(_onAuthChanged);

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) async {
      if (!mounted) return;
      final hasWifi = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet) ||
          results.contains(ConnectivityResult.vpn);

      if (hasWifi && _screen == _Screen.modelSetup) {
        if (_pausedForWifi) {
          setState(() => _pausedForWifi = false);
          _checkModels();
        } else if (_downloading &&
            _missingCodes.isNotEmpty &&
            _startedOnMobile) {
          _startedOnMobile = false; // Prevent multiple restart loops
          // Pause and redownload on Wi-Fi for faster speeds
          setState(() {
            _statusKey = 'setup_switching_wifi';
          });

          await Future.wait(_missingCodes.map((code) async {
            if (!_completedModels.contains(code)) {
              await _mlkit.deleteModel(code);
            }
          }));

          if (!mounted) return;
          _checkModels();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _screen == _Screen.awaitingVerification) {
      _checkVerificationNow();
    }
  }

  Future<bool> _checkVerificationNow() async {
    final verified = await AuthService().reloadAndCheckVerified();
    if (!mounted) return true;
    if (verified) {
      _verificationTimer?.cancel();
      _verificationTimer = null;
      _tokenSub?.cancel();
      _tokenSub = null;
      final freshUser = FirebaseAuth.instance.currentUser;
      _onAuthChanged(freshUser);
      return true;
    }
    return false;
  }

  void _onAuthChanged(User? user) {
    if (!mounted) return;
    if (user == null) {
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
        _pausedForWifi = false;
        _statusText = AppTranslations().t('setup_checking_models');
        _current = 0;
        _total = 0;
      });
    } else {
      // Anonymous users skip email verification entirely.
      final isAnonymous = user.isAnonymous;

      // Email/password users must verify before proceeding.
      final isEmailProvider =
          user.providerData.any((p) => p.providerId == 'password');
      if (!isAnonymous && isEmailProvider && !user.emailVerified) {
        setState(() => _screen = _Screen.awaitingVerification);
        _startVerificationPolling();
        return;
      }
      _verificationTimer?.cancel();
      _verificationTimer = null;
      if (_screen == _Screen.home ||
          _screen == _Screen.onboarding ||
          _screen == _Screen.modelSetup) return;
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

    _tokenSub = FirebaseAuth.instance.idTokenChanges().listen((user) {
      if (user != null && user.emailVerified) _checkVerificationNow();
    });

    _verificationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_screen == _Screen.awaitingVerification) _checkVerificationNow();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _verificationTimer?.cancel();
    _tokenSub?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _checkModels() async {
    _downloadSessionId++;
    final int currentSession = _downloadSessionId;
    if (mounted) setState(() => _statusKey = 'setup_checking_models');

    final checks = await Future.wait(
      OnDeviceTranslationService.defaultLanguageCodes.map((code) async {
        final onDisk = await _mlkit.isModelDownloaded(code);
        final everHad = _mlkit.wasEverDownloaded(code);
        return (!onDisk && !everHad) ? code : null;
      }),
    );
    final missingCodes = checks.whereType<String>().toList();
    _missingCodes = missingCodes;

    if (!mounted || currentSession != _downloadSessionId) return;

    if (missingCodes.isEmpty) {
      _goNext();
      return;
    }

    setState(() {
      _checking = false;
      _waitingForWifi = true;
      _statusKey = 'setup_checking_conn';
    });

    if (!mounted || currentSession != _downloadSessionId) return;
    final proceed = await WiFiCheckService().checkAndConfirm(context);
    if (!mounted || currentSession != _downloadSessionId) return;

    if (!proceed) {
      setState(() {
        _waitingForWifi = false;
        _pausedForWifi = true;
        _checking = true;
        _statusKey = 'setup_waiting_wifi';
      });
      return;
    }

    final netResults = await Connectivity().checkConnectivity();
    final isWifiNow = netResults.contains(ConnectivityResult.wifi) ||
        netResults.contains(ConnectivityResult.ethernet) ||
        netResults.contains(ConnectivityResult.vpn);
    _startedOnMobile = !isWifiNow;

    setState(() {
      _waitingForWifi = false;
      _downloading = true;
      _total = missingCodes.length;
      _current = 0;
      _statusKey = 'setup_downloading';
      _completedModels = OnDeviceTranslationService.defaultLanguageCodes
          .where((c) => !missingCodes.contains(c))
          .toSet();
    });

    await _mlkit.ensureDefaultModels(
      alreadyMissing: missingCodes,
      onProgress: (code, current, total) {
        if (!mounted || currentSession != _downloadSessionId) return;
        setState(() {
          _current = current;
          _total = total;
          _completedModels.add(code);
          _statusKey = '';
          _statusText =
              '${AppTranslations().t('setup_downloaded')} ${_mlkit.displayName(code)} ($current ${AppTranslations().t('setup_of')} $total)…';
        });
      },
    );

    if (!mounted || currentSession != _downloadSessionId) return;
    setState(() {
      _done = true;
      _statusText = AppTranslations().t('setup_all_set');
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted && currentSession == _downloadSessionId) _goNext();
  }

  Future<void> _goNext() async {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user?.isAnonymous ?? false;

    bool seenOnboarding = false;
    try {
      if (!isGuest) {
        // Full user: run Firestore setup in parallel
        final results = await Future.wait([
          AuthService().ensureUserDocument(),
          AuthService().hasSeenOnboarding(),
        ]);
        seenOnboarding = results[1] as bool;
        // Fire-and-forget scan count sync for logged-in users
        DataService().syncScanCountFromRemote().catchError((_) {});
      } else {
        // Guest: no Firestore writes, scan count tracked locally only.
        // Show onboarding (terms) for guests too.
        seenOnboarding = _guestSeenOnboarding;
      }
    } catch (e) {
      debugPrint('[AppRoot] _goNext setup failed: $e');
    }

    if (!mounted) return;
    if (!seenOnboarding) {
      setState(() => _screen = _Screen.onboarding);
    } else {
      setState(() => _screen = _Screen.home);
    }
  }

  /// Called by OnboardingScreen when the user taps 'Acknowledge'.
  Future<void> _onOnboardingDone() async {
    final isGuest = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
    if (!isGuest) {
      // Only persist to Firestore for real accounts
      try {
        await AuthService().markOnboardingSeen();
      } catch (e) {
        debugPrint('[AppRoot] markOnboardingSeen failed: $e');
      }
    } else {
      _guestSeenOnboarding = true;
    }
    if (!mounted) return;
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
      case _Screen.onboarding:
        return OnboardingScreen(onDone: _onOnboardingDone);
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
    final _tr = AppTranslations();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/img/VisionAID_logo.png',
                      width: 220,
                    ),
                    if (_checking)
                      Text(
                        _statusKey.isNotEmpty ? _tr.t(_statusKey) : _statusText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSM,
                          color: AppTheme.textMedium,
                          height: 1.5,
                        ),
                      ),
                    if (_waitingForWifi)
                      Text(
                        _tr.t('setup_checking_conn'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSM,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    if (_downloading || _done) ...[
                      const SizedBox(height: 6),
                      Text(
                        _tr.t('setup_downloading'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSM,
                          color: AppTheme.textMedium,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    if (_checking || _downloading) ...[
                      LinearProgressIndicator(
                        value: _total > 0 ? _current / _total : null,
                        backgroundColor: AppTheme.cardBorder,
                        color: AppTheme.accent,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _statusKey.isNotEmpty ? _tr.t(_statusKey) : _statusText,
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
                        _statusKey.isNotEmpty ? _tr.t(_statusKey) : _statusText,
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
                        children: OnDeviceTranslationService
                            .defaultLanguageCodes
                            .map((code) {
                          final name = AppTranslations.languageNames[code] ??
                              _mlkit.displayName(code);
                          final isDone =
                              _done || _completedModels.contains(code);
                          return Chip(
                            avatar: isDone
                                ? const Icon(Icons.check_circle_rounded,
                                    size: 18, color: AppTheme.success)
                                : const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.primary),
                                  ),
                            label: Text(name,
                                style: TextStyle(
                                    fontSize: AppTheme.fontXS,
                                    color: isDone
                                        ? AppTheme.success
                                        : AppTheme.primary)),
                            backgroundColor: AppTheme.surface,
                            side: BorderSide(
                                color: isDone
                                    ? AppTheme.success
                                    : AppTheme.cardBorder),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: GlobalLanguageIcon(
                  fastLoad: true, onChanged: () => setState(() {})),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Verification waiting screen
// ════════════════════════════════════════════════════════════════════════════
class _VerificationWaitingScreen extends StatefulWidget {
  final Future<bool> Function() onCheckNow;
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
    if (navigated) return;

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
      SnackBar(
        content: Text(AppTranslations().t('verify_msg_resent')),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';
    final _tr = AppTranslations();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
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
                      Icons.mark_email_unread_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _tr.t('verify_title'),
                    style: const TextStyle(
                      fontSize: AppTheme.fontXL,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_tr.t('verify_desc_1')}\n$email\n\n${_tr.t('verify_desc_2')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSM,
                      color: AppTheme.textMedium,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _tr.t('verify_checking'),
                        style: const TextStyle(
                          fontSize: AppTheme.fontSM,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton.icon(
                      onPressed: _checking ? null : _handleProceed,
                      icon: _checking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 26),
                      label: Text(
                        _checking
                            ? _tr.t('verify_btn_check')
                            : _tr.t('verify_btn_continue'),
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
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      color: Color(0xFFD97706), size: 22),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _tr.t('verify_err_not_yet'),
                                      style: const TextStyle(
                                        color: Color(0xFFD97706),
                                        fontSize: AppTheme.fontXS,
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
                  OutlinedButton.icon(
                    onPressed: _checking ? null : _handleResend,
                    icon: const Icon(Icons.send_rounded, size: 24),
                    label: Text(_tr.t('verify_resend'),
                        style: const TextStyle(
                            fontSize: AppTheme.fontSM,
                            fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                      side:
                          const BorderSide(color: AppTheme.primary, width: 1.5),
                      foregroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _checking ? null : widget.onSignOut,
                    child: Text(
                      _tr.t('verify_diff_account'),
                      style: const TextStyle(
                          color: AppTheme.textMedium,
                          fontSize: AppTheme.fontXS),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: GlobalLanguageIcon(
                  fastLoad: true, onChanged: () => setState(() {})),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashLoading extends StatelessWidget {
  const _SplashLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GlobalLanguageIcon(
                fastLoad: true,
                onChanged: () {
                  // We do nothing on change since splash only shows logo,
                  // but we need the icon visible
                }),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/img/VisionAID_logo.png',
              width: 220,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppTheme.accent),
          ],
        ),
      ),
    );
  }
}
