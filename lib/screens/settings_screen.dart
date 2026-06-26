import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/data_service.dart';
import '../services/mlkit_translation_service.dart';
import '../services/premium_service.dart';
import '../services/translation_service.dart';
import '../services/wifi_check_service.dart';
import '../services/auth_service.dart';
import 'voice_selection_screen.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DataService _dataService = DataService();
  final AppTranslations _tr = AppTranslations();
  final OnDeviceTranslationService _mlkit = OnDeviceTranslationService();
  final WiFiCheckService _wifiCheck = WiFiCheckService();
  final PremiumService _premium = PremiumService();
  final AuthService _auth = AuthService();

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppTheme.danger, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _tr.t('settings_sign_out'),
                style: const TextStyle(
                  fontSize: AppTheme.fontMD,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.danger,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          _tr.t('settings_sign_out_prompt'),
          style: const TextStyle(fontSize: AppTheme.fontSM, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(minimumSize: const Size(100, 52)),
            child: Text(_tr.t('settings_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              minimumSize: const Size(100, 52),
            ),
            child: Text(_tr.t('settings_sign_out')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _auth.signOut();
    // Pop every pushed route so AppRoot (which sits at the bottom of the
    // navigator stack) is revealed. AppRoot rebuilds to LoginScreen when
    // authStateChanges fires with null.
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  List<String> _configuredLanguages = [];
  List<String> _activeLanguages = [];
  Map<String, bool> _downloadStatus = {};
  Set<String> _downloading = {};
  Set<String> _translating = {};
  Set<String> _deleting = {};

  // Whether the initial parallel status check is still running.
  bool _statusLoading = true;

  // Scan mode: 'ai' or 'local'
  String _scanMode = 'ai';

  static const int _maxActive = 4;
  static const int _freeDailyLimit = 3;

  @override
  void initState() {
    super.initState();
    _configuredLanguages = List.from(_mlkit.configuredLanguages);
    _activeLanguages = List.from(_mlkit.configuredLanguages);
    _scanMode = _dataService.getScanMode();
    _refreshDownloadStatus();
  }

  /// Checks all model download states IN PARALLEL so the settings screen
  /// is fast even for guest users who have never touched Firestore.
  ///
  /// Previously this used a sequential `for` loop which caused every
  /// ML Kit call to block the next, adding noticeable latency for guests.
  Future<void> _refreshDownloadStatus() async {
    if (!mounted) return;
    setState(() => _statusLoading = true);

    // Fire all isModelDownloaded calls simultaneously.
    final codes = List<String>.from(_configuredLanguages);
    final results = await Future.wait(
      codes.map((code) async {
        final downloaded = await _mlkit.isModelDownloaded(code);
        return MapEntry(code, downloaded);
      }),
    );

    if (!mounted) return;
    setState(() {
      _downloadStatus = Map.fromEntries(results);
      _statusLoading = false;
    });
  }

  // Language selection is now fixed to the 4 common languages.
  // We only allow downloading/deleting models.



  Future<void> _downloadModel(String code) async {
    if (!mounted) return;
    final proceed = await _wifiCheck.checkAndConfirm(context);
    if (!proceed) return;

    setState(() => _downloading.add(code));
    await _mlkit.downloadModel(code);
    
    if (mounted) {
      setState(() {
        _downloading.remove(code);
        _translating.add(code);
      });
    }

    try {
      await AppTranslations().preTranslate(code);
    } catch (_) {}

    final downloaded = await _mlkit.isModelDownloaded(code);
    if (mounted) {
      setState(() {
        _translating.remove(code);
        _downloadStatus[code] = downloaded;
      });
    }
  }

  Future<void> _deleteModel(String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(
          _tr.t('settings_remove_lang'),
          style: const TextStyle(
              fontSize: AppTheme.fontMD, fontWeight: FontWeight.bold),
        ),
        content: Text(
          _tr.t('settings_remove_lang_desc'),
          style: const TextStyle(fontSize: AppTheme.fontSM, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(100, 52)),
            child: Text(_tr.t('settings_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              minimumSize: const Size(100, 52),
            ),
            child: Text(_tr.t('settings_remove')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting.add(code));
    await _mlkit.deleteModel(code);
    await AppTranslations().clearCache(code);

    if (mounted) {
      setState(() {
        _deleting.remove(code);
        _downloadStatus[code] = false;
      });
    }
  }



  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr.t('settings'), maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _statusLoading
          ? _buildStatusLoading()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Voice Settings ──────────────────────────────────────
            _sectionTitle(
                Icons.record_voice_over_rounded,
                _tr.t('voice_settings')),
            const SizedBox(height: 12),
            _buildVoiceSettingsCard(),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            // ── Auto Read Settings ──────────────────────────────────
            _sectionTitle(
                Icons.volume_up_rounded, 'Auto Read'),
            const SizedBox(height: 12),
            _buildAutoReadCard(),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            // ── Daily Scans ─────────────────────────────────────────
            _sectionTitle(
                Icons.document_scanner_rounded, _tr.t('settings_daily_scans')),
            const SizedBox(height: 12),
            _buildDailyScansCard(),

            const SizedBox(height: 20),

            // ── Scan Mode ───────────────────────────────────────────────
            _sectionTitle(
                Icons.settings_input_antenna_rounded,
                _tr.t('settings_scan_mode')),
            const SizedBox(height: 12),
            _buildScanModeCard(),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            // ── Translation Languages ───────────────────────────────
            _sectionTitle(
                Icons.translate_rounded, _tr.t('settings_translation_languages')),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.accent.withOpacity(0.3),
                    width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppTheme.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _tr.t('settings_lang_desc'),
                      style: const TextStyle(
                        fontSize: AppTheme.fontXS,
                        color: AppTheme.textMedium,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 10),

            ..._configuredLanguages
                .map((code) => _buildLanguageCard(code)),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            // ── Account ─────────────────────────────────────────────
            _sectionTitle(
                Icons.account_circle_rounded, _tr.t('settings_account')),
            const SizedBox(height: 12),
            _buildLogoutButton(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Lightweight loading indicator shown only while the parallel model-status
  /// check is in flight (typically < 300 ms, even for guests).
  Widget _buildStatusLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:  [
          CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 3),
          SizedBox(height: 20),
          Text(
            _tr.t('settings_loading'),
            style: const TextStyle(
              fontSize: AppTheme.fontSM,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  // ── Scan mode card ────────────────────────────────────────────────────────

  Widget _buildScanModeCard() {
    final isAi = _scanMode == 'ai';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr.t('settings_scan_mode_desc'),
            style: const TextStyle(
              fontSize: AppTheme.fontXS,
              color: AppTheme.textMedium,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // ── AI Scan tile ─────────────────────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await _dataService.setScanMode('ai');
                    setState(() => _scanMode = 'ai');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isAi
                          ? AppTheme.primary
                          : AppTheme.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAi
                            ? AppTheme.primary
                            : AppTheme.primary.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_rounded,
                          size: 28,
                          color: isAi ? Colors.white : AppTheme.primary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _tr.t('settings_scan_mode_ai'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppTheme.fontXS,
                            fontWeight: FontWeight.bold,
                            color: isAi ? Colors.white : AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tr.t('settings_scan_mode_ai_sub'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppTheme.fontXS - 1,
                            color: isAi
                                ? Colors.white.withOpacity(0.8)
                                : AppTheme.textLight,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isAi) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _tr.t('upgrade_active'),
                              style: const TextStyle(
                                fontSize: AppTheme.fontXS,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ── Local Scan tile ──────────────────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await _dataService.setScanMode('local');
                    setState(() => _scanMode = 'local');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 10),
                    decoration: BoxDecoration(
                      color: !isAi
                          ? AppTheme.accent
                          : AppTheme.accent.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !isAi
                            ? AppTheme.accent
                            : AppTheme.accent.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.phone_android_rounded,
                          size: 28,
                          color: !isAi ? Colors.white : AppTheme.accent,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _tr.t('settings_scan_mode_local'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppTheme.fontXS,
                            fontWeight: FontWeight.bold,
                            color: !isAi ? Colors.white : AppTheme.accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tr.t('settings_scan_mode_local_sub'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppTheme.fontXS - 1,
                            color: !isAi
                                ? Colors.white.withOpacity(0.8)
                                : AppTheme.textLight,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isAi) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _tr.t('upgrade_active'),
                              style: const TextStyle(
                                fontSize: AppTheme.fontXS,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Auto Read Settings ────────────────────────────────────────────────────

  Widget _buildAutoReadCard() {
    final autoRead = _dataService.getAutoRead();
    final startMuted = _dataService.getStartMuted();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder, width: 1.5),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: autoRead,
            onChanged: (val) async {
              await _dataService.setAutoRead(val);
              setState(() {});
            },
            title: Text(_tr.t('settings_auto_read'), style: const TextStyle(fontSize: AppTheme.fontSM, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            subtitle: Text(_tr.t('settings_auto_read_desc'), style: const TextStyle(fontSize: AppTheme.fontXS, color: AppTheme.textMedium)),
            activeColor: AppTheme.primary,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            value: startMuted,
            onChanged: (val) async {
              await _dataService.setStartMuted(val);
              setState(() {});
            },
            title: Text(_tr.t('settings_start_muted'), style: const TextStyle(fontSize: AppTheme.fontSM, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            subtitle: Text(_tr.t('settings_start_muted_desc'), style: const TextStyle(fontSize: AppTheme.fontXS, color: AppTheme.textMedium)),
            activeColor: AppTheme.danger,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
          ),
        ],
      ),
    );
  }

  // ── Daily scans card ──────────────────────────────────────────────────────

  Widget _buildDailyScansCard() {
    final isPremium = _premium.isPremium;
    final usedToday = _dataService.getFreeScanCount();
    final limit = _freeDailyLimit;
    final remaining = (limit - usedToday).clamp(0, limit);
    final fraction = (usedToday / limit).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPremium) ...[
            // Premium — unlimited
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.all_inclusive_rounded,
                      color: AppTheme.accent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tr.t('settings_unlimited'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTheme.fontMD,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _tr.t('settings_premium_plan'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTheme.fontXS,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            // Free / Guest — show usage bar
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: remaining == 0
                        ? AppTheme.danger.withOpacity(0.12)
                        : AppTheme.primary.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.document_scanner_rounded,
                    color:
                    remaining == 0 ? AppTheme.danger : AppTheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$remaining ${_tr.t("home_of")} $limit ${_tr.t("home_scans_left")}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTheme.fontMD,
                          fontWeight: FontWeight.bold,
                          color: remaining == 0
                              ? AppTheme.danger
                              : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _tr.t('settings_free_plan_reset'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTheme.fontXS,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 14,
                backgroundColor: AppTheme.cardBorder,
                color: remaining == 0 ? AppTheme.danger : AppTheme.accent,
              ),
            ),

            const SizedBox(height: 10),

            // Used / total label row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '$usedToday ${_tr.t("settings_used")}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTheme.fontXS,
                      color: AppTheme.textMedium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    '$limit ${_tr.t("settings_total")}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTheme.fontXS,
                      color: AppTheme.textLight,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Voice settings card ───────────────────────────────────────────────────

  Widget _buildVoiceSettingsCard() {
    final voiceName   = _dataService.getPreferredVoiceName();
    final voiceLocale = _dataService.getPreferredVoiceLocale();
    final hasVoice    = voiceName != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.record_voice_over_rounded,
                color: AppTheme.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasVoice
                      ? _friendlyName(voiceLocale)
                      : _tr.t('voice_default'),
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  hasVoice
                      ? (voiceLocale ?? '')
                      : _tr.t('voice_default_hint'),
                  style: const TextStyle(
                    fontSize: AppTheme.fontXS,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const VoiceSelectionScreen()),
              );
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              hasVoice ? _tr.t('voice_change') : _tr.t('voice_select'),
              style: const TextStyle(
                  fontSize: AppTheme.fontXS, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyName(String? locale) {
    if (locale == null || locale.isEmpty) return _tr.t('voice_default');
    
    final parts = locale.split(RegExp(r'[-_]'));
    if (parts.length > 1) {
      String region = parts[1];
      for (int i = 1; i < parts.length; i++) {
        if (parts[i].length == 2) {
          region = parts[i];
          break;
        }
      }
      region = region.toUpperCase();
      if (region == 'GB') region = 'UK';
      return '$region ${_tr.t('voice_number')}';
    }
    return '${parts.first.toUpperCase()} ${_tr.t('voice_number')}';
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTheme.fontMD,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageCard(String code) {
    final name          = _mlkit.displayName(code);
    final isDownloaded  = _downloadStatus[code] ?? false;
    final isDownloading = _downloading.contains(code);
    final isTranslating = _translating.contains(code);
    final isDeleting    = _deleting.contains(code);
    final isDefault =
    OnDeviceTranslationService.defaultLanguageCodes.contains(code);
    final isActive          = _activeLanguages.contains(code);
    final atCap             = _activeLanguages.length >= _maxActive;
    final everHad           = _mlkit.wasEverDownloaded(code);
    final wasDeletedByUser  = everHad && !isDownloaded && !isDownloading && !isTranslating;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primary.withOpacity(0.04)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppTheme.primary : AppTheme.cardBorder,
          width: isActive ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDownloaded
                      ? AppTheme.success
                      : AppTheme.textLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSM,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        if (isDefault) _badge(_tr.t('voice_default'), AppTheme.accent),
                        if (isActive)  _badge(_tr.t('settings_active'), AppTheme.success),
                        if (isDownloading || isTranslating)
                          _badge(_tr.t('settings_downloading'), AppTheme.accent)
                        else if (wasDeletedByUser)
                          _badge(_tr.t('settings_removed'), AppTheme.danger),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isTranslating
                          ? _tr.t('setup_setting_up')
                          : isDownloaded
                              ? _tr.t('settings_model_ready')
                              : isDownloading
                                  ? _tr.t('settings_downloading')
                                  : wasDeletedByUser
                                      ? _tr.t('settings_removed_restore')
                                      : _tr.t('settings_not_downloaded'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTheme.fontXS,
                        color: isTranslating || isDownloading
                            ? AppTheme.accent
                            : isDownloaded
                                ? AppTheme.success
                                : wasDeletedByUser
                                    ? AppTheme.danger
                                    : AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isDownloading || isTranslating || isDeleting)
            const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: AppTheme.accent),
              ),
            )
          else
            Row(
              children: [
                if (!isDownloaded)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _downloadModel(code),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.accent, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download_rounded,
                                color: AppTheme.accent, size: 22),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _tr.t('settings_download'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: AppTheme.fontXS,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _deleteModel(code),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.danger, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_rounded,
                                color: AppTheme.danger, size: 22),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _tr.t('settings_remove'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: AppTheme.fontXS,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTheme.fontXS,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon:
        const Icon(Icons.logout_rounded, color: AppTheme.danger, size: 24),
        label: Text(
          _tr.t('settings_sign_out'),
          style: const TextStyle(
            fontSize: AppTheme.fontSM,
            fontWeight: FontWeight.bold,
            color: AppTheme.danger,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: AppTheme.danger, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }


}