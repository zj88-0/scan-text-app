import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/mlkit_translation_service.dart';
import '../services/translation_service.dart';

class LanguageSelectionHelper {
  static Future<void> showLanguageDialog(
    BuildContext context,
    String currentLang,
    ValueChanged<String> onChanged,
  ) async {
    final tr = AppTranslations();
    final mlkit = OnDeviceTranslationService();

    // Support all MLKit languages
    const Map<String, String> allLangsMap =
        OnDeviceTranslationService.allSupportedLanguages;
    final List<String> allLangs = allLangsMap.keys.toList()
      ..sort((a, b) => allLangsMap[a]!.compareTo(allLangsMap[b]!));

    const uiNames = AppTranslations.languageNames;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr.t('lang_select_title'),
          style: const TextStyle(
            fontSize: AppTheme.fontMD,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: ListView.builder(
            itemCount: allLangs.length,
            itemBuilder: (listCtx, index) {
              final code = allLangs[index];
              final isSelected = code == currentLang;
              final label = uiNames[code] ?? mlkit.displayName(code);

              return _LanguageListItem(
                code: code,
                label: label,
                isSelected: isSelected,
                mlkit: mlkit,
                tr: tr,
                onChanged: onChanged,
                dialogContext: ctx,
                // parentContext is the screen context BEHIND the dialog —
                // always valid for showing new dialogs after the main one closes.
                parentContext: context,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr.t('lang_cancel')),
          ),
        ],
      ),
    );
  }
}

class _LanguageListItem extends StatefulWidget {
  final String code;
  final String label;
  final bool isSelected;
  final OnDeviceTranslationService mlkit;
  final AppTranslations tr;
  final ValueChanged<String> onChanged;
  final BuildContext dialogContext;

  /// The BuildContext of the screen that opened the dialog.
  /// Use this for any dialogs shown AFTER the main dialog has been dismissed,
  /// because the widget's own context is inside the dismissed dialog tree.
  final BuildContext parentContext;

  const _LanguageListItem({
    required this.code,
    required this.label,
    required this.isSelected,
    required this.mlkit,
    required this.tr,
    required this.onChanged,
    required this.dialogContext,
    required this.parentContext,
  });

  @override
  State<_LanguageListItem> createState() => _LanguageListItemState();
}

class _LanguageListItemState extends State<_LanguageListItem> {
  bool _isDownloaded = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkDownloaded();
  }

  Future<void> _checkDownloaded() async {
    final downloaded = await widget.mlkit.isModelDownloaded(widget.code);
    if (mounted) {
      setState(() {
        _isDownloaded = downloaded || widget.code == 'en';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        widget.label,
        style: TextStyle(
          fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
          color: widget.isSelected ? AppTheme.accent : AppTheme.textDark,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoading)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
          else if (_isDownloaded)
            const Icon(Icons.push_pin_rounded,
                color: AppTheme.success, size: 20),
          if (widget.isSelected)
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.check_rounded, color: AppTheme.accent),
            ),
        ],
      ),
      onTap: () async {
        // If this language is already selected, just close the dialog.
        if (widget.isSelected) {
          Navigator.pop(widget.dialogContext);
          return;
        }

        if (!_isDownloaded && widget.code != 'en') {
          // ── Step 1: Show download confirmation BEFORE closing the main dialog.
          //    We use `widget.dialogContext` here because the main dialog is still open.
          final download = await showDialog<bool>(
            context: widget.dialogContext,
            builder: (dCtx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(
                widget.tr.t('lang_select_title'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Text(widget.tr.t('lang_download_prompt')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: Text(widget.tr.t('lang_cancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: Text(widget.tr.t('lang_download')),
                ),
              ],
            ),
          );

          // User tapped Cancel — keep the main language dialog open.
          if (download != true) return;

          // ── Step 2: User confirmed download.
          //    Close the main dialog first.
          //    NOTE: after this pop the _LanguageListItem widget is DISPOSED,
          //    so we must NOT touch widget.code/tr/mlkit through `mounted` —
          //    those fields are still accessible since they are widget properties,
          //    but `mounted` will be false.  Use widget.parentContext instead.
          if (widget.dialogContext.mounted) {
            Navigator.pop(widget.dialogContext);
          }

          // ── Step 3: Show the loading progress dialog using parentContext.
          //    Create the notifier as a LOCAL variable so its lifetime is tied
          //    to this async closure, NOT to the widget state which was just
          //    disposed when the main dialog closed.
          if (!widget.parentContext.mounted) return;
          final translatingNotifier = ValueNotifier<bool>(false);

          showDialog<void>(
            context: widget.parentContext,
            barrierDismissible: false,
            builder: (bCtx) => ValueListenableBuilder<bool>(
              valueListenable: translatingNotifier,
              builder: (_, isTranslating, __) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                content: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                          color: AppTheme.accent, strokeWidth: 3),
                      const SizedBox(height: 20),
                      Text(
                        isTranslating
                            ? widget.tr.t('setup_setting_up')
                            : widget.tr.t('lang_downloading'),
                        style: const TextStyle(
                          fontSize: AppTheme.fontSM,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: AppTheme.fontMD,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.tr.t('lang_download_wait'),
                        style: const TextStyle(
                          fontSize: AppTheme.fontXS,
                          color: AppTheme.textMedium,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          // ── Step 4: Perform the download.
          final ok = await widget.mlkit.downloadModel(widget.code);

          // ── Step 4.5: Pre-translate UI strings (loading dialog still open).
          //    Switch dialog label to "Setting up translation…" while we work.
          if (ok) {
            translatingNotifier.value = true;
            try {
              await AppTranslations().preTranslate(widget.code);
            } catch (_) {
              // Silently ignore — the app will fall back to English for any
              // untranslated strings on the first open; they will be retried
              // the next time load() is called.
            }
            translatingNotifier.value = false;
          }

          // Free the notifier now that the dialog content no longer needs it.
          translatingNotifier.dispose();

          // ── Step 5: Close the loading dialog.
          if (widget.parentContext.mounted) {
            Navigator.pop(widget.parentContext);
          }

          // ── Step 6: Show success/failure then switch language.
          if (!widget.parentContext.mounted) return;
          if (ok) {
            // Show the "Finished downloading" success dialog and AWAIT it,
            // so parentContext is still valid when we call onChanged.
            await showDialog<void>(
              context: widget.parentContext,
              barrierDismissible: false,
              builder: (dCtx) {
                // Auto-close after 1.5 s
                Future.delayed(const Duration(milliseconds: 1500), () {
                  if (dCtx.mounted) Navigator.pop(dCtx);
                });
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  content: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.success, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          widget.tr.t('lang_download_success'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSM,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );

            // Only switch the language AFTER the dialog has fully closed,
            // so onChanged does not rebuild the tree while dialogs are open.
            if (widget.parentContext.mounted) {
              widget.onChanged(widget.code);
            }
          } else {
            if (widget.parentContext.mounted) {
              ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                SnackBar(
                  content: Text(widget.tr.t('lang_download_failed')),
                  backgroundColor: Colors.redAccent,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        } else {
          // Language already downloaded — just close the dialog and switch.
          Navigator.pop(widget.dialogContext);
          widget.onChanged(widget.code);
        }
      },
    );
  }
}
