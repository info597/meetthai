import 'dart:async';

import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n/app_strings.dart';
import 'services/chat_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with WidgetsBindingObserver {
  final SupabaseClient _supa = Supabase.instance.client;

  bool _loading = true;
  bool _backgroundRefreshing = false;
  bool _isFetching = false;
  String? _error;

  List<ConversationSummary> _items = [];

  RealtimeChannel? _chatListChannel;
  Timer? _reloadDebounce;

  bool get _loggedIn => _supa.auth.currentUser != null;

  AppStrings get _t => AppStrings.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reloadDebounce?.cancel();
    _unsubscribeRealtime();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _scheduleBackgroundReload();
      _startRealtime();
    }
  }

  Future<void> _bootstrap() async {
    await _loadChats(showLoader: true);
    _startRealtime();
  }

  void _startRealtime() {
    _unsubscribeRealtime();

    final user = _supa.auth.currentUser;
    if (user == null) return;

    _chatListChannel = _supa.channel('chat-list-${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          final row = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;

          final conversationId = row['conversation_id']?.toString();
          if (conversationId == null || conversationId.isEmpty) return;

          final affectsVisibleChat = _items.any(
            (item) => item.conversationId == conversationId,
          );

          if (affectsVisibleChat || payload.eventType == PostgresChangeEvent.insert) {
            _scheduleBackgroundReload();
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'conversations',
        callback: (_) {
          _scheduleBackgroundReload();
        },
      )
      ..subscribe((status, [error]) {
        debugPrint('[ChatListScreen] realtime status=$status error=$error');
      });
  }

  void _unsubscribeRealtime() {
    final channel = _chatListChannel;
    _chatListChannel = null;

    if (channel != null) {
      unawaited(_supa.removeChannel(channel));
    }
  }

  void _scheduleBackgroundReload() {
    if (!mounted || !_loggedIn) return;

    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      await _loadChats(showLoader: false);
    });
  }

  Future<void> _loadChats({required bool showLoader}) async {
    if (!_loggedIn) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _t.loginRequired;
        _items = [];
        _backgroundRefreshing = false;
      });
      return;
    }

    if (_isFetching) return;
    _isFetching = true;

    if (showLoader) {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _backgroundRefreshing = true;
        });
      }
    }

    try {
      final list = await ChatService.loadConversationList(limit: 120);

      if (!mounted) return;

      setState(() {
        _items = list;
        _loading = false;
        _error = null;
        _backgroundRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _t.isGerman
            ? 'Fehler beim Laden der Chats: $e'
            : _t.isThai
                ? 'เกิดข้อผิดพลาดในการโหลดแชต: $e'
                : 'Error loading chats: $e';
        _loading = false;
        _backgroundRefreshing = false;

        if (showLoader) {
          _items = [];
        }
      });
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _refreshAll() async {
    await _loadChats(showLoader: false);
  }

  Future<void> _openChat(ConversationSummary c) async {
    final isBlocked = await ChatService.isUserBlocked(c.otherUserId);

    if (!mounted) return;

    if (isBlocked) {
      await _loadChats(showLoader: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t.isGerman
                ? 'Dieser Chat ist nicht mehr verfügbar.'
                : _t.isThai
                    ? 'แชตนี้ไม่พร้อมใช้งานอีกต่อไป'
                    : 'This chat is no longer available.',
          ),
        ),
      );
      return;
    }

    await Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'conversationId': c.conversationId,
        'otherUserId': c.otherUserId,
        'otherDisplayName': c.otherDisplayName,
        'otherAvatarUrl': c.otherAvatarUrl,
      },
    );

    if (!mounted) return;
    await _loadChats(showLoader: false);
  }

  String _formatSubtitle(ConversationSummary c) {
    switch (c.lastMessageType) {
      case 'image':
        return _t.isGerman
            ? '📷 Bild'
            : _t.isThai
                ? '📷 รูปภาพ'
                : '📷 Image';
      case 'short':
        return _t.isGerman
            ? '🎬 Short'
            : _t.isThai
                ? '🎬 คลิปสั้น'
                : '🎬 Short';
      case 'text':
      default:
        final text = (c.lastMessage ?? '').trim();
        if (text.isNotEmpty) return text;

        return _t.isGerman
            ? 'Neue Nachricht'
            : _t.isThai
                ? 'ข้อความใหม่'
                : 'New message';
    }
  }

  String _formatLastMessageTime(DateTime? dt) {
    if (dt == null) return '';

    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(local.year, local.month, local.day);

    if (msgDay == today) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    final diffDays = today.difference(msgDay).inDays;
    if (diffDays == 1) {
      if (_t.isGerman) return 'Gestern';
      if (_t.isThai) return 'เมื่อวาน';
      return 'Yesterday';
    }

    final d = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$d.$mo.';
  }

  Widget _buildLoggedOutState() {
    return Scaffold(
      appBar: AppBar(title: Text(_t.chats)),
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
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _t.isGerman
                          ? 'Noch keine Chats.\nSobald du ein Match hast, erscheint es hier.'
                          : _t.isThai
                              ? 'ยังไม่มีแชต\nเมื่อคุณมีแมตช์ แชตจะปรากฏที่นี่'
                              : 'No chats yet.\nAs soon as you have a match, it will appear here.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _refreshAll,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(_t.refresh),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsList() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = _items[i];

          final name = (c.otherDisplayName ?? '').trim();
          final avatar = (c.otherAvatarUrl ?? '').trim();
          final subtitle = _formatSubtitle(c);
          final unread = c.unreadCount;
          final timeLabel = _formatLastMessageTime(c.lastMessageAt);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty ? const Icon(Icons.person) : null,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name.isEmpty
                        ? (_t.isGerman
                            ? 'Chat'
                            : _t.isThai
                                ? 'แชต'
                                : 'Chat')
                        : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:
                          unread > 0 ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  _unreadPill(unread),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                  color: unread > 0 ? Colors.black87 : Colors.black54,
                ),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (timeLabel.isNotEmpty)
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: unread > 0 ? Colors.pink : Colors.black45,
                      fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: () => _openChat(c),
          );
        },
      ),
    );
  }

  Widget _unreadPill(int unread) {
    final text = unread > 99 ? '99+' : '$unread';

    return badges.Badge(
      position: badges.BadgePosition.topEnd(top: -8, end: -8),
      badgeAnimation: const badges.BadgeAnimation.scale(),
      badgeStyle: const badges.BadgeStyle(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      badgeContent: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: const SizedBox(width: 16, height: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) {
      return _buildLoggedOutState();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t.chats),
        actions: [
          if (_backgroundRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
            tooltip: _t.refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
              ? _buildErrorState()
              : _items.isEmpty
                  ? _buildEmptyState()
                  : _buildChatsList(),
    );
  }
}