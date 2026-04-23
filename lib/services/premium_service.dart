import 'package:shared_preferences/shared_preferences.dart';

/// PremiumService manages the user's subscription tier.
///
/// FREE TIER  — uses on-device ML Kit translation (direct, immediate).
/// PREMIUM    — uses Groq AI translation (natural, context-aware).
///              Translation happens lazily: only when the user switches to a
///              language tab, and the result is cached locally so it is never
///              re-requested for the same text + language combination.
///
/// Payment is intentionally skipped for now. Switching tiers is instant via
/// the Settings screen.
class PremiumService {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  static const String _tierKey = 'subscription_tier';
  static const String _tierFree = 'free';
  static const String _tierPremium = 'premium';

  bool _isPremium = false;

  bool get isPremium => _isPremium;
  bool get isFree => !_isPremium;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_tierKey) ?? _tierFree;
    _isPremium = saved == _tierPremium;
  }

  Future<void> setFree() async {
    _isPremium = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, _tierFree);
  }

  Future<void> setPremium() async {
    _isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, _tierPremium);
  }
}
