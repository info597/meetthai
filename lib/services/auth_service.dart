import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:flutter/foundation.dart';
class AuthService {
  static final _supa = Supabase.instance.client;

  /// LOGIN (Email + Passwort)
  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _supa.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = res.user;

    if (user == null) {
      throw Exception('Login fehlgeschlagen');
    }

    await _syncRevenueCat(user.id);
  }

  /// REGISTRIEREN
  static Future<void> signUp({
    required String email,
    required String password,
  }) async {
    final res = await _supa.auth.signUp(
      email: email,
      password: password,
    );

    final user = res.user;

    if (user == null) {
      throw Exception('Signup fehlgeschlagen');
    }

    await _syncRevenueCat(user.id);
  }

  /// LOGOUT
  static Future<void> signOut() async {
    try {
      await Purchases.logOut(); // wichtig!
    } catch (_) {}

    await _supa.auth.signOut();
  }

  /// 🔥 WICHTIG: RevenueCat mit Supabase User synchronisieren
  static Future<void> _syncRevenueCat(String userId) async {
    try {
      final info = await Purchases.logIn(userId);

      debugPrint('[RC] Login synced: $userId');
      debugPrint('[RC] created: ${info.created}');
    } catch (e) {
      debugPrint('[RC] Login Fehler: $e');
    }
  }
}

Future<void> trackLoginAnalytics() async {
  await FirebaseAnalytics.instance.logLogin(
    loginMethod: 'email',
  );
}


Future<void> trackSignupAnalytics() async {
  await FirebaseAnalytics.instance.logSignUp(
    signUpMethod: 'email',
  );
}
