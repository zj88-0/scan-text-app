import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'encryption_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth      _auth         = FirebaseAuth.instance;
  final FirebaseFirestore _firestore    = FirebaseFirestore.instance;
  final GoogleSignIn      _googleSignIn = GoogleSignIn();
  final EncryptionService _enc          = EncryptionService();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Sign up ───────────────────────────────────────────────────────────────

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _enc.initFromEmail(cred.user!.email!);
    await _writeNewUserDocument(cred.user!);
    return cred;
  }

  // ── Sign in ───────────────────────────────────────────────────────────────

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _enc.initFromEmail(cred.user!.email!);
    await ensureUserDocument();
    return cred;
  }

  Future<UserCredential?> signInWithGoogle() async {
    await _googleSignIn.signOut();
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null) {
      throw FirebaseAuthException(
        code: 'google-auth-failed',
        message: 'Google sign-in failed: could not retrieve ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken:     googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);
    if (cred.user?.email != null) {
      await _enc.initFromEmail(cred.user!.email!);
    }
    await ensureUserDocument();
    return cred;
  }

  // ── Password reset ────────────────────────────────────────────────────────

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Email verification ────────────────────────────────────────────────────

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
    } catch (_) {
      return false;
    }
    return _auth.currentUser?.emailVerified ?? false;
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Restore encryption on cold start ─────────────────────────────────────

  Future<void> restoreEncryptionIfSignedIn() async {
    final user = _auth.currentUser;
    if (user != null && user.email != null) {
      await _enc.initFromEmail(user.email!);
    }
  }

  // ── Ensure document exists (called after verification + every sign-in) ────

  Future<void> ensureUserDocument() async {
    final user = currentUser;
    if (user == null) {
      debugPrint('[AuthService] ensureUserDocument: no user signed in');
      return;
    }
    if (user.email != null && !_enc.isReady) {
      await _enc.initFromEmail(user.email!);
    }
    if (!_enc.isReady) {
      debugPrint('[AuthService] ensureUserDocument: encryption not ready');
      return;
    }

    final docId = _enc.hashEmail(user.email ?? user.uid);
    final ref   = _firestore.collection('users').doc(docId);

    try {
      final snap = await ref.get();
      if (snap.exists) {
        debugPrint('[AuthService] ensureUserDocument: already exists — OK');
        return;
      }
      // Document missing — write it now
      await _writeNewUserDocument(user);
    } catch (e, st) {
      debugPrint('[AuthService] ensureUserDocument error: $e\n$st');
    }
  }

  // ── Core Firestore write ──────────────────────────────────────────────────

  /// Writes a brand-new user document. Does NOT use merge so this always
  /// triggers the Firestore `allow create` rule (not update).
  /// Only call this when you know the document does not exist yet.
  Future<void> _writeNewUserDocument(User user) async {
    if (!_enc.isReady) {
      debugPrint('[AuthService] _writeNewUserDocument: encryption not ready');
      return;
    }

    final docId = _enc.hashEmail(user.email ?? user.uid);
    final today = _todayString();

    debugPrint('[AuthService] Writing user document — docId: $docId');
    debugPrint('[AuthService] User email: ${user.email}');
    debugPrint('[AuthService] User uid:   ${user.uid}');

    // Build the document — all string fields encrypted, createdAt plain.
    final doc = <String, dynamic>{
      'email'         : _enc.encrypt(user.email ?? ''),
      'uid'           : _enc.encrypt(user.uid),
      'tier'          : _enc.encrypt('free'),
      'premiumSince'  : _enc.encrypt(''),
      'scanLimit'     : _enc.encrypt('3'),
      'dailyScanCount': _enc.encrypt('0'),
      'dailyScanDate' : _enc.encrypt(today),
      'createdAt'     : FieldValue.serverTimestamp(),
    };

    debugPrint('[AuthService] Document fields built — attempting Firestore set...');

    try {
      // Plain set() — no merge — so Firestore always evaluates allow create.
      await _firestore.collection('users').doc(docId).set(doc);
      debugPrint('[AuthService] *** USER DOCUMENT WRITTEN SUCCESSFULLY *** docId: $docId');
    } catch (e, st) {
      // Log but never rethrow — a Firestore failure must never break sign-up.
      // ensureUserDocument() called from _goNext() will retry after verification.
      debugPrint('[AuthService] _writeNewUserDocument FAILED: $e');
      debugPrint('[AuthService] Stack: $st');
    }
  }

  // ── Read user data ────────────────────────────────────────────────────────

  Future<Map<String, String>?> getUserData() async {
    final user = currentUser;
    if (user == null) return null;
    if (!_enc.isReady) return null;

    final docId = _enc.hashEmail(user.email ?? user.uid);

    final snap = await _firestore.collection('users').doc(docId).get();
    if (!snap.exists) return null;

    final raw = snap.data()!;
    return {
      'email'         : _enc.decrypt(raw['email']          as String? ?? ''),
      'uid'           : _enc.decrypt(raw['uid']            as String? ?? ''),
      'tier'          : _enc.decrypt(raw['tier']           as String? ?? ''),
      'premiumSince'  : _enc.decrypt(raw['premiumSince']   as String? ?? ''),
      'scanLimit'     : _enc.decrypt(raw['scanLimit']      as String? ?? ''),
      'dailyScanCount': _enc.decrypt(raw['dailyScanCount'] as String? ?? '0'),
      'dailyScanDate' : _enc.decrypt(raw['dailyScanDate']  as String? ?? ''),
    };
  }

  // ── Update tier ───────────────────────────────────────────────────────────

  Future<void> updateTier({required bool isPremium}) async {
    final user = currentUser;
    if (user == null || !_enc.isReady) return;

    final docId = _enc.hashEmail(user.email ?? user.uid);
    final now   = DateTime.now().toIso8601String();

    await _firestore.collection('users').doc(docId).update({
      'tier'        : _enc.encrypt(isPremium ? 'premium' : 'free'),
      'scanLimit'   : _enc.encrypt(isPremium ? 'unlimited' : '3'),
      'premiumSince': _enc.encrypt(isPremium ? now : ''),
    });
    debugPrint('[AuthService] updateTier → ${isPremium ? 'premium' : 'free'}');
  }

  // ── Scan count ────────────────────────────────────────────────────────────

  Future<int> getRemoteScanCount() async {
    try {
      final data = await getUserData();
      if (data == null) return 0;
      final storedDate  = data['dailyScanDate']  ?? '';
      final storedCount = data['dailyScanCount'] ?? '0';
      if (storedDate != _todayString()) return 0;
      return int.tryParse(storedCount) ?? 0;
    } catch (e) {
      debugPrint('[AuthService] getRemoteScanCount error: $e');
      return 0;
    }
  }

  Future<int?> incrementRemoteScanCount() async {
    final user = currentUser;
    if (user == null || !_enc.isReady) return null;

    try {
      final docId = _enc.hashEmail(user.email ?? user.uid);
      final today = _todayString();
      final ref   = _firestore.collection('users').doc(docId);

      final newCount = await _firestore.runTransaction<int>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return 1;

        final raw         = snap.data()!;
        final storedDate  = _enc.decrypt(raw['dailyScanDate']  as String? ?? '');
        final storedCount = _enc.decrypt(raw['dailyScanCount'] as String? ?? '0');
        final current     = (storedDate == today)
            ? (int.tryParse(storedCount) ?? 0)
            : 0;
        final next = current + 1;

        tx.update(ref, {
          'dailyScanCount': _enc.encrypt(next.toString()),
          'dailyScanDate' : _enc.encrypt(today),
        });
        return next;
      });

      debugPrint('[AuthService] incrementRemoteScanCount → $newCount');
      return newCount;
    } catch (e) {
      debugPrint('[AuthService] incrementRemoteScanCount error: $e');
      return null;
    }
  }

  Future<void> resetRemoteScanCount() async {
    final user = currentUser;
    if (user == null || !_enc.isReady) return;
    try {
      final docId = _enc.hashEmail(user.email ?? user.uid);
      await _firestore.collection('users').doc(docId).update({
        'dailyScanCount': _enc.encrypt('0'),
        'dailyScanDate' : _enc.encrypt(_todayString()),
      });
      debugPrint('[AuthService] resetRemoteScanCount OK');
    } catch (e) {
      debugPrint('[AuthService] resetRemoteScanCount error: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}