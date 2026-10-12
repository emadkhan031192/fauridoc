import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// Auth backend contract. Implemented by [DemoAuthBackend] (no Firebase)
/// and [FirebaseAuthBackend] (email/password + Google via Firebase Auth).
abstract class AuthBackend {
  Stream<AppUser?> get userStream;
  AppUser? get currentUser;
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> registerWithEmail(String email, String password, String name);
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signInDemo(String name, String phone);
  Future<void> signOut();
}

/// Demo-mode backend: local profile stored in SharedPreferences.
/// Google sign-in is unavailable in demo mode.
class DemoAuthBackend implements AuthBackend {
  final SharedPreferences _prefs;
  final _ctrl = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  DemoAuthBackend(this._prefs) {
    final uid = _prefs.getString('demo_uid');
    final name = _prefs.getString('demo_name');
    if (uid != null && name != null) {
      _user = AppUser(
        uid: uid,
        name: name,
        phone: _prefs.getString('demo_phone') ?? '',
      );
    }
  }

  @override
  Stream<AppUser?> get userStream => _ctrl.stream;

  @override
  AppUser? get currentUser => _user;

  @override
  Future<AppUser> signInDemo(String name, String phone) async {
    final uid = _prefs.getString('demo_uid') ?? 'demo_${DateTime.now().millisecondsSinceEpoch}';
    await _prefs.setString('demo_uid', uid);
    await _prefs.setString('demo_name', name);
    await _prefs.setString('demo_phone', phone);
    _user = AppUser(uid: uid, name: name, phone: phone);
    _ctrl.add(_user);
    return _user!;
  }

  @override
  Future<AppUser> signInWithEmail(String email, String password) =>
      throw UnsupportedError('Email sign-in needs Firebase (see SETUP.md).');

  @override
  Future<AppUser> registerWithEmail(String email, String password, String name) =>
      throw UnsupportedError('Email sign-in needs Firebase (see SETUP.md).');

  @override
  Future<AppUser> signInWithGoogle() =>
      throw UnsupportedError('Google sign-in needs Firebase (see SETUP.md).');

  @override
  Future<void> signOut() async {
    await _prefs.remove('demo_uid');
    await _prefs.remove('demo_name');
    await _prefs.remove('demo_phone');
    _user = null;
    _ctrl.add(null);
  }
}

/// Firebase backend: email/password + Google sign-in.
/// Admin flag comes from the `admins` collection (doc id == uid).
class FirebaseAuthBackend implements AuthBackend {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Stream<AppUser?> get userStream =>
      _auth.authStateChanges().asyncMap(_mapUser);

  @override
  AppUser? get currentUser =>
      _auth.currentUser == null ? null : _cached[_auth.currentUser!.uid];

  final Map<String, AppUser> _cached = {};

  Future<AppUser?> _mapUser(fb.User? u) async {
    if (u == null) return null;
    var isAdmin = false;
    try {
      final doc = await _db.collection('admins').doc(u.uid).get();
      isAdmin = doc.exists;
    } catch (_) {}
    final appUser = AppUser(
      uid: u.uid,
      name: u.displayName ?? (u.email ?? 'User'),
      email: u.email ?? '',
      phone: u.phoneNumber ?? '',
      isAdmin: isAdmin,
    );
    _cached[u.uid] = appUser;
    return appUser;
  }

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return (await _mapUser(cred.user))!;
  }

  @override
  Future<AppUser> registerWithEmail(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user?.updateDisplayName(name);
    return (await _mapUser(cred.user))!;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    final account = await GoogleSignIn().signIn();
    if (account == null) throw StateError('Google sign-in cancelled.');
    final googleAuth = await account.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    return (await _mapUser(cred.user))!;
  }

  @override
  Future<AppUser> signInDemo(String name, String phone) =>
      throw UnsupportedError('Demo sign-in is only available without Firebase.');

  @override
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}

/// Riverpod controller exposing the current user.
class AuthController extends Notifier<AppUser?> {
  AuthBackend? _backend;
  StreamSubscription<AppUser?>? _sub;

  @override
  AppUser? build() {
    ref.onDispose(() => _sub?.cancel());
    return null;
  }

  /// Called once from main() after Firebase probing.
  void attach(AuthBackend backend) {
    _backend = backend;
    _sub?.cancel();
    state = backend.currentUser;
    _sub = backend.userStream.listen((u) => state = u);
  }

  bool get canUseGoogle => _backend is FirebaseAuthBackend;
  bool get canUseEmail => _backend is FirebaseAuthBackend;
  bool get isDemoBackend => _backend is DemoAuthBackend;

  Future<AppUser> signInDemo(String name, String phone) =>
      _backend!.signInDemo(name, phone);

  Future<AppUser> signInWithEmail(String email, String password) =>
      _backend!.signInWithEmail(email, password);

  Future<AppUser> registerWithEmail(String email, String password, String name) =>
      _backend!.registerWithEmail(email, password, name);

  Future<AppUser> signInWithGoogle() => _backend!.signInWithGoogle();

  Future<void> signOut() => _backend!.signOut();
}
