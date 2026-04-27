import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UnreadService extends ChangeNotifier {
  UnreadService._();
  static final UnreadService instance = UnreadService._();

  final _supa = Supabase.instance.client;

  RealtimeChannel? _channel;

  bool _initialized = false;
  bool _loading = false;
  int _totalUnread = 0;
  String? _currentUserId;

  int get totalUnread => _totalUnread;
  bool get loading => _loading;
  bool get initialized => _initialized;

  Future<void> init() async {
    final user = _supa.auth.currentUser;

    if (user == null) {
      await disposeService();
      await reset();
      return;
    }

    final userChanged = _currentUserId != user.id;
    final needsInit = !_initialized || userChanged;

    if (!needsInit) {
      await refresh();
      return;
    }

    await disposeService();

    _currentUserId = user.id;
    _initialized = true;

    await refresh();
    _subscribeRealtime(user.id);
  }

  Future<void> refresh() async {
    final user = _supa.auth.currentUser;
    if (user == null) {
      await reset();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      final rows = await _supa
          .from('messages')
          .select('id')
          .eq('recipient_id', user.id)
          .eq('is_read', false);

      _totalUnread = (rows as List).length;
    } catch (e) {
      debugPrint('[UnreadService] refresh error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> reset() async {
    _loading = false;
    _totalUnread = 0;
    _currentUserId = null;
    notifyListeners();
  }

  Future<void> disposeService() async {
    if (_channel != null) {
      await _supa.removeChannel(_channel!);
      _channel = null;
    }
    _initialized = false;
  }

  void clear() {
    _loading = false;
    _totalUnread = 0;
    notifyListeners();
  }

  void _subscribeRealtime(String userId) {
    final channelName = 'unread-messages-$userId';

    _channel = _supa.channel(channelName)
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) async {
          final row = payload.newRecord;
          final recipientId = row['recipient_id']?.toString();
          final isRead = row['is_read'] == true;

          if (recipientId == userId && !isRead) {
            _totalUnread++;
            notifyListeners();
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        callback: (payload) async {
          final oldRow = payload.oldRecord;
          final newRow = payload.newRecord;

          final oldRecipientId = oldRow['recipient_id']?.toString();
          final newRecipientId = newRow['recipient_id']?.toString();

          final oldIsRead = oldRow['is_read'] == true;
          final newIsRead = newRow['is_read'] == true;

          if (oldRecipientId == userId &&
              newRecipientId == userId &&
              !oldIsRead &&
              newIsRead) {
            if (_totalUnread > 0) {
              _totalUnread--;
              notifyListeners();
            } else {
              await refresh();
            }
          }
        },
      )
      ..subscribe((status, [error]) async {
        debugPrint('[UnreadService] realtime status: $status error=$error');

        if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          await refresh();
        }
      });
  }
}