import sys

def modify_file(filepath, replacements):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    for old, new in replacements:
        if old in content:
            content = content.replace(old, new)
        else:
            print(f"Warning: could not find snippet in {filepath}: {old[:50]}...")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Successfully modified {filepath}")

# onboarding_screen.dart replacements
onboarding_replacements = [
    (
        "import 'package:flutter/material.dart';\nimport '../app_theme.dart';",
        "import 'package:flutter/material.dart';\nimport '../app_theme.dart';\nimport '../services/data_service.dart';\nimport '../services/translation_service.dart';\nimport '../widgets/language_selector.dart';"
    ),
    (
        "class _OnboardingScreenState extends State<OnboardingScreen> {\n  bool _scrolledToBottom = false;\n  final ScrollController _scrollController = ScrollController();\n\n  @override\n  void initState() {\n    super.initState();\n    _scrollController.addListener(_onScroll);\n  }",
        "class _OnboardingScreenState extends State<OnboardingScreen> {\n  bool _scrolledToBottom = false;\n  final ScrollController _scrollController = ScrollController();\n  final AppTranslations _tr = AppTranslations();\n  final DataService _dataService = DataService();\n  String _currentLang = 'en';\n\n  @override\n  void initState() {\n    super.initState();\n    _currentLang = _dataService.getLanguage();\n    _scrollController.addListener(_onScroll);\n  }\n\n  Future<void> _changeLanguage(String langCode) async {\n    await _tr.load(langCode);\n    setState(() => _currentLang = langCode);\n  }"
    ),
    (
        "      appBar: AppBar(\n        automaticallyImplyLeading: false,\n        title: const Text(\n          'Terms & Conditions',\n          style: TextStyle(\n            fontSize: AppTheme.fontLG,\n            fontWeight: FontWeight.bold,\n          ),\n        ),\n      ),",
        "      appBar: AppBar(\n        automaticallyImplyLeading: false,\n        title: Text(\n          _tr.t('terms_title'),\n          style: const TextStyle(\n            fontSize: AppTheme.fontLG,\n            fontWeight: FontWeight.bold,\n          ),\n        ),\n        bottom: PreferredSize(\n          preferredSize: const Size.fromHeight(56),\n          child: Container(\n            color: AppTheme.primary,\n            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),\n            child: LanguageSelector(\n              currentLang: _currentLang,\n              onChanged: _changeLanguage,\n            ),\n          ),\n        ),\n      ),"
    ),
    (
        "                    Expanded(\n                      child: Text(\n                        'Please scroll down and read all terms before acknowledging.',\n                        style: TextStyle(",
        "                    Expanded(\n                      child: Text(\n                        _tr.t('terms_scroll_hint'),\n                        style: const TextStyle("
    ),
    (
        "                  const Center(\n                    child: Text(\n                      'Please Read Before Using',\n                      textAlign: TextAlign.center,\n                      style: TextStyle(",
        "                  Center(\n                    child: Text(\n                      _tr.t('terms_header'),\n                      textAlign: TextAlign.center,\n                      style: const TextStyle("
    ),
    (
        "                  Center(\n                    child: Text(\n                      'Last updated: June 2025',\n                      style: TextStyle(\n                        fontSize: AppTheme.fontXS,\n                        color: AppTheme.textLight,\n                      ),\n                    ),\n                  ),",
        "                  Center(\n                    child: Text(\n                      _tr.t('terms_last_updated'),\n                      style: const TextStyle(\n                        fontSize: AppTheme.fontXS,\n                        color: AppTheme.textLight,\n                      ),\n                    ),\n                  ),"
    ),
    (
        "                  // ── Section 1 ─────────────────────────────────────────\n                  _buildSection(\n                    icon: Icons.translate_rounded,\n                    iconColor: AppTheme.accent,\n                    title: '1. Translation Accuracy',\n                    body: 'Translations are provided by AI and may not be 100% accurate. Do not rely on them for critical decisions.',\n                  ),\n\n                  const SizedBox(height: 12),\n\n                  // ── Section 2 ─────────────────────────────────────────\n                  _buildSection(\n                    icon: Icons.privacy_tip_rounded,\n                    iconColor: AppTheme.success,\n                    title: '2. Data Storage',\n                    body: 'Saved texts are stored locally. Uninstalling the app deletes all saved data permanently.',\n                  ),\n\n                  const SizedBox(height: 12),\n\n                  // ── Section 3 ─────────────────────────────────────────\n                  _buildSection(\n                    icon: Icons.image_not_supported_rounded,\n                    iconColor: AppTheme.primary,\n                    title: '3. Image Requirements',\n                    body: 'Images must contain clear text. Blurry or handwritten text may not be read correctly.',\n                  ),\n\n                  const SizedBox(height: 12),\n\n                  // ── Section 4 ─────────────────────────────────────────\n                  _buildSection(\n                    icon: Icons.privacy_tip_rounded,\n                    iconColor: AppTheme.success,\n                    title: '4. Image Processing',\n                    body: 'Images are processed online but not stored. Do not upload sensitive or personal documents.',\n                  ),\n\n                  const SizedBox(height: 12),\n\n                  // ── Section 5 ─────────────────────────────────────────\n                  _buildSection(\n                    icon: Icons.account_circle_rounded,\n                    iconColor: AppTheme.accent,\n                    title: '5. Account & Usage',\n                    body: 'Free and Guest accounts are limited to 3 scans per day. Misuse may result in suspension.',\n                  ),\n\n                  const SizedBox(height: 12),\n\n                  // ── Section 6 ─────────────────────────────────────────\n                  _buildSection(\n                    icon: Icons.update_rounded,\n                    iconColor: AppTheme.primary,\n                    title: '6. Changes to Terms',\n                    body: 'Terms may be updated occasionally. Continued use constitutes acceptance of changes.',\n                  ),\n\n                  const SizedBox(height: 12),\n\n                  // ── Section 7 ─────────────────────────────────────────\n                  _buildSection(\n                    icon: Icons.shield_rounded,\n                    iconColor: AppTheme.success,\n                    title: '7. Liability',\n                    body: 'App is provided \"as is\". We are not liable for damages, translation errors, or data loss.',\n                  ),",
        "                  // ── Section 1 ─────────────────────────────────────────\n                  _buildSection(\n                    icon: Icons.translate_rounded,\n                    iconColor: AppTheme.accent,\n                    title: _tr.t('terms_sec1_title'),\n                    body: _tr.t('terms_sec1_body'),\n                  ),\n\n                  const SizedBox(height: 12),\n\n                  // ── Section 2 ─────────────────────────────────────────\n                  _buildSection(\n                    icon: Icons.privacy_tip_rounded,\n                    iconColor: AppTheme.success,\n                    title: _tr.t('terms_sec2_title'),\n                    body: _tr.t('terms_sec2_body'),\n                  ),\n\n                  const SizedBox(height: 12),\n\n                  // ── Section 3 ─────────────────────────────────────────\n                  _buildSection(\n                    icon: Icons.image_not_supported_rounded,\n                    iconColor: AppTheme.primary,\n                    title: _tr.t('terms_sec3_title'),\n                    body: _tr.t('terms_sec3_body'),\n                  ),\n\n                  const SizedBox(height: 12),\n\n                  // ── Section 4 ─────────────────────────────────────────\n                  _buildSection(\n                    icon: Icons.privacy_tip_rounded,\n                    iconColor: AppTheme.success,\n                    title: _tr.t('terms_sec4_title'),\n                    body: _tr.t('terms_sec4_body'),\n                  ),\n\n                  const SizedBox(height: 12),\n\n                  // ── Section 5 ─────────────────────────────────────────\n                  _buildSection(\n                    icon: Icons.account_circle_rounded,\n                    iconColor: AppTheme.accent,\n                    title: _tr.t('terms_sec5_title'),\n                    body: _tr.t('terms_sec5_body'),\n                  ),\n\n                  const SizedBox(height: 12),\n\n                  // ── Section 6 ─────────────────────────────────────────\n                  _buildSection(\n                    icon: Icons.update_rounded,\n                    iconColor: AppTheme.primary,\n                    title: _tr.t('terms_sec6_title'),\n                    body: _tr.t('terms_sec6_body'),\n                  ),\n\n                  const SizedBox(height: 12),\n\n                  // ── Section 7 ─────────────────────────────────────────\n                  _buildSection(\n                    icon: Icons.shield_rounded,\n                    iconColor: AppTheme.success,\n                    title: _tr.t('terms_sec7_title'),\n                    body: _tr.t('terms_sec7_body'),\n                  ),"
    ),
    (
        "                    child: const Text(\n                      'By tapping \"I Acknowledge\" below, you confirm that you '\n                      'have read and understood these Terms and Conditions, '\n                      'and agree to be bound by them.',\n                      textAlign: TextAlign.center,\n                      style: TextStyle(",
        "                    child: Text(\n                      _tr.t('terms_ack_note'),\n                      textAlign: TextAlign.center,\n                      style: const TextStyle("
    ),
    (
        "                    label: const Text('I Acknowledge'),",
        "                    label: Text(_tr.t('terms_ack_btn')),"
    ),
    (
        "                    child: const Row(\n                      children: [\n                        Icon(Icons.swipe_down_rounded,\n                            color: AppTheme.accent, size: 22),\n                        SizedBox(width: 10),\n                        Expanded(",
        "                    child: Row(\n                      children: [\n                        const Icon(Icons.swipe_down_rounded,\n                            color: AppTheme.accent, size: 22),\n                        const SizedBox(width: 10),\n                        Expanded("
    )
]

modify_file('lib/screens/onboarding_screen.dart', onboarding_replacements)

