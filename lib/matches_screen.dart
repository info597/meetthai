import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n/app_strings.dart';
import 'services/chat_service.dart';
import 'services/match_service.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final _supa = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  final List<Map<String, String?>> _items = [];

  bool get _loggedIn => _supa.auth.currentUser != null;

  AppStrings get _t => AppStrings.of(context);

  @override
  void initState() {
    super.initState();
    _refreshScreen();
  }

  Future<void> _refreshScreen() async {
    await _load();
  }

  Future<Set<String>> _loadBlockedUserIds() async {
    final me = _supa.auth.currentUser;
    if (me == null) return <String>{};

    try {
      final rows = await _supa
          .from('user_blocks')
          .select('blocker_user_id, blocked_user_id')
          .or(
            'blocker_user_id.eq.${me.id},blocked_user_id.eq.${me.id}',
          );

      final blocked = <String>{};

      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final blocker = row['blocker_user_id']?.toString();
        final blockedUser = row['blocked_user_id']?.toString();

        if (blocker == me.id && blockedUser != null && blockedUser.isNotEmpty) {
          blocked.add(blockedUser);
        } else if (blockedUser == me.id &&
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

  Future<Set<String>> _loadDeletedUserIds() async {
    try {
      final rows = await _supa
          .from('profiles')
          .select('user_id')
          .eq('is_deleted', true);

      return (rows as List)
          .map((e) => (e['user_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      try {
        final rows = await _supa
            .from('profiles')
            .select('user_id')
            .not('deleted_at', 'is', null);

        return (rows as List)
            .map((e) => (e['user_id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet();
      } catch (_) {
        return <String>{};
      }
    }
  }

  Future<void> _load() async {
    if (!_loggedIn) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _t.loginRequired;
        _items.clear();
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
    });

    try {
      final blockedUserIds = await _loadBlockedUserIds();
      final deletedUserIds = await _loadDeletedUserIds();
      final otherUserIds = await MatchService.loadMyMatchUserIds();

      final visibleUserIds = otherUserIds
          .where((id) => !blockedUserIds.contains(id))
          .where((id) => !deletedUserIds.contains(id))
          .toList();

      if (visibleUserIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _items.clear();
        });
        return;
      }

      Map<String, Map<String, dynamic>> profileById = {};

      try {
        final profRows = await _supa
            .from('profiles')
            .select(
              'user_id, display_name, avatar_url, is_online, last_seen, is_deleted, deleted_at',
            )
            .inFilter('user_id', visibleUserIds);

        final list = (profRows as List).cast<Map<String, dynamic>>();
        final filteredList = list.where((p) {
          final isDeleted = p['is_deleted'] == true;
          final hasDeletedAt = p['deleted_at'] != null;
          return !isDeleted && !hasDeletedAt;
        }).toList();

        profileById = {
          for (final p in filteredList) p['user_id'].toString(): p,
        };
      } catch (_) {}

      final loadedItems = <Map<String, String?>>[];

      for (final uid in visibleUserIds) {
        final p = profileById[uid];
        if (p == null) continue;

        final convoId = await ChatService.getOrCreateConversationId(uid);

        loadedItems.add({
          'userId': uid,
          'conversationId': convoId,
          'displayName': p['display_name']?.toString(),
          'avatarUrl': p['avatar_url']?.toString(),
          'isOnline': p['is_online']?.toString(),
          'lastSeen': p['last_seen']?.toString(),
        });
      }

      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(loadedItems);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _t.isGerman
            ? 'Fehler beim Laden der Matches: $e'
            : _t.isThai
                ? 'เกิดข้อผิดพลาดในการโหลดแมตช์: $e'
                : 'Error loading matches: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openChat(Map<String, String?> item) async {
    final otherUserId = (item['userId'] ?? '').trim();
    if (otherUserId.isEmpty) return;

    try {
      final conversationId = item['conversationId'] ??
          await ChatService.getOrCreateConversationId(otherUserId);

      if (!mounted) return;

      await Navigator.pushNamed(
        context,
        '/chat',
        arguments: {
          'conversationId': conversationId,
          'otherUserId': otherUserId,
          'otherDisplayName': item['displayName'],
          'otherAvatarUrl': item['avatarUrl'],
        },
      );

      if (!mounted) return;
      await _refreshScreen();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t.isGerman
                ? 'Chat konnte nicht geöffnet werden: $e'
                : _t.isThai
                    ? 'ไม่สามารถเปิดแชตได้: $e'
                    : 'Chat could not be opened: $e',
          ),
        ),
      );
    }
  }

  String _formatLastSeen(String? lastSeenRaw, String? isOnlineRaw) {
    final isOnline = isOnlineRaw == 'true' || isOnlineRaw == '1';

    if (isOnline) {
      if (_t.isThai) return 'ออนไลน์';
      return 'Online';
    }

    if (lastSeenRaw == null || lastSeenRaw.trim().isEmpty) {
      if (_t.isThai) return 'ออฟไลน์';
      return _t.isGerman ? 'Offline' : 'Offline';
    }

    final dt = DateTime.tryParse(lastSeenRaw);
    if (dt == null) {
      if (_t.isThai) return 'ออฟไลน์';
      return _t.isGerman ? 'Offline' : 'Offline';
    }

    final now = DateTime.now().toUtc();
    final diff = now.difference(dt.toUtc());

    if (diff.inMinutes < 2) {
      if (_t.isGerman) return 'Gerade eben';
      if (_t.isThai) return 'เมื่อสักครู่';
      return 'Just now';
    }

    if (diff.inMinutes < 60) {
      if (_t.isGerman) return 'Vor ${diff.inMinutes} Min';
      if (_t.isThai) return '${diff.inMinutes} นาทีที่แล้ว';
      return '${diff.inMinutes} min ago';
    }

    if (diff.inHours < 24) {
      if (_t.isGerman) return 'Vor ${diff.inHours} Std';
      if (_t.isThai) return '${diff.inHours} ชั่วโมงที่แล้ว';
      return '${diff.inHours} h ago';
    }

    if (_t.isGerman) return 'Vor ${diff.inDays} Tagen';
    if (_t.isThai) return '${diff.inDays} วันที่แล้ว';
    return '${diff.inDays} days ago';
  }

  Widget _buildLoggedOutState() {
    return Scaffold(
      appBar: AppBar(title: Text(_t.matches)),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/auth'),
          child: Text(_t.toLogin),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _t.isGerman
              ? 'Noch keine Matches.\nLike ein paar Profile – wenn es gegenseitig ist, erscheint es hier.'
              : _t.isThai
                  ? 'ยังไม่มีแมตช์\nลองกดไลก์โปรไฟล์สักหน่อย — ถ้าชอบกันทั้งสองฝ่าย จะขึ้นที่นี่'
                  : 'No matches yet.\nLike a few profiles — if the feeling is mutual, they will appear here.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildMatchesList() {
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final it = _items[i];

        final name = (it['displayName'] ?? '').trim();
        final avatar = (it['avatarUrl'] ?? '').trim();

        final presence = _formatLastSeen(
          it['lastSeen'],
          it['isOnline'],
        );

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty ? const Icon(Icons.person) : null,
          ),
          title: Text(
            name.isEmpty
                ? (_t.isGerman
                    ? 'Match'
                    : _t.isThai
                        ? 'แมตช์'
                        : 'Match')
                : name,
          ),
          subtitle: Text(
            _t.isGerman
                ? 'Tippe um zu chatten • $presence'
                : _t.isThai
                    ? 'แตะเพื่อแชต • $presence'
                    : 'Tap to chat • $presence',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openChat(it),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) {
      return _buildLoggedOutState();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t.matches),
        actions: [
          IconButton(
            onPressed: _refreshScreen,
            icon: const Icon(Icons.refresh),
            tooltip: _t.refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _items.isEmpty
                  ? _buildEmptyState()
                  : _buildMatchesList(),
    );
  }
}