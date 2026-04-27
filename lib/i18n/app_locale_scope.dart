import 'package:flutter/widgets.dart';

import 'app_locale_controller.dart';

class AppLocaleScope extends InheritedNotifier<AppLocaleController> {
  final AppLocaleController controller;

  const AppLocaleScope({
    super.key,
    required this.controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLocaleScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    assert(scope != null, 'No AppLocaleScope found in context');
    return scope!;
  }
}