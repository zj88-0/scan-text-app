import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/saved_text.dart';
import '../services/translation_service.dart';

class SavedTextCard extends StatelessWidget {
  final SavedText savedText;
  final String langCode;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEditName;

  const SavedTextCard({
    super.key,
    required this.savedText,
    required this.langCode,
    required this.onTap,
    required this.onDelete,
    required this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppTranslations();
    final preview = savedText.forLanguage(langCode);
    final previewText = preview.replaceAll('\n', ' ').trim();
    final displayText = previewText.length > 100
        ? '${previewText.substring(0, 100)}...'
        : previewText;

    final date = savedText.createdAt;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}  '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final hasName = savedText.name != null && savedText.name!.trim().isNotEmpty;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 8, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: icon + date/name + edit + delete ──────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.article_rounded,
                      color: AppTheme.primary, size: 26),
                  const SizedBox(width: 10),

                  // Name (if set) or date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasName)
                          Text(
                            savedText.name!,
                            style: const TextStyle(
                              fontSize: AppTheme.fontSM,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: hasName
                                ? AppTheme.fontXS - 2
                                : AppTheme.fontXS,
                            color: AppTheme.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Edit name button
                  IconButton(
                    icon: const Icon(Icons.edit_rounded,
                        color: AppTheme.primary, size: 26),
                    tooltip: hasName ? 'Edit name' : 'Add name',
                    onPressed: onEditName,
                  ),

                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_rounded,
                        color: AppTheme.danger, size: 26),
                    tooltip: tr.t('delete'),
                    onPressed: onDelete,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Preview text ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 2, right: 10),
                child: Text(
                  displayText.isEmpty ? '—' : displayText,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textDark,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 10),

              // ── Tap hint ───────────────────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: AppTheme.primary.withOpacity(0.6)),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to read',
                    style: TextStyle(
                      fontSize: AppTheme.fontXS,
                      color: AppTheme.primary.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
