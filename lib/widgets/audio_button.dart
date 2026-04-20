import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/tts_service.dart';
import '../services/translation_service.dart';

class AudioButton extends StatefulWidget {
  final String text;
  final String langCode;

  const AudioButton({super.key, required this.text, required this.langCode});

  @override
  State<AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends State<AudioButton> with SingleTickerProviderStateMixin {
  final TtsService _tts = TtsService();
  bool _playing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _tts.onComplete = () {
      if (mounted) setState(() => _playing = false);
    };
    _tts.onStart = () {
      if (mounted) setState(() => _playing = true);
    };
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _tts.stop();
      setState(() => _playing = false);
    } else {
      setState(() => _playing = true);
      await _tts.speak(widget.text, langCode: widget.langCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppTranslations();
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Transform.scale(
          scale: _playing ? _pulse.value : 1.0,
          child: ElevatedButton.icon(
            onPressed: _toggle,
            style: ElevatedButton.styleFrom(
              backgroundColor: _playing ? AppTheme.danger : AppTheme.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 68),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: _playing ? 6 : 2,
            ),
            icon: Icon(
              _playing ? Icons.stop_rounded : Icons.volume_up_rounded,
              size: 32,
            ),
            label: Text(
              _playing ? tr.t('stop_audio') : tr.t('play_audio'),
              style: const TextStyle(fontSize: AppTheme.fontMD, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}
