import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/translation_service.dart';

/// OnboardingScreen — shown exactly once per user account, right after
/// the translation models finish downloading on a new install.
/// [onDone] is called when the user dismisses the screen; the caller
/// (AppRoot in main.dart) is responsible for persisting the seen status
/// and navigating to HomeScreen.
class OnboardingScreen extends StatelessWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              // ── Title ──────────────────────────────────────────────────
              const Text(
                'APP INFO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.fontXL,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),

              const SizedBox(height: 28),

              // ── Point 1 ───────────────────────────────────────────────
              const _InfoCard(
                icon: Icons.translate_rounded,
                iconColor: AppTheme.accent,
                title: 'Translations May Not Be Perfect',
                body:
                'AI can make mistakes. Translations may not always be '
                    '100% accurate.',
              ),

              const SizedBox(height: 16),

              const _InfoCard(
                icon: Icons.translate_rounded,
                iconColor: AppTheme.accent,
                title: 'Text saved store locally',
                body:
                'Text not saved online only you can view them. '
                    'However, saved text does not share across different devices',
              ),

              const SizedBox(height: 16),

              // ── Point 2 ───────────────────────────────────────────────
              const _InfoCard(
                icon: Icons.image_not_supported_rounded,
                iconColor: AppTheme.primary,
                title: 'Images Must Contain Text',
                body:
                'The app cannot understand pictures that have no words '
                    'or blurry images.',
              ),

              const SizedBox(height: 16),

              // ── Point 3 ───────────────────────────────────────────────
              const _InfoCard(
                icon: Icons.privacy_tip_rounded,
                iconColor: AppTheme.success,
                title: 'Privacy Information',
                body:
                'Images you upload are sent to an online AI model for '
                    'text reading, but are not saved online. Please do not '
                    'upload sensitive images that you do not want to be '
                    'viewed by AI.',
              ),

              const SizedBox(height: 32),

              // ── CTA Button — only reachable after scrolling ────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.check_rounded, size: 28),
                  label: const Text("Got It — Let's Start!"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 68),
                    textStyle: const TextStyle(
                      fontSize: AppTheme.fontMD,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Private helper widget ────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Icon + title on one row ──────────────────────────────────
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
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

          const SizedBox(height: 14),

          // ── Body text — full width, larger size ──────────────────────
          Text(
            body,
            style: const TextStyle(
              fontSize: AppTheme.fontSM,
              color: AppTheme.textMedium,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}