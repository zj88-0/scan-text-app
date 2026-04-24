import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/data_service.dart';
import 'services/mlkit_translation_service.dart';
import 'services/premium_service.dart';
import 'services/translation_service.dart';
import 'services/tts_service.dart';
import 'services/wifi_check_service.dart';

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
      home: ModelGate(onLanguageChanged: _onLanguageChanged),
    );
  }
}

/// Shows a download progress screen if the 4 default models are not yet
/// on the device, then navigates to OnboardingScreen (first launch) or
/// HomeScreen (returning user) automatically when done.
class ModelGate extends StatefulWidget {
  final VoidCallback onLanguageChanged;
  const ModelGate({super.key, required this.onLanguageChanged});

  @override
  State<ModelGate> createState() => _ModelGateState();
}

class _ModelGateState extends State<ModelGate> {
  final OnDeviceTranslationService _mlkit = OnDeviceTranslationService();

  bool _checking = true;
  bool _downloading = false;
  bool _done = false;

  // Set to true when we are waiting for the user to confirm the wifi dialog.
  // While true the UI shows "Waiting for your confirmation…" instead of
  // the spinner, so it does not look frozen.
  bool _waitingForWifi = false;

  String _statusText = 'Checking language models…';
  int _current = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    int missing = 0;
    for (final code in OnDeviceTranslationService.defaultLanguageCodes) {
      if (!await _mlkit.isModelDownloaded(code)) missing++;
    }

    if (!mounted) return;

    if (missing == 0) {
      _goNext();
      return;
    }

    // ── Wi-Fi check before first-time download ────────────────────────────
    setState(() {
      _checking = false;
      _waitingForWifi = true;
      _statusText = 'Checking your connection…';
    });

    final proceed = await WiFiCheckService().checkAndConfirm(context);

    if (!mounted) return;

    if (!proceed) {
      // User chose to wait for Wi-Fi — keep showing the splash with a message.
      setState(() {
        _waitingForWifi = false;
        _checking = true;
        _statusText = 'Connect to Wi-Fi and reopen the app to continue.';
      });
      return;
    }

    // ── Start downloading ─────────────────────────────────────────────────
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

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) _goNext();
  }

  /// After models are ready, go to OnboardingScreen on first launch,
  /// or directly to HomeScreen for returning users.
  Future<void> _goNext() async {
    final seen = await OnboardingScreen.hasBeenSeen();
    if (!mounted) return;

    if (!seen) {
      // First launch — show onboarding.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              OnboardingScreen(onLanguageChanged: widget.onLanguageChanged),
        ),
      );
    } else {
      _goHome();
    }
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(onLanguageChanged: widget.onLanguageChanged),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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