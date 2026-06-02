import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../app_theme.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import '../services/translation_service.dart';
import '../widgets/global_language_icon.dart';

/// LoginScreen
/// ───────────
/// Email + Password login, Google Sign-In button, Guest login, links to SignUp and
/// ForgotPassword screens.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _auth = AuthService();

  bool _loading = false;
  bool _obscurePass = true;
  String? _errorMsg;
  final _tr = AppTranslations();

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setError(String? msg) => setState(() => _errorMsg = msg);
  void _setLoading(bool v) => setState(() => _loading = v);

  String _friendlyError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return _tr.t('login_err_user_not_found');
        case 'wrong-password':       // legacy Firebase SDK — wrong password only
          return _tr.t('login_err_wrong_pass');
        case 'invalid-credential':   // modern Firebase SDK (v9+) — wrong email OR password (can't distinguish)
          return _tr.t('login_err_invalid_credential');
        case 'invalid-email':
          return _tr.t('login_err_invalid_email');
        case 'user-disabled':
          return _tr.t('login_err_disabled');
        case 'too-many-requests':
          return _tr.t('login_err_too_many');
        default:
          return e.message ?? _tr.t('login_err_failed');
      }
    }
    
    final errorStr = e.toString().toLowerCase();
    if (errorStr.contains('platformexception') || 
        errorStr.contains('missingplugin') || 
        errorStr.contains('network_error') || 
        errorStr.contains('sign_in_failed')) {
      return _tr.t('login_err_no_google');
    }
    
    return _tr.t('login_err_generic');
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _setError(null);
    _setLoading(true);
    try {
      await _auth.signInWithEmail(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
    } catch (e) {
      if (mounted) _setError(_friendlyError(e));
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _googleSignIn() async {
    _setError(null);
    _setLoading(true);
    try {
      final cred = await _auth.signInWithGoogle();
      if (cred == null && mounted) {
        _setLoading(false);
      }
    } catch (e) {
      if (mounted) _setError(_friendlyError(e));
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  /// Guest login — uses Firebase anonymous sign-in.
  /// Daily scan limit (3) is enforced locally via DataService / SharedPreferences.
  Future<void> _guestLogin() async {
    _setError(null);
    _setLoading(true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
      // DataService scan count is keyed per UID, so guest gets its own slot.
      // Sync from remote is skipped for anonymous users — local cache is authoritative.
    } catch (e) {
      if (mounted) _setError(_tr.t('login_err_guest'));
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Logo / Icon ───────────────────────────────────────────
                Image.asset(
                  'assets/img/VisionAID_logo.png',
                  width: 180,
                ),
                const SizedBox(height: 12),

                // ── Form card ─────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSM,
                            color: AppTheme.textDark,
                          ),
                          decoration: _inputDecoration(
                            label: _tr.t('login_email_address'),
                            icon: Icons.email_outlined,
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
                        const SizedBox(height: 8),

                        // Password
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePass,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _signIn(),
                          style: const TextStyle(
                            fontSize: AppTheme.fontSM,
                            color: AppTheme.textDark,
                          ),
                          decoration: _inputDecoration(
                            label: _tr.t('login_password'),
                            icon: Icons.lock_outline_rounded,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppTheme.textLight,
                                size: 26,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return _tr.t('login_err_empty_pass');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 2),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ).then((_) {
                              if (mounted) setState(() {});
                            }),
                            child: Text(
                              _tr.t('login_forgot_password'),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: AppTheme.fontXS,
                              ),
                            ),
                          ),
                        ),

                        // Error message
                        if (_errorMsg != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppTheme.danger.withOpacity(0.3)),
                            ),
                            child: Text(
                              _errorMsg!,
                              style: const TextStyle(
                                color: AppTheme.danger,
                                fontSize: AppTheme.fontXS,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Sign in button
                        SizedBox(
                          width: double.infinity,
                          height: 68,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(
                                    _tr.t('login_sign_in'),
                                    style: const TextStyle(
                                      fontSize: AppTheme.fontMD,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Divider ───────────────────────────────────────────────
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppTheme.cardBorder)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        _tr.t('login_or_continue_with'),
                        style: const TextStyle(
                          color: AppTheme.textLight,
                          fontSize: AppTheme.fontXS,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: AppTheme.cardBorder)),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Google button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 68,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _googleSignIn,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppTheme.surface,
                      side: const BorderSide(
                          color: AppTheme.cardBorder, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GoogleLogo(),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _tr.t('login_continue_with_google'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: AppTheme.fontMD,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Guest login button ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 68,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _guestLogin,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppTheme.background,
                      side: const BorderSide(
                          color: AppTheme.textLight, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 32,
                          color: AppTheme.textMedium,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _tr.t('login_continue_as_guest'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: AppTheme.fontMD,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Sign up link ──────────────────────────────────────────
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      "${_tr.t('login_no_account')} ",
                      style: const TextStyle(
                          color: AppTheme.textMedium,
                          fontSize: AppTheme.fontXS),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignUpScreen(),
                        ),
                      ).then((_) {
                        if (mounted) setState(() {});
                      }),
                      child: Text(
                        _tr.t('login_sign_up'),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: AppTheme.fontXS,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: GlobalLanguageIcon(onChanged: () => setState(() {})),
        ),
      ],
    ),
  ),
);
  }

  InputDecoration _inputDecoration(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
          color: AppTheme.textMedium, fontSize: AppTheme.fontXS),
      prefixIcon: Icon(icon, color: AppTheme.textLight, size: 26),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.danger),
      ),
      errorStyle: const TextStyle(fontSize: AppTheme.fontXS - 2),
      filled: true,
      fillColor: AppTheme.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

/// Simple Google 'G' logo drawn with CustomPaint — no image asset needed.
class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC05),
      const Color(0xFFEA4335),
    ];

    for (int i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = 4.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 2),
        (i * 90 - 45) * 3.14159 / 180,
        80 * 3.14159 / 180,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
