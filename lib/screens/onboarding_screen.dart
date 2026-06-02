import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/data_service.dart';
import '../services/translation_service.dart';
import '../widgets/language_selector.dart';

/// OnboardingScreen — shown exactly once per user account, right after
/// the translation models finish downloading on a new install.
/// [onDone] is called when the user dismisses the screen; the caller
/// (AppRoot in main.dart) is responsible for persisting the seen status
/// and navigating to HomeScreen.
/// NOTE: Logic is unchanged — only the UI has been updated to show
/// Terms & Conditions.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _scrolledToBottom = false;
  final ScrollController _scrollController = ScrollController();
  final AppTranslations _tr = AppTranslations();
  final DataService _dataService = DataService();
  String _currentLang = 'en';

  @override
  void initState() {
    super.initState();
    _currentLang = _dataService.getLanguage();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _changeLanguage(String langCode) async {
    await _tr.load(langCode);
    setState(() => _currentLang = langCode);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrolledToBottom &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 60) {
      setState(() => _scrolledToBottom = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          _tr.t('terms_title'),
          style: const TextStyle(
            fontSize: AppTheme.fontLG,
            fontWeight: FontWeight.bold,
          ),
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
      body: SafeArea(
        child: Column(
          children: [
            // ── Scroll hint banner ────────────────────────────────────────
            if (!_scrolledToBottom)
              Container(
                width: double.infinity,
                color: AppTheme.accent.withOpacity(0.10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.swipe_down_rounded,
                        color: AppTheme.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _tr.t('terms_scroll_hint'),
                        style: const TextStyle(
                          fontSize: AppTheme.fontXS,
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Scrollable content ────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                children: [
                  // Header
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.gavel_rounded,
                          color: AppTheme.primary, size: 40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      _tr.t('terms_header'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: AppTheme.fontLG,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _tr.t('terms_last_updated'),
                      style: const TextStyle(
                        fontSize: AppTheme.fontXS,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  _buildSection(
                    icon: Icons.copyright_rounded,
                    iconColor: AppTheme.danger,
                    title: _tr.t('terms_sec8_title'),
                    body: _tr.t('terms_sec8_body'),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 1 ─────────────────────────────────────────
                  _buildSection(
                    icon: Icons.translate_rounded,
                    iconColor: AppTheme.accent,
                    title: _tr.t('terms_sec1_title'),
                    body: _tr.t('terms_sec1_body'),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 2 ─────────────────────────────────────────
                  _buildSection(
                    icon: Icons.privacy_tip_rounded,
                    iconColor: AppTheme.success,
                    title: _tr.t('terms_sec2_title'),
                    body: _tr.t('terms_sec2_body'),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 3 ─────────────────────────────────────────
                  _buildSection(
                    icon: Icons.image_not_supported_rounded,
                    iconColor: AppTheme.primary,
                    title: _tr.t('terms_sec3_title'),
                    body: _tr.t('terms_sec3_body'),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 4 ─────────────────────────────────────────
                  _buildSection(
                    icon: Icons.privacy_tip_rounded,
                    iconColor: AppTheme.success,
                    title: _tr.t('terms_sec4_title'),
                    body: _tr.t('terms_sec4_body'),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 5 ─────────────────────────────────────────
                  _buildSection(
                    icon: Icons.account_circle_rounded,
                    iconColor: AppTheme.accent,
                    title: _tr.t('terms_sec5_title'),
                    body: _tr.t('terms_sec5_body'),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 6 ─────────────────────────────────────────
                  _buildSection(
                    icon: Icons.update_rounded,
                    iconColor: AppTheme.primary,
                    title: _tr.t('terms_sec6_title'),
                    body: _tr.t('terms_sec6_body'),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 7 ─────────────────────────────────────────
                  _buildSection(
                    icon: Icons.shield_rounded,
                    iconColor: AppTheme.success,
                    title: _tr.t('terms_sec7_title'),
                    body: _tr.t('terms_sec7_body'),
                  ),

                  const SizedBox(height: 12),

                  // ── Acknowledge note ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.2), width: 1.5),
                    ),
                    child: Text(
                      _tr.t('terms_ack_note'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: AppTheme.fontXS,
                        color: AppTheme.textMedium,
                        height: 1.7,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── CTA Button ────────────────────────────────────────
                  ElevatedButton.icon(
                    onPressed: widget.onDone,
                    icon: const Icon(Icons.check_circle_rounded, size: 28),
                    label: Text(_tr.t('terms_ack_btn')),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 68),
                      textStyle: const TextStyle(
                        fontSize: AppTheme.fontMD,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + title
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Body text
          Text(
            body,
            style: const TextStyle(
              fontSize: AppTheme.fontSM,
              color: AppTheme.textMedium,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
