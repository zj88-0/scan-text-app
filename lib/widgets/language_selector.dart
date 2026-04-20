import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/translation_service.dart';

/// A horizontal row of language toggle buttons shown in the AppBar / settings.
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: AppTranslations.languageNames.entries.map((entry) {
        final isSelected = entry.key == currentLang;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: GestureDetector(
            onTap: () => onChanged(entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accent : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.accent : Colors.white.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
