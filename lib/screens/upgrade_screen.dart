import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/premium_service.dart';
import '../services/translation_service.dart';

/// UpgradeScreen — lets the user switch between Free and Premium tiers.
/// Moved here from SettingsScreen to keep settings clean.
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  final PremiumService _premium = PremiumService();
  final AppTranslations _tr = AppTranslations();

  @override
  Widget build(BuildContext context) {
    final isPremium = _premium.isPremium;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Upgrade Plan'),
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
            // ── Info banner ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.2), width: 1.5),
              ),
              child: const Text(
                'Choose how the app translates your scanned text.\n\n'
                '• Free  — translations happen immediately using system models. '
                'Fast and works without internet after the first setup. '
                'Limited to 3 scans per day.\n\n'
                '• Premium  — translations are done by AI and are natural '
                'and context-aware. Only the language you select is translated. '
                'Results are cached locally, translated once per scan. Unlimited scans.',
                style: TextStyle(
                  fontSize: AppTheme.fontXS,
                  color: AppTheme.textMedium,
                  height: 1.6,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Free tier card ────────────────────────────────────────────
            _buildTierCard(
              isSelected: !isPremium,
              icon: Icons.phone_android_rounded,
              iconColor: AppTheme.primary,
              title: 'Free',
              subtitle: 'On-device translation · Works offline',
              features: const [
                'Instant translation for all languages',
                'Direct word-for-word translation',
                '3 scans per day',
              ],
              badgeLabel: 'Current Plan',
              badgeColor: AppTheme.success,
              showBadge: !isPremium,
              onTap: isPremium
                  ? () async {
                      await _premium.setFree();
                      setState(() {});
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Switched to Free tier.')),
                      );
                    }
                  : null,
              buttonLabel: isPremium ? 'Switch to Free' : 'Active',
              buttonStyle: _TierButtonStyle.outlined,
            ),

            const SizedBox(height: 16),

            // ── Premium tier card ─────────────────────────────────────────
            _buildTierCard(
              isSelected: isPremium,
              icon: Icons.auto_awesome_rounded,
              iconColor: AppTheme.accent,
              title: 'Premium',
              subtitle: 'AI translation · Natural & context-aware',
              features: const [
                'Natural, fluent translations',
                'Names & abbreviations handled intelligently',
                'Results cached locally',
                'Unlimited scans',
              ],
              badgeLabel: 'Current Plan',
              badgeColor: AppTheme.accent,
              showBadge: isPremium,
              onTap: !isPremium
                  ? () async {
                      await _premium.setPremium();
                      setState(() {});
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Switched to Premium AI translation!')),
                      );
                    }
                  : null,
              buttonLabel: isPremium ? 'Active' : 'Switch to Premium',
              buttonStyle: _TierButtonStyle.elevated,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard({
    required bool isSelected,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<String> features,
    required String badgeLabel,
    required Color badgeColor,
    required bool showBadge,
    required VoidCallback? onTap,
    required String buttonLabel,
    required _TierButtonStyle buttonStyle,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: isSelected ? iconColor.withOpacity(0.05) : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? iconColor : AppTheme.cardBorder,
          width: isSelected ? 2.5 : 1.5,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: AppTheme.fontMD,
                            fontWeight: FontWeight.bold,
                            color:
                                isSelected ? iconColor : AppTheme.textDark,
                          ),
                        ),
                        if (showBadge) ...[
                          const SizedBox(width: 8),
                          _badge(badgeLabel, badgeColor),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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

          const SizedBox(height: 14),

          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_rounded, size: 18, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        fontSize: AppTheme.fontXS,
                        color: AppTheme.textDark,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: buttonStyle == _TierButtonStyle.elevated
                ? ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          onTap == null ? AppTheme.textLight : iconColor,
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSM,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: onTap == null
                            ? AppTheme.textLight
                            : AppTheme.primary,
                        width: 2,
                      ),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSM,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
}

enum _TierButtonStyle { elevated, outlined }
