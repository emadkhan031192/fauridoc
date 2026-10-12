import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/data/auth.dart';
import 'src/data/demo_repository.dart';
import 'src/data/firestore_repository.dart';
import 'src/providers/providers.dart';

/// Fauridoc entry point.
///
/// Firebase is optional: if [Firebase.initializeApp] fails (no
/// google-services.json / no Firebase project yet), the app runs fully in
/// demo mode on [DemoRepository]. Nothing crashes — the user just sees a
/// small "demo mode" note in Settings.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  var firebaseOk = false;
  try {
    await Firebase.initializeApp();
    firebaseOk = true;
  } catch (_) {
    firebaseOk = false;
  }

  final repository = firebaseOk ? FirestoreRepository() : DemoRepository(prefs);
  final AuthBackend authBackend = firebaseOk ? FirebaseAuthBackend() : DemoAuthBackend(prefs);

  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
      ],
      child: FauridocApp(
        prefs: prefs,
        authBackend: authBackend,
        demoMode: !firebaseOk,
      ),
    ),
  );
}
