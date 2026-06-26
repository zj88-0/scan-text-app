import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_theme.dart';
import '../services/data_service.dart';
import '../services/translation_service.dart';
import '../services/premium_service.dart';
import '../services/auth_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final AppTranslations _tr = AppTranslations();
  final DataService _dataService = DataService();
  final PremiumService _premiumService = PremiumService();
  final AuthService _authService = AuthService();

  bool _isSubmitting = false;

  double _usefulnessScore = 3;
  double _accuracyScore = 3;
  final TextEditingController _improvementController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final lang = _dataService.getLanguage();
    _tr.load(lang);
  }

  @override
  void dispose() {
    _improvementController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final isPremium = _premiumService.isPremium;
      // Different collections based on user tier
      final collectionName = isPremium ? 'feedback_premium' : 'feedback_free';

      await FirebaseFirestore.instance.collection(collectionName).add({
        'isPremium': isPremium,
        'usefulnessScore': _usefulnessScore,
        'accuracyScore': _accuracyScore,
        'improvement': _improvementController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr.t('feedback_success')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr.t('error_generic')),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildQuestionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Title dynamically changes based on premium tier
    final titleKey = _premiumService.isPremium ? 'feedback_title_premium' : 'feedback_title_free';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // Soft gray-blue background common in forms
      appBar: AppBar(
        title: Text(_tr.t('feedback')),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form Header Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Google Form style top colored bar
                        Container(
                          height: 12,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            _tr.t(titleKey),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Q1: Usefulness
                  _buildQuestionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr.t('feedback_q1'),
                          style: const TextStyle(fontSize: AppTheme.fontMD, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_tr.t('feedback_scale_1'), style: const TextStyle(fontSize: AppTheme.fontXS, color: AppTheme.textMedium)),
                            Text(_tr.t('feedback_scale_5'), style: const TextStyle(fontSize: AppTheme.fontXS, color: AppTheme.textMedium)),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.primary,
                            inactiveTrackColor: AppTheme.primary.withOpacity(0.2),
                            thumbColor: AppTheme.primary,
                            overlayColor: AppTheme.primary.withOpacity(0.1),
                            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
                            activeTickMarkColor: Colors.white,
                            inactiveTickMarkColor: AppTheme.primary.withOpacity(0.5),
                          ),
                          child: Slider(
                            value: _usefulnessScore,
                            min: 1,
                            max: 5,
                            divisions: 4,
                            label: _usefulnessScore.round().toString(),
                            onChanged: (value) {
                              setState(() {
                                _usefulnessScore = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _usefulnessScore.round().toString(),
                            style: const TextStyle(fontSize: AppTheme.fontSM, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Q2: Accuracy
                  _buildQuestionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr.t('feedback_q2'),
                          style: const TextStyle(fontSize: AppTheme.fontMD, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_tr.t('feedback_scale_1_acc'), style: const TextStyle(fontSize: AppTheme.fontXS, color: AppTheme.textMedium)),
                            Text(_tr.t('feedback_scale_5_acc'), style: const TextStyle(fontSize: AppTheme.fontXS, color: AppTheme.textMedium)),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.accent,
                            inactiveTrackColor: AppTheme.accent.withOpacity(0.2),
                            thumbColor: AppTheme.accent,
                            overlayColor: AppTheme.accent.withOpacity(0.1),
                            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
                            activeTickMarkColor: Colors.white,
                            inactiveTickMarkColor: AppTheme.accent.withOpacity(0.5),
                          ),
                          child: Slider(
                            value: _accuracyScore,
                            min: 1,
                            max: 5,
                            divisions: 4,
                            label: _accuracyScore.round().toString(),
                            onChanged: (value) {
                              setState(() {
                                _accuracyScore = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _accuracyScore.round().toString(),
                            style: const TextStyle(fontSize: AppTheme.fontSM, fontWeight: FontWeight.bold, color: AppTheme.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Q3: Improvements
                  _buildQuestionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            text: '${_tr.t('feedback_q3')} ',
                            style: const TextStyle(fontSize: AppTheme.fontMD, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                            children: [
                              TextSpan(
                                text: _tr.t('feedback_optional'),
                                style: const TextStyle(fontSize: AppTheme.fontSM, fontWeight: FontWeight.normal, color: AppTheme.textMedium),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _improvementController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: _tr.t('feedback_q3_hint'),
                            hintStyle: const TextStyle(color: AppTheme.textLight),
                            filled: false, // Google forms often use a simple underline for text
                            border: const UnderlineInputBorder(
                              borderSide: BorderSide(color: AppTheme.cardBorder, width: 1.5),
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: AppTheme.cardBorder, width: 1.5),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: AppTheme.primary, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ElevatedButton(
                        onPressed: _submitFeedback,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 56), // Override global infinite width
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _tr.t('feedback_submit'),
                          style: const TextStyle(fontSize: AppTheme.fontSM, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
