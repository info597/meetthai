import 'package:supabase_flutter/supabase_flutter.dart';

class MatchService {
  static final SupabaseClient _supa = Supabase.instance.client;

  static String _requireUserId() {
    final user = _supa.auth.currentUser;
    if (user == null) {
      throw Exception('Nicht eingeloggt.');
    }
    return user.id;
  }

  static Future<Set<String>> _loadBlockedUserIds() async {
    final me = _requireUserId();

    try {
      final rows = await _supa
          .from('user_blocks')
          .select('blocker_user_id, blocked_user_id')
          .or('blocker_user_id.eq.$me,blocked_user_id.eq.$me');

      final blocked = <String>{};

      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final blocker = row['blocker_user_id']?.toString();
        final blockedUser = row['blocked_user_id']?.toString();

        if (blocker == me && blockedUser != null && blockedUser.isNotEmpty) {
          blocked.add(blockedUser);
        } else if (blockedUser == me &&
            blocker != null &&
            blocker.isNotEmpty) {
          blocked.add(blocker);
        }
      }

      return blocked;
    } catch (_) {
      return <String>{};
    }
  }

  static Future<Set<String>> _loadDeletedUserIds() async {
    try {
      final rows =
          await _supa.from('profiles').select('user_id').eq('is_deleted', true);

      return (rows as List)
          .map((row) => (row['user_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      try {
        final rows = await _supa
            .from('profiles')
            .select('user_id')
            .not('deleted_at', 'is', null);

        return (rows as List)
            .map((row) => (row['user_id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet();
      } catch (_) {
        return <String>{};
      }
    }
  }

  static Future<List<String>> loadMyMatchUserIds() async {
    final me = _requireUserId();

    final blockedUserIds = await _loadBlockedUserIds();
    final deletedUserIds = await _loadDeletedUserIds();

    final rows = await _supa
        .from('matches')
        .select('user_a, user_b')
        .or('user_a.eq.$me,user_b.eq.$me')
        .order('created_at', ascending: false);

    final result = <String>[];

    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final a = row['user_a']?.toString();
      final b = row['user_b']?.toString();

      if (a == null || b == null) continue;

      final otherUserId = a == me ? b : a;

      if (otherUserId.isEmpty) continue;
      if (blockedUserIds.contains(otherUserId)) continue;
      if (deletedUserIds.contains(otherUserId)) continue;

      if (!result.contains(otherUserId)) {
        result.add(otherUserId);
      }
    }

    return result;
  }

  static Future<bool> isMatchedWith(String otherUserId) async {
    final me = _requireUserId();

    final blockedUserIds = await _loadBlockedUserIds();
    if (blockedUserIds.contains(otherUserId)) return false;

    final deletedUserIds = await _loadDeletedUserIds();
    if (deletedUserIds.contains(otherUserId)) return false;

    final row = await _supa
        .from('matches')
        .select('id')
        .or(
          'and(user_a.eq.$me,user_b.eq.$otherUserId),and(user_a.eq.$otherUserId,user_b.eq.$me)',
        )
        .maybeSingle();

    return row != null;
  }

  static Future<String?> getMatchConversationId(String otherUserId) async {
    final me = _requireUserId();

    final blockedUserIds = await _loadBlockedUserIds();
    if (blockedUserIds.contains(otherUserId)) return null;

    final deletedUserIds = await _loadDeletedUserIds();
    if (deletedUserIds.contains(otherUserId)) return null;

    final row = await _supa
        .from('matches')
        .select('conversation_id')
        .or(
          'and(user_a.eq.$me,user_b.eq.$otherUserId),and(user_a.eq.$otherUserId,user_b.eq.$me)',
        )
        .maybeSingle();

    final conversationId = row?['conversation_id']?.toString();
    if (conversationId == null || conversationId.isEmpty) return null;

    return conversationId;
  }
}