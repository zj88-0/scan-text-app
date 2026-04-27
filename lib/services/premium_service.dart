import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'data_service.dart';

/// PremiumService manages the user's subscription tier.
///
/// FREE TIER  — on-device ML Kit translation. Limited to 3 scans per day.
/// PREMIUM    — Groq AI translation. Unlimited scans. Results cached locally.
///
/// SOURCE OF TRUTH: Firestore (encrypted via AuthService/EncryptionService).
/// Local SharedPreferences is used as a fast cache / offline fallback only.
class PremiumService {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  static const String _tierKey     = 'subscription_tier';
  static const String _tierFree    = 'free';
  static const String _tierPremium = 'premium';

  bool _isPremium = false;

  bool get isPremium => _isPremium;
  bool get isFree    => !_isPremium;

  // ── init ─────────────────────────────────────────────────────────────────

  /// Called once at app start (after Firebase + AuthService are ready).
  /// Reads from Firestore when signed in; falls back to local prefs when
  /// offline or signed out.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(_tierKey) ?? _tierFree;

    // Try to get the authoritative value from Firestore.
    try {
      final data = await AuthService().getUserData();
      if (data != null && data['tier'] != null) {
        final remoteTier = data['tier']!;
        _isPremium = remoteTier == _tierPremium;
        await prefs.setString(_tierKey, remoteTier);
        debugPrint('[PremiumService] init: tier from Firestore → $remoteTier');
        return;
      }
    } catch (e) {
      debugPrint('[PremiumService] Firestore read failed, using local: $e');
    }

    // Offline / not signed in — use local cache.
    _isPremium = local == _tierPremium;
    debugPrint('[PremiumService] init: tier from local cache → $local');
  }

  // ── setFree ───────────────────────────────────────────────────────────────

  /// Downgrades to free tier. Persists locally AND to Firestore.
  Future<void> setFree() async {
    _isPremium = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, _tierFree);
    try {
      await AuthService().updateTier(isPremium: false);
      debugPrint('[PremiumService] setFree: Firestore updated OK');
    } catch (e) {
      debugPrint('[PremiumService] setFree Firestore update failed: $e');
    }
  }

  // ── setPremium ────────────────────────────────────────────────────────────

  /// Upgrades to premium tier. Persists locally AND to Firestore.
  /// Also resets the daily scan counter so the user gets a clean slate.
  Future<void> setPremium() async {
    _isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, _tierPremium);
    try {
      await AuthService().updateTier(isPremium: true);
      debugPrint('[PremiumService] setPremium: Firestore updated OK');
    } catch (e) {
      debugPrint('[PremiumService] setPremium Firestore update failed: $e');
    }
    // Reset scan counter so upgrading mid-day gives a clean slate.
    await DataService().resetFreeScanCount();
  }
}