import 'package:flutter/material.dart';

class AppLocaleController extends ChangeNotifier {
  Locale? _locale;

  Locale? get locale => _locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
    Locale('th'),
  ];

  void useSystemLocale() {
    _locale = null;
    notifyListeners();
  }

  void setLocale(Locale? locale) {
    _locale = locale;
    notifyListeners();
  }

  bool isSupported(Locale locale) {
    return supportedLocales.any(
      (l) => l.languageCode == locale.languageCode,
    );
  }

  Locale resolveLocale(Locale? deviceLocale) {
    if (_locale != null && isSupported(_locale!)) {
      return _locale!;
    }

    if (deviceLocale != null) {
      for (final supported in supportedLocales) {
        if (supported.languageCode == deviceLocale.languageCode) {
          return supported;
        }
      }
    }

    return const Locale('en');
  }
}