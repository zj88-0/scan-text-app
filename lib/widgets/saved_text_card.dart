import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/saved_text.dart';
import '../services/translation_service.dart';

/// Card displayed in the saved texts list.
class SavedTextCard extends StatelessWidget {
  final SavedText savedText;
  final String langCode;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SavedTextCard({
    super.key,
    required this.savedText,
    required this.langCode,
    required this.onTap,
    required this.onDelete,
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
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.article_rounded, color: AppTheme.primary, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: AppTheme.fontXS,
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, color: AppTheme.danger, size: 28),
                    tooltip: tr.t('delete'),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                displayText.isEmpty ? '—' : displayText,
                style: const TextStyle(
                  fontSize: AppTheme.fontSM,
                  color: AppTheme.textDark,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
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
