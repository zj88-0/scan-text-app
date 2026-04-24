import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// WiFiCheckService
/// Checks connectivity before any model download and shows a large-text,
/// senior-friendly dialog when the user is on mobile data / hotspot.
class WiFiCheckService {
  static final WiFiCheckService _instance = WiFiCheckService._internal();
  factory WiFiCheckService() => _instance;
  WiFiCheckService._internal();

  /// Returns true if the caller should proceed with the download.
  /// - Wi-Fi → proceed immediately (returns true).
  /// - Mobile data / hotspot → show warning dialog; returns true only if user
  ///   taps "Download Anyway", false if they tap "Not Now".
  /// - No internet → show error dialog; always returns false.
  Future<bool> checkAndConfirm(BuildContext context) async {
    List<ConnectivityResult> results;
    try {
      results = await Connectivity().checkConnectivity();
    } catch (_) {
      // If we can't check, assume no internet to be safe.
      results = [ConnectivityResult.none];
    }

    // Consider VPN-over-WiFi and ethernet as "safe" connections.
    final hasWifi = results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet) ||
        results.contains(ConnectivityResult.vpn);

    // Mobile data includes phone hotspot — connectivity_plus reports the
    // *outgoing* interface, so a device tethered via hotspot will report
    // ConnectivityResult.mobile on the *tethering* device.
    final hasMobile = results.contains(ConnectivityResult.mobile);

    final hasNone = results.isEmpty ||
        (results.length == 1 && results.first == ConnectivityResult.none);

    if (hasWifi && !hasMobile) {
      // Purely on Wi-Fi / Ethernet — proceed without a dialog.
      return true;
    }

    if (hasMobile) {
      // On mobile data or hotspot — warn the user.
      if (!context.mounted) return false;
      return await _showMobileDataDialog(context) ?? false;
    }

    if (hasNone) {
      // No internet at all.
      if (!context.mounted) return false;
      await _showNoInternetDialog(context);
      return false;
    }

    // Fallback: unknown connectivity type — allow but don't warn.
    return true;
  }

  Future<bool?> _showMobileDataDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),

        // ── Icon ──────────────────────────────────────────────────────────
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: AppTheme.accent,
              ),
            ),
            const Text(
              'Not on Wi-Fi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontLG,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),

        // ── Body text ─────────────────────────────────────────────────────
        content: const Text(
          'You are using mobile data or a hotspot.\n\n'
              'The translation files are large (about 30 MB each). '
              'Downloading on mobile data may be slow and could use up your data plan.\n\n'
              'It is best to connect to Wi-Fi first.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTheme.fontSM,
            color: AppTheme.textDark,
            height: 1.6,
          ),
        ),

        // ── Buttons ───────────────────────────────────────────────────────
        actions: [
          // "Wait for Wi-Fi" — safe, prominent outlined button
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, false),
            icon: const Icon(Icons.wifi_rounded, size: 26),
            label: const Text(
              'Wait for Wi-Fi',
              style: TextStyle(
                fontSize: AppTheme.fontSM,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 60),
              side: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
          const SizedBox(height: 10),

          // "Download Anyway" — smaller, de-emphasised
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text(
              'Download Anyway',
              style: TextStyle(
                fontSize: AppTheme.fontXS,
                color: AppTheme.textMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNoInternetDialog(BuildContext context) {
    return showDialog<void>(
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
                color: AppTheme.danger.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.signal_wifi_off_rounded,
                size: 48,
                color: AppTheme.danger,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Internet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontLG,
                fontWeight: FontWeight.bold,
                color: AppTheme.danger,
              ),
            ),
          ],
        ),
        content: const Text(
          'Your phone is not connected to the internet.\n\n'
              'Please turn on Wi-Fi and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTheme.fontSM,
            color: AppTheme.textDark,
            height: 1.6,
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.check_rounded, size: 26),
            label: const Text(
              'OK',
              style: TextStyle(
                fontSize: AppTheme.fontSM,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 60),
            ),
          ),
        ],
      ),
    );
  }
}