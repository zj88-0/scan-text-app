import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../app_theme.dart';
import '../services/translation_service.dart';
import '../widgets/global_language_icon.dart';

/// ForgotPasswordScreen
/// ─────────────────────
/// Sends a Firebase password-reset email. Shows a success state once sent.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _auth      = AuthService();
  final _tr        = AppTranslations();

  bool _loading  = false;
  bool _sent     = false;
  String? _errorMsg;

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _friendlyError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return _tr.t('login_err_user_not_found');
        case 'invalid-email':
          return _tr.t('login_err_invalid_email');
        default:
          return e.message ?? _tr.t('forgot_err_failed');
      }
    }
    return _tr.t('login_err_generic');
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _sendReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading  = true;
      _errorMsg = null;
    });
    try {
      await _auth.sendPasswordReset(_emailCtrl.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Color(0xFF1A1D23), size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GlobalLanguageIcon(onChanged: () => setState(() {})),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: _sent ? _buildSuccess() : _buildForm(),
          ),
        ),
      ),
    );
  }

  // ── Success state ─────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              color: Color(0xFF059669), size: 52),
        ),
        const SizedBox(height: 28),
        Text(
          _tr.t('signup_check_email'),
          style: const TextStyle(
            fontSize: AppTheme.fontLG,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1D23),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_tr.t('forgot_success')}\n${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: AppTheme.fontSM,
            color: Color(0xFF6B7280),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 36),

        SizedBox(
          width: double.infinity,
          height: 68,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A56DB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              _tr.t('forgot_back'),
              style: const TextStyle(fontSize: AppTheme.fontSM, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 16),

        TextButton(
          onPressed: () => setState(() => _sent = false),
          child: Text(
            _tr.t('forgot_resend'),
            style: const TextStyle(color: Color(0xFF1A56DB), fontSize: AppTheme.fontXS),
          ),
        ),
      ],
    );
  }

  // ── Form state ────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Icon ──────────────────────────────────────────────────────────
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.lock_reset_rounded,
              color: Color(0xFFF59E0B), size: 44),
        ),
        const SizedBox(height: 24),

        Text(
          _tr.t('forgot_title'),
          style: const TextStyle(
            fontSize: AppTheme.fontLG,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1D23),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _tr.t('forgot_subtitle'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: AppTheme.fontSM,
            color: Color(0xFF6B7280),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 36),

        // ── Form card ────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sendReset(),
                  decoration: InputDecoration(
                   labelText: _tr.t('login_email_address'),
                    prefixIcon: const Icon(Icons.email_outlined,
                        color: Color(0xFF9CA3AF)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFFF59E0B), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFDC2626)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return _tr.t('login_err_empty_email');
                    }
                    if (!v.contains('@')) {
                      return _tr.t('login_err_invalid_email');
                    }
                    return null;
                  },
                ),

                // Error
                if (_errorMsg != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(
                          color: Color(0xFFDC2626), fontSize: AppTheme.fontXS),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 68,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendReset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _tr.t('forgot_btn'),
                            style: const TextStyle(
                              fontSize: AppTheme.fontSM,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            '← ${_tr.t('forgot_back')}',
            style: const TextStyle(
                color: Color(0xFF1A56DB),
                fontSize: AppTheme.fontSM,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
