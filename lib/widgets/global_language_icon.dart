import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/translation_service.dart';
import '../services/mlkit_translation_service.dart';

class GlobalLanguageIcon extends StatelessWidget {
  final VoidCallback? onChanged;
  final Color iconColor;

  /// When [fastLoad] is true (e.g. on the model-setup/download screen):
  ///   • Uses [AppTranslations.loadFast] — reads only from bundled asset or
  ///     cached file, never triggers ML Kit downloads or translateUIStrings().
  ///   • Only shows the 4 default bundled languages (en/zh/ms/ta) so the user
  ///     can still switch display language without touching any download logic.
  final bool fastLoad;

  const GlobalLanguageIcon({
    super.key,
    this.onChanged,
    this.iconColor = AppTheme.primary,
    this.fastLoad = false,
  });

  @override
  Widget build(BuildContext context) {
    final mlkit = OnDeviceTranslationService();
    final currentLang = AppTranslations().currentLang;
    final uiNames = AppTranslations.languageNames;

    // On the setup screen only offer the 4 bundled languages — these always
    // have a pre-built JSON asset and can be switched instantly with loadFast.
    final List<String> languages = fastLoad
        ? OnDeviceTranslationService.defaultLanguageCodes
        : mlkit.configuredLanguages;

    return PopupMenuButton<String>(
      icon: Icon(Icons.language_rounded, color: iconColor),
      onSelected: (code) async {
        if (code != currentLang) {
          if (fastLoad) {
            // Safe during downloads — never touches ML Kit.
            await AppTranslations().loadFast(code);
          } else {
            await AppTranslations().load(code);
          }
          onChanged?.call();
        }
      },
      itemBuilder: (context) {
        return languages.map((code) {
          final isSelected = code == currentLang;
          final label = uiNames[code] ?? mlkit.displayName(code);
          return PopupMenuItem<String>(
            value: code,
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primary : AppTheme.textDark,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  const Icon(Icons.check_rounded, color: AppTheme.primary, size: 20),
                ]
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
