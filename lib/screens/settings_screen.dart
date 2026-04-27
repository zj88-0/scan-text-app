import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/data_service.dart';
import '../services/mlkit_translation_service.dart';
import '../services/premium_service.dart';
import '../services/translation_service.dart';
import '../services/wifi_check_service.dart';
import '../services/auth_service.dart';
import 'voice_selection_screen.dart';

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
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.danger, size: 28),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                fontSize: AppTheme.fontMD,
                fontWeight: FontWeight.bold,
                color: AppTheme.danger,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(fontSize: AppTheme.fontSM, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(minimumSize: const Size(100, 52)),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              minimumSize: const Size(100, 52),
            ),
            child: const Text('Sign Out'),
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
  Set<String> _deleting = {};

  static const int _maxActive = 4;
  static const int _freeDailyLimit = 3;

  @override
  void initState() {
    super.initState();
    _configuredLanguages = List.from(_mlkit.configuredLanguages);
    _activeLanguages = List.from(_mlkit.configuredLanguages);
    _refreshDownloadStatus();
  }

  Future<void> _refreshDownloadStatus() async {
    final status = <String, bool>{};
    for (final code in _configuredLanguages) {
      status[code] = await _mlkit.isModelDownloaded(code);
    }
    if (mounted) setState(() => _downloadStatus = status);
  }

  // ── Language model actions ────────────────────────────────────────────────

  Future<void> _toggleActive(String code) async {
    final isActive = _activeLanguages.contains(code);

    if (isActive) {
      if (_activeLanguages.length <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need at least one active language.'),
            backgroundColor: AppTheme.danger,
          ),
        );
        return;
      }
      final newActive =
      _activeLanguages.where((c) => c != code).toList();
      await _mlkit.setConfiguredLanguages(newActive);
      setState(() => _activeLanguages = newActive);
    } else {
      if (_activeLanguages.length >= _maxActive) {
        _showMaxLanguagesDialog();
        return;
      }
      final newActive = [..._activeLanguages, code];
      await _mlkit.setConfiguredLanguages(newActive);
      setState(() => _activeLanguages = newActive);
    }
  }

  void _showMaxLanguagesDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: const Text(
          'Maximum 4 Languages',
          style: TextStyle(
            fontSize: AppTheme.fontMD,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        content: const Text(
          'You can have up to 4 active languages at a time.\n\n'
              'Please deselect one language before adding another.',
          style: TextStyle(fontSize: AppTheme.fontSM, height: 1.6),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56)),
            child:
            const Text('OK', style: TextStyle(fontSize: AppTheme.fontSM)),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadModel(String code) async {
    if (!mounted) return;
    final proceed = await _wifiCheck.checkAndConfirm(context);
    if (!proceed) return;

    setState(() => _downloading.add(code));
    await _mlkit.downloadModel(code);
    final downloaded = await _mlkit.isModelDownloaded(code);
    if (mounted) {
      setState(() {
        _downloading.remove(code);
        _downloadStatus[code] = downloaded;
      });
    }
  }

  Future<void> _deleteModel(String code) async {
    if (_configuredLanguages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need at least one language.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove Language',
          style: TextStyle(
              fontSize: AppTheme.fontMD, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remove ${_mlkit.displayName(code)} from your language list and '
              'delete its translation model from this device?',
          style: const TextStyle(fontSize: AppTheme.fontSM, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(100, 52)),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              minimumSize: const Size(100, 52),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting.add(code));
    await _mlkit.deleteModel(code);

    final newConfigured =
    _configuredLanguages.where((c) => c != code).toList();
    final newActive = _activeLanguages.where((c) => c != code).toList();
    await _mlkit.setConfiguredLanguages(newActive);

    if (mounted) {
      setState(() {
        _deleting.remove(code);
        _configuredLanguages = newConfigured;
        _activeLanguages = newActive;
        _downloadStatus.remove(code);
      });
    }
  }

  Future<void> _addLanguage(String code) async {
    if (_configuredLanguages.contains(code)) return;

    if (!mounted) return;
    final proceed = await _wifiCheck.checkAndConfirm(context);
    if (!proceed) return;

    final newConfigured = [..._configuredLanguages, code];
    List<String> newActive = List.from(_activeLanguages);
    if (newActive.length < _maxActive) {
      newActive.add(code);
    }

    await _mlkit.setConfiguredLanguages(newActive);
    setState(() {
      _configuredLanguages = newConfigured;
      _activeLanguages = newActive;
      _downloadStatus[code] = false;
    });

    await _downloadModel(code);
  }

  List<DropdownMenuItem<String>> _buildAddLanguageItems() {
    final available =
    OnDeviceTranslationService.allSupportedLanguages.entries
        .where((e) => !_configuredLanguages.contains(e.key))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return available
        .map((e) => DropdownMenuItem(
      value: e.key,
      child: Text(e.value,
          style: const TextStyle(fontSize: AppTheme.fontXS)),
    ))
        .toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr.t('settings')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Voice Settings ────────────────────────────────────────────
            _sectionTitle(
                Icons.record_voice_over_rounded, _tr.t('voice_settings')),
            const SizedBox(height: 12),
            _buildVoiceSettingsCard(),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            // ── Daily Scans ───────────────────────────────────────────────
            _sectionTitle(Icons.document_scanner_rounded, 'Daily Scans'),
            const SizedBox(height: 12),
            _buildDailyScansCard(),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            // ── Translation Languages ─────────────────────────────────────
            _sectionTitle(
                Icons.translate_rounded, 'Translation Languages'),
            const SizedBox(height: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.accent.withOpacity(0.3), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppTheme.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Select up to $_maxActive languages to show in the app. '
                          'Models are stored on your device — no internet needed after download.',
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
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _activeLanguages.length >= _maxActive
                      ? AppTheme.accent.withOpacity(0.15)
                      : AppTheme.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_activeLanguages.length} / $_maxActive active',
                  style: TextStyle(
                    fontSize: AppTheme.fontXS,
                    fontWeight: FontWeight.bold,
                    color: _activeLanguages.length >= _maxActive
                        ? AppTheme.accent
                        : AppTheme.success,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            ..._configuredLanguages.map((code) => _buildLanguageCard(code)),

            const SizedBox(height: 12),
            _buildAddLanguageRow(),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            // ── Account ───────────────────────────────────────────────────
            _sectionTitle(Icons.account_circle_rounded, 'Account'),
            const SizedBox(height: 12),
            _buildLogoutButton(),

            const SizedBox(height: 40),
          ],
        ),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unlimited Scans',
                        style: TextStyle(
                          fontSize: AppTheme.fontMD,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Premium plan — no daily limit',
                        style: TextStyle(
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
            // Free — show usage bar
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
                    color: remaining == 0 ? AppTheme.danger : AppTheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$remaining of $limit scans left today',
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
                        'Resets at midnight • Free plan',
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
                Text(
                  '$usedToday used',
                  style: const TextStyle(
                    fontSize: AppTheme.fontXS,
                    color: AppTheme.textMedium,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$limit total',
                  style: const TextStyle(
                    fontSize: AppTheme.fontXS,
                    color: AppTheme.textLight,
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
    final voiceName = _dataService.getPreferredVoiceName();
    final voiceLocale = _dataService.getPreferredVoiceLocale();
    final hasVoice = voiceName != null;

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
                      ? _friendlyName(voiceName!)
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

  String _friendlyName(String raw) {
    return raw
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 26),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: AppTheme.fontMD,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageCard(String code) {
    final name = _mlkit.displayName(code);
    final isDownloaded = _downloadStatus[code] ?? false;
    final isDownloading = _downloading.contains(code);
    final isDeleting = _deleting.contains(code);
    final isDefault =
    OnDeviceTranslationService.defaultLanguageCodes.contains(code);
    final isActive = _activeLanguages.contains(code);
    final atCap = _activeLanguages.length >= _maxActive;
    final everHad = _mlkit.wasEverDownloaded(code);
    final wasDeletedByUser = everHad && !isDownloaded && !isDownloading;

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
                        if (isDefault) _badge('Default', AppTheme.accent),
                        if (isActive) _badge('Active', AppTheme.success),
                        if (wasDeletedByUser)
                          _badge('Removed', AppTheme.danger),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isDownloaded
                          ? 'Model ready — on this device'
                          : isDownloading
                          ? 'Downloading…'
                          : wasDeletedByUser
                          ? 'Removed — tap Download to restore'
                          : 'Not yet downloaded',
                      style: TextStyle(
                        fontSize: AppTheme.fontXS,
                        color: isDownloaded
                            ? AppTheme.success
                            : isDownloading
                            ? AppTheme.accent
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
          if (isDownloading || isDeleting)
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
                Expanded(
                  child: GestureDetector(
                    onTap: () => _toggleActive(code),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.primary
                            : (!atCap
                            ? AppTheme.primary.withOpacity(0.08)
                            : AppTheme.textLight.withOpacity(0.08)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? AppTheme.primary
                              : (!atCap
                              ? AppTheme.primary.withOpacity(0.5)
                              : AppTheme.textLight),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isActive
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 22,
                            color: isActive
                                ? Colors.white
                                : (!atCap
                                ? AppTheme.primary
                                : AppTheme.textLight),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isActive ? 'Selected' : 'Select',
                            style: TextStyle(
                              fontSize: AppTheme.fontXS,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? Colors.white
                                  : (!atCap
                                  ? AppTheme.primary
                                  : AppTheme.textLight),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download_rounded,
                                color: AppTheme.accent, size: 22),
                            SizedBox(width: 6),
                            Text(
                              'Download',
                              style: TextStyle(
                                fontSize: AppTheme.fontXS,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent,
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
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_rounded,
                                color: AppTheme.danger, size: 22),
                            SizedBox(width: 6),
                            Text(
                              'Remove',
                              style: TextStyle(
                                fontSize: AppTheme.fontXS,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.danger,
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
          fontSize: 12,
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
        icon: const Icon(Icons.logout_rounded, color: AppTheme.danger, size: 24),
        label: const Text(
          'Sign Out',
          style: TextStyle(
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

  Widget _buildAddLanguageRow() {
    final items = _buildAddLanguageItems();
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppTheme.primary.withOpacity(0.3),
            width: 1.5,
            style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          const Icon(Icons.add_circle_outline_rounded,
              color: AppTheme.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: null,
                hint: const Text(
                  'Add a language…',
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textLight,
                  ),
                ),
                isExpanded: true,
                items: items,
                onChanged: (val) {
                  if (val != null) _addLanguage(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}