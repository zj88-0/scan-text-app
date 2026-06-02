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
        title: Text(_tr.t('upgrade_title'), maxLines: 1, overflow: TextOverflow.ellipsis),
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


            // ── Standard tier card ────────────────────────────────────────────
            _buildTierCard(
              isSelected: !isPremium,
              icon: Icons.phone_android_rounded,
              iconColor: AppTheme.primary,
              title: _tr.t('upgrade_standard'),
              subtitle: _tr.t('upgrade_standard_sub'),
              features: [
                _tr.t('upgrade_std_feat_1'),
                _tr.t('upgrade_std_feat_2'),
                _tr.t('upgrade_std_feat_3'),
              ],
              badgeLabel: _tr.t('upgrade_current_plan'),
              badgeColor: AppTheme.success,
              showBadge: !isPremium,
              onTap: isPremium
                  ? () async {
                      await _premium.setFree();
                      setState(() {});
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_tr.t('upgrade_switched_std'))),
                      );
                    }
                  : null,
              buttonLabel: isPremium ? _tr.t('upgrade_switch_std_btn') : _tr.t('upgrade_active'),
              buttonStyle: _TierButtonStyle.outlined,
            ),

            const SizedBox(height: 16),

            // ── Premium tier card ─────────────────────────────────────────
            _buildTierCard(
              isSelected: isPremium,
              icon: Icons.auto_awesome_rounded,
              iconColor: AppTheme.accent,
              title: _tr.t('upgrade_premium'),
              subtitle: _tr.t('upgrade_premium_sub'),
              features: [
                _tr.t('upgrade_prem_feat_1'),
                _tr.t('upgrade_prem_feat_2'),
                _tr.t('upgrade_prem_feat_3'),
                _tr.t('upgrade_prem_feat_4'),
              ],
              badgeLabel: _tr.t('upgrade_current_plan'),
              badgeColor: AppTheme.accent,
              showBadge: isPremium,
              onTap: !isPremium
                  ? () async {
                      await _premium.setPremium();
                      setState(() {});
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(_tr.t('upgrade_switched_prem'))),
                      );
                    }
                  : null,
              buttonLabel: isPremium ? _tr.t('upgrade_active') : _tr.t('upgrade_switch_prem_btn'),
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
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
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
                        if (showBadge) _badge(badgeLabel, badgeColor),
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
          fontSize: AppTheme.fontXS,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _TierButtonStyle { elevated, outlined }
