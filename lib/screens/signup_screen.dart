import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

/// SignUpScreen
/// ─────────────
/// Email + password registration. On success calls [onSuccess] so the host
/// can navigate to HomeScreen (or wherever fits your flow).
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _emailCtrl       = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmCtrl     = TextEditingController();
  final _auth            = AuthService();

  bool _awaitingVerification = false;
  String? _verifiedEmail;
  bool _loading          = false;
  bool _obscurePass      = true;
  bool _obscureConfirm   = true;
  String? _errorMsg;

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setError(String? msg) => setState(() => _errorMsg = msg);
  void _setLoading(bool v)    => setState(() => _loading = v);

  String _friendlyError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        default:
          return e.message ?? 'Sign-up failed. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _setError(null);
    _setLoading(true);
    try {
      // signUpWithEmail creates the Auth account, inits encryption, AND
      // writes the Firestore document — all awaited in sequence.
      final cred = await _auth.signUpWithEmail(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      // Send verification email immediately after account creation.
      // If this throws (e.g. rate limit), ignore it so the user can still proceed to the verification screen.
      try {
        await _auth.sendVerificationEmail();
      } catch (e) {
        debugPrint('[SignUp] Auto verification email failed: $e');
      }

      if (mounted) {
        setState(() {
          _awaitingVerification = true;
          _verifiedEmail = cred.user?.email ?? _emailCtrl.text.trim();
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _setError(_friendlyError(e));
    } catch (e, st) {
      // Log Firestore or other non-auth errors but do NOT block the user.
      // The Auth account was created — let them proceed to verification.
      // ensureUserDocument() in _goNext() will retry the Firestore write.
      debugPrint('[SignUp] Non-auth error (will retry on verify): $e');
      debugPrint('[SignUp] Stack: $st');
      // Still show verification screen — auth succeeded even if Firestore failed.
      if (mounted) {
        setState(() {
          _awaitingVerification = true;
          _verifiedEmail = _emailCtrl.text.trim();
        });
      }
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_awaitingVerification) {
      return _VerificationScreen(email: _verifiedEmail ?? '');
    }
    return _buildSignUpForm();
  }

  Widget _buildSignUpForm() {
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
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Icon ──────────────────────────────────────────────────
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person_add_rounded,
                      color: Colors.white, size: 44),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign up to get started',
                  style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 32),

                // ── Form card ─────────────────────────────────────────────
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
                        // Email
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Email Address',
                            icon: Icons.email_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!v.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePass,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Password',
                            icon: Icons.lock_outline_rounded,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF6B7280),
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (v.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Confirm password
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _signUp(),
                          decoration: _inputDecoration(
                            label: 'Confirm Password',
                            icon: Icons.lock_rounded,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF6B7280),
                              ),
                              onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (v != _passwordCtrl.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),

                        // Error message
                        if (_errorMsg != null) ...[
                          const SizedBox(height: 16),
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
                                color: Color(0xFFDC2626),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Sign up button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
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
                                : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 17,
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

                // ── Sign in link ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style:
                      TextStyle(color: Color(0xFF6B7280), fontSize: 15),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: Color(0xFF1A56DB),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF)),
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
        borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      labelStyle: const TextStyle(color: Color(0xFF6B7280)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Verification waiting screen — shown right after sign-up.
// • Background polls every 4 s via Timer.
// • App-resume triggers an immediate check via WidgetsBindingObserver.
// • "I've Verified" button for a manual check.
// • "Resend Email" has a 60-second cooldown to prevent spamming.
// ═══════════════════════════════════════════════════════════════════════════
class _VerificationScreen extends StatefulWidget {
  final String email;
  const _VerificationScreen({required this.email});

  @override
  State<_VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<_VerificationScreen>
    with WidgetsBindingObserver {
  final _auth = AuthService();

  // ── Proceed button state ─────────────────────────────────────────────────
  bool _proceedLoading = false;
  bool _notVerifiedYet = false;

  // ── Resend cooldown ──────────────────────────────────────────────────────
  static const int _cooldownSecs = 60;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  // ── Background poll + stream ─────────────────────────────────────────────
  Timer? _pollTimer;
  StreamSubscription<User?>? _tokenSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startListening();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    _tokenSub?.cancel();
    super.dispose();
  }

  // Resume from background → reload immediately, don't wait for next tick
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reloadAndAdvance();
  }

  void _startListening() {
    // 1. idTokenChanges fires the moment Firebase pushes a new token —
    //    which happens as soon as the backend registers the email as verified.
    //    This is the fastest path: often sub-second after the user taps the link.
    _tokenSub = FirebaseAuth.instance.idTokenChanges().listen((user) {
      if (user != null && user.emailVerified) _advance();
    });

    // 2. Fallback poll every 2 s in case the token stream misses the update
    //    (e.g. no push connection). We reload the user so emailVerified is fresh.
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _reloadAndAdvance();
    });
  }

  /// Silently reloads the Firebase user record and advances if verified.
  /// Returns true if navigation was triggered.
  Future<bool> _reloadAndAdvance() async {
    final verified = await _auth.reloadAndCheckVerified();
    if (!mounted) return true;
    if (verified) {
      _advance();
      return true;
    }
    return false;
  }

  /// Cancel timers and trigger navigation.
  /// AppRoot listens to userChanges() which fires when emailVerified becomes
  /// true after reload — so we just need to pop SignUpScreen off the stack.
  void _advance() {
    if (!mounted) return;
    _pollTimer?.cancel();
    _pollTimer = null;
    _tokenSub?.cancel();
    _tokenSub = null;
    _cooldownTimer?.cancel();
    // Pop SignUpScreen — AppRoot underneath rebuilds via userChanges() → home.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ── Proceed button ───────────────────────────────────────────────────────
  Future<void> _onProceed() async {
    if (_proceedLoading) return;
    setState(() { _proceedLoading = true; _notVerifiedYet = false; });

    final navigated = await _reloadAndAdvance();
    if (navigated) return; // AppRoot already swapped screens

    if (mounted) {
      setState(() { _proceedLoading = false; _notVerifiedYet = true; });
      Future.delayed(const Duration(seconds: 3),
              () { if (mounted) setState(() => _notVerifiedYet = false); });
    }
  }

  // ── Resend button ────────────────────────────────────────────────────────
  Future<void> _onResend() async {
    if (_resendCooldown > 0) return;

    try {
      await _auth.sendVerificationEmail();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not send email. Please try again later.'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Verification email sent! Check your inbox.'),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 3),
    ));

    // Start 60-second cooldown
    setState(() => _resendCooldown = _cooldownSecs);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) { _resendCooldown = 0; t.cancel(); }
      });
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final canResend = _resendCooldown == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Icon ────────────────────────────────────────────────
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.mark_email_unread_rounded,
                      color: Colors.white, size: 48),
                ),
                const SizedBox(height: 28),

                const Text(
                  'Check Your Email',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'We sent a verification link to\n${widget.email}\n\n'
                      'Tap the link in that email, then come back and press the button below.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Proceed button ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _proceedLoading ? null : _onProceed,
                    icon: _proceedLoading
                        ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      _proceedLoading ? 'Checking…' : "I've Verified — Continue",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                      const Color(0xFF059669).withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),

                // ── "Not verified yet" amber banner ──────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _notVerifiedYet
                      ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Color(0xFFD97706), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Email not verified yet — please click the link in your inbox first.',
                              style: TextStyle(
                                  color: Color(0xFFD97706), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 16),

                // ── Resend button with cooldown ───────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: canResend ? _onResend : null,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      canResend
                          ? 'Resend Verification Email'
                          : 'Resend in ${_resendCooldown}s',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      disabledForegroundColor:
                      const Color(0xFF9CA3AF),
                      side: BorderSide(
                        color: canResend
                            ? const Color(0xFF059669)
                            : const Color(0xFFD1D5DB),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Sign out link ────────────────────────────────────────
                TextButton(
                  onPressed: () async {
                    await _auth.signOut();
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    'Use a different account',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}