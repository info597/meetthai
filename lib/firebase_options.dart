// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Wir haben aktuell nur Web konfiguriert.
    // Wenn du später Android/iOS hinzufügst, erweitern wir das hier.
    if (kIsWeb) return web;
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAHctXyl8UR8uW1XDiZ560DyMoz04WBSFs',
    authDomain: 'meet-thai-dating.firebaseapp.com',
    projectId: 'meet-thai-dating',
    storageBucket: 'meet-thai-dating.firebasestorage.app',
    messagingSenderId: '541550784769',
    appId: '1:541550784769:web:53f4ba50c4cdecaae72b00',
  );
}
