import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/mlkit_translation_service.dart';
import '../services/translation_service.dart';

/// A horizontal row of language toggle buttons shown in the AppBar.
/// Shows only the currently configured languages.
class LanguageSelector extends StatelessWidget {
  final String currentLang;
  final ValueChanged<String> onChanged;

  const LanguageSelector({
    super.key,
    required this.currentLang,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final mlkit = OnDeviceTranslationService();
    final configured = mlkit.configuredLanguages;

    // Build display labels: prefer the friendly UI name from AppTranslations
    // fallback to ML Kit's display name
    final uiNames = AppTranslations.languageNames;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: configured.map((code) {
          final isSelected = code == currentLang;
          final label = uiNames[code] ?? mlkit.displayName(code);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onChanged(code),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accent
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accent
                        : Colors.white.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
