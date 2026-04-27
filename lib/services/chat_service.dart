import 'package:supabase_flutter/supabase_flutter.dart';

class ConversationSummary {
  final String conversationId;
  final String otherUserId;

  final String? otherDisplayName;
  final String? otherAvatarUrl;

  final bool otherIsGold;
  final bool otherIsPremium;

  final String? lastMessage;
  final String lastMessageType;
  final String? lastMediaUrl;

  final DateTime? lastMessageAt;

  final int unreadCount;

  ConversationSummary({
    required this.conversationId,
    required this.otherUserId,
    this.otherDisplayName,
    this.otherAvatarUrl,
    required this.otherIsGold,
    required this.otherIsPremium,
    this.lastMessage,
    required this.lastMessageType,
    this.lastMediaUrl,
    this.lastMessageAt,
    required this.unreadCount,
  });
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'].toString(),
      conversationId: map['conversation_id'].toString(),
      senderId: map['sender_id'].toString(),
      body: (map['body'] ?? '').toString(),
      createdAt: DateTime.parse(map['created_at'].toString()),
    );
  }
}

class ChatService {
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

  static Future<bool> isUserBlocked(String otherUserId) async {
    final me = _requireUserId();

    try {
      final row = await _supa
          .from('user_blocks')
          .select('id')
          .or(
            'and(blocker_user_id.eq.$me,blocked_user_id.eq.$otherUserId),and(blocker_user_id.eq.$otherUserId,blocked_user_id.eq.$me)',
          )
          .maybeSingle();

      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Stream<Map<String, int>> streamUnreadCounts() {
    final me = _requireUserId();

    return _supa.from('messages').stream(primaryKey: ['id']).map((rows) {
      final map = <String, int>{};

      for (final r in rows) {
        final recipientId = r['recipient_id']?.toString();
        final isRead = r['is_read'] == true;
        if (recipientId != me || isRead) continue;

        final cid = r['conversation_id']?.toString();
        if (cid == null) continue;

        map[cid] = (map[cid] ?? 0) + 1;
      }

      return map;
    });
  }

  static Future<String> getOrCreateConversationId(String otherUserId) async {
    _requireUserId();

    final res = await _supa.rpc(
      'get_or_create_conversation',
      params: {'other_user': otherUserId},
    );

    if (res == null) {
      throw Exception('RPC get_or_create_conversation gab null zurück.');
    }

    if (res is String) return res;
    if (res is Map && res['id'] != null) return res['id'].toString();
    return res.toString();
  }

  static Future<void> markConversationRead(String conversationId) async {
    final me = _requireUserId();

    await _supa
        .from('messages')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toIso8601String(),
        })
        .eq('conversation_id', conversationId)
        .eq('recipient_id', me)
        .eq('is_read', false);
  }

  static Future<List<ConversationSummary>> loadConversationList({
    int limit = 80,
  }) async {
    final me = _requireUserId();

    final blockedUserIds = await _loadBlockedUserIds();
    final deletedUserIds = await _loadDeletedUserIds();

    final convoRows = await _supa
        .from('conversations')
        .select('id, user1_id, user2_id, created_at')
        .or('user1_id.eq.$me,user2_id.eq.$me')
        .order('created_at', ascending: false)
        .limit(limit);

    final convosRaw = (convoRows as List).cast<Map<String, dynamic>>();
    if (convosRaw.isEmpty) return [];

    final convos = convosRaw.where((c) {
      final a = c['user1_id'].toString();
      final b = c['user2_id'].toString();
      final other = (a == me) ? b : a;

      if (blockedUserIds.contains(other)) return false;
      if (deletedUserIds.contains(other)) return false;

      return true;
    }).toList();

    if (convos.isEmpty) return [];

    final convoIds = convos.map((c) => c['id'].toString()).toList();

    final Map<String, int> unreadByConvo = {
      for (final id in convoIds) id: 0,
    };

    try {
      final unreadRows = await _supa
          .from('messages')
          .select('conversation_id')
          .eq('recipient_id', me)
          .eq('is_read', false)
          .inFilter('conversation_id', convoIds);

      final unreadList = (unreadRows as List).cast<Map<String, dynamic>>();
      for (final row in unreadList) {
        final cid = row['conversation_id']?.toString();
        if (cid == null) continue;
        unreadByConvo[cid] = (unreadByConvo[cid] ?? 0) + 1;
      }
    } catch (_) {}

    final msgRows = await _supa
        .from('messages')
        .select(
          'id, conversation_id, sender_id, recipient_id, body, created_at, is_read, message_type, media_url',
        )
        .inFilter('conversation_id', convoIds)
        .order('created_at', ascending: false)
        .limit(600);

    final msgs = (msgRows as List).cast<Map<String, dynamic>>();
    final Map<String, Map<String, dynamic>> lastMsgByConvo = {};

    for (final m in msgs) {
      final cid = m['conversation_id']?.toString();
      if (cid == null) continue;
      lastMsgByConvo.putIfAbsent(cid, () => m);
    }

    final otherUserIds = <String>{};
    for (final c in convos) {
      final a = c['user1_id'].toString();
      final b = c['user2_id'].toString();
      final other = (a == me) ? b : a;
      otherUserIds.add(other);
    }

    Map<String, Map<String, dynamic>> profileByUser = {};
    if (otherUserIds.isNotEmpty) {
      try {
        final profRows = await _supa
            .from('profiles')
            .select(
              'user_id, display_name, avatar_url, is_gold, is_premium, is_deleted, deleted_at',
            )
            .inFilter('user_id', otherUserIds.toList());

        final list = (profRows as List).cast<Map<String, dynamic>>();

        final filteredProfiles = list.where((p) {
          final isDeleted = p['is_deleted'] == true;
          final hasDeletedAt = p['deleted_at'] != null;
          return !isDeleted && !hasDeletedAt;
        }).toList();

        profileByUser = {
          for (final p in filteredProfiles) p['user_id'].toString(): p,
        };
      } catch (_) {}
    }

    final result = <ConversationSummary>[];

    for (final c in convos) {
      final cid = c['id'].toString();
      final a = c['user1_id'].toString();
      final b = c['user2_id'].toString();
      final other = (a == me) ? b : a;

      if (deletedUserIds.contains(other)) {
        continue;
      }

      final profile = profileByUser[other];
      if (profile == null) {
        continue;
      }

      final lastMsg = lastMsgByConvo[cid];

      result.add(
        ConversationSummary(
          conversationId: cid,
          otherUserId: other,
          otherDisplayName: profile['display_name']?.toString(),
          otherAvatarUrl: profile['avatar_url']?.toString(),
          otherIsGold: profile['is_gold'] == true,
          otherIsPremium: profile['is_premium'] == true,
          lastMessage: (lastMsg?['body'] ?? '').toString(),
          lastMessageType: (lastMsg?['message_type'] ?? 'text').toString(),
          lastMediaUrl: lastMsg?['media_url']?.toString(),
          lastMessageAt: lastMsg?['created_at'] != null
              ? DateTime.tryParse(lastMsg!['created_at'].toString())
              : null,
          unreadCount: unreadByConvo[cid] ?? 0,
        ),
      );
    }

    result.sort((x, y) {
      final ax = x.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final ay = y.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ay.compareTo(ax);
    });

    return result;
  }

  static Stream<List<ChatMessage>> streamMessages(String conversationId) {
    _requireUserId();

    return _supa
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map(
          (rows) => rows
              .where(
                (row) => row['conversation_id']?.toString() == conversationId,
              )
              .map((row) => ChatMessage.fromMap(row))
              .toList(),
        );
  }

  static Future<void> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final me = _requireUserId();
    final text = body.trim();
    if (text.isEmpty) return;

    final convo = await _supa
        .from('conversations')
        .select('user1_id, user2_id')
        .eq('id', conversationId)
        .maybeSingle();

    if (convo == null) {
      throw Exception('Conversation nicht gefunden.');
    }

    final user1 = convo['user1_id']?.toString();
    final user2 = convo['user2_id']?.toString();

    if (user1 == null || user2 == null) {
      throw Exception('Conversation ist unvollständig.');
    }

    final otherUserId = user1 == me ? user2 : user1;

    if (await isUserBlocked(otherUserId)) {
      throw Exception('BLOCKED');
    }

    final deletedUserIds = await _loadDeletedUserIds();
    if (deletedUserIds.contains(otherUserId)) {
      throw Exception('USER_DELETED');
    }

    await _supa.rpc(
      'send_message',
      params: {
        'p_conversation_id': conversationId,
        'p_other_user_id': otherUserId,
        'p_body': text,
      },
    );
  }

  static Future<void> deleteConversation(String conversationId) async {
    _requireUserId();
    await _supa.from('messages').delete().eq('conversation_id', conversationId);
    await _supa.from('conversations').delete().eq('id', conversationId);
  }
}