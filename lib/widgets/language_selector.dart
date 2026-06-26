import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/mlkit_translation_service.dart';
import '../services/translation_service.dart';
import '../services/data_service.dart';
import 'language_selection_helper.dart';

/// A horizontal row of language toggle buttons shown in the AppBar.
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
    const defaultLangs = ['en', 'zh', 'ms', 'ta'];
    const uiNames = AppTranslations.languageNames;
    final isCustomLang = !defaultLangs.contains(currentLang);

    // The globe/extra-language button is pinned to the right and always visible.
    // The four default language buttons scroll horizontally on the left side.
    final globeButton = GestureDetector(
      onTap: () {
        LanguageSelectionHelper.showLanguageDialog(context, currentLang, onChanged);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isCustomLang
              ? AppTheme.accent
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCustomLang
                ? AppTheme.accent
                : Colors.white.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language_rounded,
              size: AppTheme.fontSM,
              color: isCustomLang
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.9),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        // ── Scrollable default-language buttons ──────────────────────────
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: defaultLangs.map((code) {
                final isSelected = code == currentLang;
                final label = uiNames[code] ?? mlkit.displayName(code);

                Widget innerContent = Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.9),
                    fontSize: AppTheme.fontSM,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );

                if (code == 'zh') {
                  innerContent = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      innerContent,
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: AppTheme.fontSM,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                    ],
                  );
                }

                final button = AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accent
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accent
                          : Colors.white.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: innerContent,
                );

                if (code == 'zh') {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: PopupMenuButton<String>(
                      onSelected: (val) {
                        DataService().setChineseDialect(val);
                        onChanged(code);
                      },
                      offset: const Offset(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'mandarin',
                          child: Text('中文 (Mandarin)', style: TextStyle(fontSize: AppTheme.fontSM)),
                        ),
                        const PopupMenuItem(
                          value: 'cantonese',
                          child: Text('粤语 (Cantonese)', style: TextStyle(fontSize: AppTheme.fontSM)),
                        ),
                      ],
                      child: button,
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () => onChanged(code),
                    child: button,
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // ── Divider ──────────────────────────────────────────────────────
        Container(
          width: 1,
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          color: Colors.white.withValues(alpha: 0.3),
        ),

        // ── Globe button — always pinned to the right ─────────────────────
        globeButton,
      ],
    );
  }
}
