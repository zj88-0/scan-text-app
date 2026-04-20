import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/data_service.dart';
import '../services/translation_service.dart';

/// A slider that lets the user adjust text display size.
class FontSizeSlider extends StatefulWidget {
  final ValueChanged<double> onChanged;

  const FontSizeSlider({super.key, required this.onChanged});

  @override
  State<FontSizeSlider> createState() => _FontSizeSliderState();
}

class _FontSizeSliderState extends State<FontSizeSlider> {
  final DataService _dataService = DataService();
  double _value = 1.5;

  @override
  void initState() {
    super.initState();
    _value = _dataService.getFontSize();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppTranslations();
    return Row(
      children: [
        const Icon(Icons.text_fields, size: 26, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          tr.t('font_size'),
          style: const TextStyle(
            fontSize: AppTheme.fontSM,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
          ),
        ),
        const Spacer(),
        const Icon(Icons.text_fields, size: 18, color: AppTheme.textMedium),
        Expanded(
          flex: 3,
          child: Slider(
            value: _value,
            min: 1.0,
            max: 2.5,
            divisions: 6,
            activeColor: AppTheme.accent,
            inactiveColor: AppTheme.cardBorder,
            onChanged: (v) async {
              setState(() => _value = v);
              await _dataService.setFontSize(v);
              widget.onChanged(v);
            },
          ),
        ),
        const Icon(Icons.text_fields, size: 28, color: AppTheme.primary),
      ],
    );
  }
}
