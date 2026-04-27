import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'blocked_users_screen.dart';
import 'chat_list_screen.dart';
import 'chat_screen.dart';
import 'discovery_screen.dart';
import 'firebase_options.dart';
import 'home_screen.dart';
import 'i18n/app_locale_controller.dart';
import 'i18n/app_locale_scope.dart';
import 'i18n/app_strings.dart';
import 'likes_screen.dart';
import 'matches_screen.dart';
import 'profile_edit_screen.dart';
import 'profile_preview_screen.dart';
import 'services/push_service.dart';
import 'services/subscription_service.dart';
import 'upgrade_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final AppLocaleController appLocaleController = AppLocaleController();

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FLUTTER ERROR: ${details.exception}');
      debugPrint('FLUTTER STACK: ${details.stack}');
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Text(
                'Flutter Error:\n\n${details.exception}\n\n${details.stack ?? ''}',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );
    };

    bool firebaseReady = false;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('Firebase init erfolgreich');
      } else {
        debugPrint('Firebase bereits initialisiert');
      }
      firebaseReady = true;
    } catch (e, st) {
      final errorText = e.toString();
      final isDuplicateDefaultApp =
          errorText.contains('[core/duplicate-app]') ||
              errorText.contains('A Firebase App named "[DEFAULT]" already exists');

      if (isDuplicateDefaultApp) {
        debugPrint('Firebase bereits initialisiert (duplicate-app erkannt)');
        firebaseReady = true;
      } else {
        debugPrint('Firebase init fehlgeschlagen: $e');
        debugPrint('$st');
      }
    }

    const supabaseUrl =
        String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const supabaseAnonKey =
        String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    const revenueCatKey =
        String.fromEnvironment('REVENUECAT_PUBLIC_KEY', defaultValue: '');

    final hasSupabaseConfig =
        supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

    final anonPrefix = supabaseAnonKey.isEmpty
        ? 'EMPTY'
        : supabaseAnonKey.substring(
            0,
            supabaseAnonKey.length >= 20 ? 20 : supabaseAnonKey.length,
          );

    debugPrint('SUPABASE_URL=$supabaseUrl');
    debugPrint('SUPABASE_ANON_KEY_PREFIX=$anonPrefix');
    debugPrint('SUPABASE_ANON_KEY_LENGTH=${supabaseAnonKey.length}');

    if (hasSupabaseConfig) {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: true,
      );
      debugPrint('Supabase init erfolgreich');
      debugPrint(
        'CURRENT SUPABASE USER AT STARTUP: ${Supabase.instance.client.auth.currentUser?.id}',
      );
    } else {
      debugPrint('Supabase Config fehlt');
    }

    try {
      await SubscriptionService.instance.init(
        publicKey: revenueCatKey,
      );
      debugPrint('SubscriptionService init erfolgreich');
    } catch (e, st) {
      debugPrint('SubscriptionService init fehlgeschlagen: $e');
      debugPrint('$st');
    }

    if (hasSupabaseConfig) {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      debugPrint('Initial auth sync userId=$currentUserId');

      try {
        await SubscriptionService.instance.onAuthChanged(currentUserId);
        debugPrint('SubscriptionService initial auth sync erfolgreich');
      } catch (e, st) {
        debugPrint('SubscriptionService initial auth sync fehlgeschlagen: $e');
        debugPrint('$st');
      }
    }

    if (firebaseReady && hasSupabaseConfig) {
      Future.delayed(const Duration(milliseconds: 300), () async {
        try {
          await PushService.init();
          debugPrint('PushService init erfolgreich');
        } catch (e, st) {
          debugPrint('PushService init fehlgeschlagen: $e');
          debugPrint('$st');
        }
      });
    } else {
      debugPrint(
        'PushService init übersprungen: firebaseReady=$firebaseReady, hasSupabaseConfig=$hasSupabaseConfig',
      );
    }

    runApp(MyApp(hasSupabaseConfig: hasSupabaseConfig));
  }, (error, stack) {
    debugPrint('ZONE ERROR: $error');
    debugPrint('$stack');
  });
}

class MyApp extends StatelessWidget {
  final bool hasSupabaseConfig;

  const MyApp({
    super.key,
    required this.hasSupabaseConfig,
  });

  @override
  Widget build(BuildContext context) {
    return AppLocaleScope(
      controller: appLocaleController,
      child: AnimatedBuilder(
        animation: appLocaleController,
        builder: (context, _) {
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            onGenerateTitle: (context) => AppStrings.of(context).appName,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFFE91E63),
            ),
            locale: appLocaleController.locale,
            supportedLocales: AppLocaleController.supportedLocales,
            localeResolutionCallback: (deviceLocale, supportedLocales) {
              return appLocaleController.resolveLocale(deviceLocale);
            },
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            initialRoute: '/',
            routes: {
              '/': (_) => hasSupabaseConfig
                  ? const _RootGate()
                  : const _SupabaseSetupScreen(),
              '/auth': (_) => const AuthScreen(),
              '/home': (_) => const HomeScreen(),
              '/discover': (_) => const DiscoveryScreen(),
              '/matches': (_) => const MatchesScreen(),
              '/chats': (_) => const ChatListScreen(),
              '/likes': (_) => const LikesScreen(),
              '/blocked-users': (_) => const BlockedUsersScreen(),
              '/profile-edit': (_) => const ProfileEditScreen(),
              '/profile-preview': (_) => const ProfilePreviewScreen(),
              '/upgrade': (_) => const UpgradeScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/chat') {
                final args = settings.arguments;

                if (args is Map) {
                  final conversationId = args['conversationId'];
                  final otherUserId = args['otherUserId'];
                  final otherDisplayName = args['otherDisplayName'];
                  final otherAvatarUrl = args['otherAvatarUrl'];
                  final initialMessageId = args['initialMessageId'];

                  if (conversationId is String && otherUserId is String) {
                    return MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        conversationId: conversationId,
                        otherUserId: otherUserId,
                        otherDisplayName:
                            otherDisplayName is String ? otherDisplayName : null,
                        otherAvatarUrl:
                            otherAvatarUrl is String ? otherAvatarUrl : null,
                        initialMessageId:
                            initialMessageId is String ? initialMessageId : null,
                      ),
                    );
                  }
                }

                return MaterialPageRoute(
                  builder: (context) {
                    final t = AppStrings.of(context);
                    return Scaffold(
                      appBar: AppBar(title: Text(t.chats)),
                      body: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            t.isGerman
                                ? 'Fehler: conversationId/otherUserId fehlen beim Öffnen des Chats.'
                                : t.isThai
                                    ? 'ข้อผิดพลาด: ไม่มี conversationId/otherUserId ตอนเปิดแชต'
                                    : 'Error: conversationId/otherUserId are missing when opening the chat.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }

              return null;
            },
          );
        },
      ),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (event) async {
        final userId = event.session?.user.id;

        debugPrint('Auth change erkannt: userId=$userId');
        debugPrint(
          'CURRENT SUPABASE USER AFTER AUTH CHANGE: ${Supabase.instance.client.auth.currentUser?.id}',
        );

        try {
          await SubscriptionService.instance.onAuthChanged(userId);
          debugPrint('Subscription auth sync erfolgreich für userId=$userId');
        } catch (e, st) {
          debugPrint('Subscription auth sync Fehler: $e');
          debugPrint('$st');
        }

        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supa = Supabase.instance.client;
    final loggedIn = supa.auth.currentUser != null;

    if (loggedIn) {
      return const HomeScreen();
    }

    return const AuthScreen();
  }
}

class _SupabaseSetupScreen extends StatelessWidget {
  const _SupabaseSetupScreen();

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);

    final title = t.isGerman
        ? 'Setup erforderlich'
        : t.isThai
            ? 'ต้องตั้งค่า'
            : 'Setup required';

    final headline = t.isGerman
        ? 'Supabase URL / ANON KEY fehlen.'
        : t.isThai
            ? 'ไม่มี Supabase URL / ANON KEY'
            : 'Supabase URL / ANON KEY are missing.';

    final description = t.isGerman
        ? 'Starte die App mit --dart-define:\n\n'
            'Android:\n'
            'flutter run -d <deviceId> '
            '--dart-define=SUPABASE_URL="https://xxx.supabase.co" '
            '--dart-define=SUPABASE_ANON_KEY="xxx" '
            '--dart-define=REVENUECAT_PUBLIC_KEY="rc_test_xxx"\n\n'
            'Web:\n'
            'flutter run -d chrome '
            '--dart-define=SUPABASE_URL="https://xxx.supabase.co" '
            '--dart-define=SUPABASE_ANON_KEY="xxx"'
        : t.isThai
            ? 'เริ่มแอปด้วย --dart-define:\n\n'
                'Android:\n'
                'flutter run -d <deviceId> '
                '--dart-define=SUPABASE_URL="https://xxx.supabase.co" '
                '--dart-define=SUPABASE_ANON_KEY="xxx" '
                '--dart-define=REVENUECAT_PUBLIC_KEY="rc_test_xxx"\n\n'
                'Web:\n'
                'flutter run -d chrome '
                '--dart-define=SUPABASE_URL="https://xxx.supabase.co" '
                '--dart-define=SUPABASE_ANON_KEY="xxx"'
            : 'Start the app with --dart-define:\n\n'
                'Android:\n'
                'flutter run -d <deviceId> '
                '--dart-define=SUPABASE_URL="https://xxx.supabase.co" '
                '--dart-define=SUPABASE_ANON_KEY="xxx" '
                '--dart-define=REVENUECAT_PUBLIC_KEY="rc_test_xxx"\n\n'
                'Web:\n'
                'flutter run -d chrome '
                '--dart-define=SUPABASE_URL="https://xxx.supabase.co" '
                '--dart-define=SUPABASE_ANON_KEY="xxx"';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 8),
            Text(
              headline,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(description),
          ],
        ),
      ),
    );
  }
}