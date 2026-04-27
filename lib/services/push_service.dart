import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

class PushService {
  static final SupabaseClient _supa = Supabase.instance.client;

  static const String _webPushKey =
      'BEqkzWAXfLJ7w0WRBMiH2tOB5s5WjfikUJEg9YESmjd-zbY9yTI_0AzYHfjG-Kez8VJv9CAKd8wxp6PThgFDnew';

  static bool _initialized = false;
  static bool _syncInProgress = false;

  static StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _foregroundSub;
  static StreamSubscription<AuthState>? _authSub;

  static String? _cachedToken;
  static String? _lastSyncedUserId;

  static String? _currentOpenConversationId;
  static void Function(String messageId)? _scrollToMessageCallback;

  static String? _lastOpenedConversationId;
  static DateTime? _lastOpenedAt;

  static Future<void> init() async {
    if (_initialized) {
      debugPrint('PushService war bereits initialisiert');
      return;
    }

    debugPrint('PushService.init() gestartet');

    await _requestPermission();
    await _loadAndCacheToken();
    await syncTokenForCurrentUser();

    _tokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      debugPrint('FCM Token Refresh erhalten');
      _cachedToken = token;

      try {
        await syncTokenForCurrentUser();
      } catch (e) {
        debugPrint('Fehler beim Speichern nach Token-Refresh: $e');
      }
    });

    _foregroundSub =
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        'Push foreground erhalten: ${message.notification?.title} / ${message.notification?.body}',
      );
      _showForegroundMessageIfNeeded(message);
    });

    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    _authSub = _supa.auth.onAuthStateChange.listen((event) async {
      final newUserId = event.session?.user.id;
      debugPrint('PushService Auth-Change erkannt: userId=$newUserId');

      try {
        if (newUserId == null || newUserId.isEmpty) {
          await _removeTokenForLastKnownUser();
        } else {
          await syncTokenForCurrentUser();
        }
      } catch (e) {
        debugPrint('Fehler beim Token-Sync nach Auth-Change: $e');
      }
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleMessageTap(initialMessage);
      });
    }

    _initialized = true;
    debugPrint('PushService.init() abgeschlossen');
  }

  static Future<void> dispose() async {
    await _onMessageOpenedSub?.cancel();
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _authSub?.cancel();

    _onMessageOpenedSub = null;
    _tokenRefreshSub = null;
    _foregroundSub = null;
    _authSub = null;
  }

  static void setCurrentOpenConversation(String? conversationId) {
    _currentOpenConversationId = conversationId;
    debugPrint('PushService current conversation = $conversationId');
  }

  static void registerScrollToMessageCallback(
    void Function(String messageId)? callback,
  ) {
    _scrollToMessageCallback = callback;
  }

  static Future<void> _requestPermission() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Push permission status: ${settings.authorizationStatus}');
  }

  static Future<void> _loadAndCacheToken() async {
    try {
      if (kIsWeb) {
        _cachedToken = await FirebaseMessaging.instance.getToken(
          vapidKey: _webPushKey,
        );
      } else {
        _cachedToken = await FirebaseMessaging.instance.getToken();
      }

      if (_cachedToken == null || _cachedToken!.isEmpty) {
        debugPrint('Kein FCM Token erhalten');
        return;
      }

      debugPrint(
        'FCM TOKEN geladen: ${_cachedToken!.substring(0, _cachedToken!.length > 20 ? 20 : _cachedToken!.length)}...',
      );
    } catch (e) {
      debugPrint('Fehler beim Laden des FCM Tokens: $e');
    }
  }

  static Future<void> syncTokenForCurrentUser() async {
    if (_syncInProgress) return;
    _syncInProgress = true;

    try {
      if (_cachedToken == null || _cachedToken!.isEmpty) {
        await _loadAndCacheToken();
      }

      final token = _cachedToken;
      if (token == null || token.isEmpty) {
        debugPrint('Kein gespeicherter Token zum Sync vorhanden');
        return;
      }

      final user = _supa.auth.currentUser;
      if (user == null) {
        debugPrint('Push Token nicht gespeichert: kein eingeloggter User');
        return;
      }

      await _cleanupTokenAssignments(token: token, currentUserId: user.id);

      await _upsertToken(
        userId: user.id,
        token: token,
      );

      _lastSyncedUserId = user.id;
      debugPrint('Push Token erfolgreich für User gespeichert: ${user.id}');
    } catch (e) {
      debugPrint('Fehler beim Sync des Push Tokens: $e');
      rethrow;
    } finally {
      _syncInProgress = false;
    }
  }

  static Future<void> _cleanupTokenAssignments({
    required String token,
    required String currentUserId,
  }) async {
    try {
      await _supa
          .from('push_tokens')
          .delete()
          .eq('token', token)
          .neq('user_id', currentUserId);
    } catch (e) {
      debugPrint('Fehler beim Bereinigen alter Token-Zuordnungen: $e');
    }
  }

  static Future<void> _removeTokenForLastKnownUser() async {
    final token = _cachedToken;
    final userId = _lastSyncedUserId;

    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      return;
    }

    try {
      await _supa
          .from('push_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);

      debugPrint('Push Token für ausgeloggten User entfernt: $userId');
      _lastSyncedUserId = null;
    } catch (e) {
      debugPrint('Fehler beim Entfernen des Tokens nach Logout: $e');
    }
  }

  static Future<void> _upsertToken({
    required String userId,
    required String token,
  }) async {
    await _supa.from('push_tokens').upsert(
      {
        'user_id': userId,
        'token': token,
        'fcm_token': token,
        'platform': _platformName(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,token',
    );
  }

  static void _showForegroundMessageIfNeeded(RemoteMessage message) {
    final data = message.data;
    final conversationId = data['conversation_id']?.toString();

    if (conversationId != null &&
        conversationId.isNotEmpty &&
        conversationId == _currentOpenConversationId) {
      debugPrint(
        'Foreground Push unterdrückt: derselbe Chat ist bereits offen',
      );
      return;
    }

    final context = appNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('Kein Context für Foreground-Snackbar verfügbar');
      return;
    }

    final notification = message.notification;

    final title = (notification?.title?.trim().isNotEmpty ?? false)
        ? notification!.title!.trim()
        : (data['other_display_name']?.toString().trim().isNotEmpty ?? false)
            ? data['other_display_name'].toString().trim()
            : 'Neue Nachricht';

    String body;
    if (notification?.body?.trim().isNotEmpty ?? false) {
      body = notification!.body!.trim();
    } else {
      final messageType = data['message_type']?.toString() ?? 'text';
      final rawBody = data['body']?.toString().trim() ?? '';

      if (messageType == 'image') {
        body = '📷 Bild';
      } else if (messageType == 'short') {
        body = '🎬 Short';
      } else {
        body = rawBody.isNotEmpty ? rawBody : 'Du hast eine neue Nachricht';
      }
    }

    final messageId = data['message_id']?.toString();
    final otherUserId = data['other_user_id']?.toString();
    final otherDisplayName = data['other_display_name']?.toString();
    final otherAvatarUrl = data['other_avatar_url']?.toString();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(body),
            ],
          ),
          action: (conversationId != null &&
                  conversationId.isNotEmpty &&
                  otherUserId != null &&
                  otherUserId.isNotEmpty)
              ? SnackBarAction(
                  label: 'Öffnen',
                  onPressed: () {
                    _openChatFromPayload(
                      conversationId: conversationId,
                      otherUserId: otherUserId,
                      otherDisplayName: otherDisplayName,
                      otherAvatarUrl: otherAvatarUrl,
                      initialMessageId: messageId,
                    );
                  },
                )
              : null,
        ),
      );
  }

  static void _handleMessageTap(RemoteMessage message) {
    final data = message.data;

    final messageId = data['message_id']?.toString();
    final conversationId = data['conversation_id']?.toString();
    final otherUserId = data['other_user_id']?.toString();
    final otherDisplayName = data['other_display_name']?.toString();
    final otherAvatarUrl = data['other_avatar_url']?.toString();

    debugPrint('Push angeklickt: $data');

    if (conversationId == null ||
        conversationId.isEmpty ||
        otherUserId == null ||
        otherUserId.isEmpty) {
      debugPrint('Push enthält keine vollständigen Chat-Daten');
      return;
    }

    _openChatFromPayload(
      conversationId: conversationId,
      otherUserId: otherUserId,
      otherDisplayName: otherDisplayName,
      otherAvatarUrl: otherAvatarUrl,
      initialMessageId: messageId,
    );
  }

  static void _openChatFromPayload({
    required String conversationId,
    required String otherUserId,
    String? otherDisplayName,
    String? otherAvatarUrl,
    String? initialMessageId,
  }) {
    if (_currentOpenConversationId == conversationId) {
      debugPrint('Push-Klick im offenen Chat -> springe zur Nachricht');

      if (initialMessageId != null &&
          initialMessageId.isNotEmpty &&
          _scrollToMessageCallback != null) {
        _scrollToMessageCallback!(initialMessageId);
      }
      return;
    }

    final now = DateTime.now();
    final isDuplicateOpen = _lastOpenedConversationId == conversationId &&
        _lastOpenedAt != null &&
        now.difference(_lastOpenedAt!).inMilliseconds < 1500;

    if (isDuplicateOpen) {
      debugPrint('Push-Klick dedupliziert');
      return;
    }

    _lastOpenedConversationId = conversationId;
    _lastOpenedAt = now;

    void doNavigate() {
      final navigator = appNavigatorKey.currentState;
      final context = appNavigatorKey.currentContext;

      if (navigator == null || context == null) {
        debugPrint('Navigator für Push-Navigation noch nicht bereit');
        return;
      }

      navigator.pushNamed(
        '/chat',
        arguments: {
          'conversationId': conversationId,
          'otherUserId': otherUserId,
          'otherDisplayName':
              (otherDisplayName != null && otherDisplayName.isNotEmpty)
                  ? otherDisplayName
                  : null,
          'otherAvatarUrl':
              (otherAvatarUrl != null && otherAvatarUrl.isNotEmpty)
                  ? otherAvatarUrl
                  : null,
          'initialMessageId':
              (initialMessageId != null && initialMessageId.isNotEmpty)
                  ? initialMessageId
                  : null,
        },
      );
    }

    final navigator = appNavigatorKey.currentState;
    final context = appNavigatorKey.currentContext;

    if (navigator == null || context == null) {
      Future.delayed(const Duration(milliseconds: 500), doNavigate);
      return;
    }

    doNavigate();
  }

  static String _platformName() {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}