import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'blocked_users_screen.dart';
import 'chat_list_screen.dart';
import 'discovery_screen.dart';
import 'i18n/app_strings.dart';
import 'likes_screen.dart';
import 'matches_screen.dart';
import 'profile_browser_screen.dart';
import 'profile_preview_screen.dart';
import 'services/chat_service.dart';
import 'services/subscription_state.dart';
import 'settings_screen.dart';
import 'upgrade_screen.dart';
import 'widgets/app_logo.dart';
import 'main.dart' show appLocaleController;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supa = Supabase.instance.client;
  final _subscription = SubscriptionState.instance;

  int _index = 0;

  bool _loadingPlan = true;
  String _planLabel = 'FREE';

  int _likesCount = 0;
  int _likesBadgeCount = 0;
  DateTime? _likesSeenAt;
  bool _loadingLikes = true;

  int _chatUnreadCount = 0;
  bool _loadingChatUnread = true;

  String _displayName = '';
  String? _avatarUrl;

  bool _loadingPreviewProfiles = true;
  List<Map<String, dynamic>> _previewProfiles = [];

  StreamSubscription<List<Map<String, dynamic>>>? _likesSub;
  RealtimeChannel? _chatUnreadChannel;
  Timer? _chatUnreadReloadDebounce;

  @override
  void initState() {
    super.initState();
    _subscription.addListener(_onSubscriptionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshHomeData());
      _startLikesRealtime();
      _startChatUnreadRealtime();
    });
  }

  @override
  void dispose() {
    _subscription.removeListener(_onSubscriptionChanged);
    _likesSub?.cancel();
    _chatUnreadReloadDebounce?.cancel();
    _unsubscribeChatUnreadRealtime();
    super.dispose();
  }

  void _onSubscriptionChanged() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyPlanFromSubscription();
    });
  }

  Future<void> _refreshHomeData() async {
    await Future.wait([
      _subscription.refresh(),
      _loadLikesCount(),
      _loadChatUnreadCount(),
      _loadProfilePreview(),
      _loadPreviewProfiles(),
    ]);

    if (!mounted) return;
    _applyPlanFromSubscription();
  }

  void _applyPlanFromSubscription() {
    final isGold = _subscription.isGold;
    final isPremium = _subscription.isPremium;

    String label;

    if (isGold) {
      label = 'GOLD';
    } else if (isPremium) {
      label = 'PREMIUM';
    } else {
      label = 'FREE';
    }

    if (!mounted) return;

    setState(() {
      _planLabel = label;
      _loadingPlan = false;
    });
  }

  Future<void> _loadProfilePreview() async {
    final user = _supa.auth.currentUser;
    if (user == null) return;

    try {
      final row = await _supa
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _displayName = (row?['display_name'] ?? '').toString().trim();
        _avatarUrl = row?['avatar_url']?.toString();
      });
    } catch (_) {}
  }

  Future<Set<String>> _loadBlockedUserIds() async {
    final me = _supa.auth.currentUser;
    if (me == null) return <String>{};

    try {
      final rows = await _supa
          .from('user_blocks')
          .select('blocker_user_id, blocked_user_id')
          .or('blocker_user_id.eq.${me.id},blocked_user_id.eq.${me.id}');

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

  Future<void> _loadPreviewProfiles() async {
    final user = _supa.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _previewProfiles = [];
        _loadingPreviewProfiles = false;
      });
      return;
    }

    setState(() {
      _loadingPreviewProfiles = true;
    });

    try {
      final blockedUserIds = await _loadBlockedUserIds();
      final deletedUserIds = await _loadDeletedUserIds();

      final rows = await _supa
          .from('profiles')
          .select(
            'user_id, display_name, avatar_url, city, origin_country, is_online, is_deleted, deleted_at',
          )
          .neq('user_id', user.id)
          .eq('is_hidden', false)
          .limit(30);

      final filtered = (rows as List)
          .cast<Map<String, dynamic>>()
          .where((p) {
            final userId = (p['user_id'] ?? '').toString();
            final isDeleted = p['is_deleted'] == true;
            final hasDeletedAt = p['deleted_at'] != null;

            if (userId.isEmpty) return false;
            if (blockedUserIds.contains(userId)) return false;
            if (deletedUserIds.contains(userId)) return false;
            if (isDeleted || hasDeletedAt) return false;

            return true;
          })
          .take(6)
          .toList();

      if (!mounted) return;

      setState(() {
        _previewProfiles = filtered;
        _loadingPreviewProfiles = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewProfiles = [];
        _loadingPreviewProfiles = false;
      });
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    return DateTime.tryParse(text);
  }

  Future<void> _loadLikesCount() async {
    final user = _supa.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _likesCount = 0;
        _likesBadgeCount = 0;
        _likesSeenAt = null;
        _loadingLikes = false;
      });
      return;
    }

    setState(() {
      _loadingLikes = true;
    });

    try {
      final profileRow = await _supa
          .from('profiles')
          .select('likes_seen_at')
          .eq('user_id', user.id)
          .maybeSingle();

      final likesSeenAt = _parseDateTime(profileRow?['likes_seen_at']);

      final rows = await _supa
          .from('likes')
          .select('id, created_at')
          .eq('to_user_id', user.id);

      final list = (rows as List).cast<Map<String, dynamic>>();
      final total = list.length;

      int unread = 0;

      if (likesSeenAt == null) {
        unread = total;
      } else {
        for (final row in list) {
          final createdAt = _parseDateTime(row['created_at']);
          if (createdAt == null) continue;

          if (createdAt.toUtc().isAfter(likesSeenAt.toUtc())) {
            unread++;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _likesCount = total < 0 ? 0 : total;
        _likesBadgeCount = unread < 0 ? 0 : unread;
        _likesSeenAt = likesSeenAt;
        _loadingLikes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _likesCount = 0;
        _likesBadgeCount = 0;
        _likesSeenAt = null;
        _loadingLikes = false;
      });
    }
  }

  Future<void> _loadChatUnreadCount() async {
    final user = _supa.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _chatUnreadCount = 0;
        _loadingChatUnread = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loadingChatUnread = true;
      });
    }

    try {
      final conversations = await ChatService.loadConversationList(limit: 120);

      int unread = 0;
      for (final c in conversations) {
        unread += c.unreadCount;
      }

      if (!mounted) return;
      setState(() {
        _chatUnreadCount = unread < 0 ? 0 : unread;
        _loadingChatUnread = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chatUnreadCount = 0;
        _loadingChatUnread = false;
      });
    }
  }

  void _startLikesRealtime() {
    _likesSub?.cancel();

    final user = _supa.auth.currentUser;
    if (user == null) return;

    _likesSub = _supa
        .from('likes')
        .stream(primaryKey: ['id'])
        .eq('to_user_id', user.id)
        .listen((_) {
      if (!mounted) return;
      unawaited(_loadLikesCount());
    });
  }

  void _startChatUnreadRealtime() {
    _unsubscribeChatUnreadRealtime();

    final user = _supa.auth.currentUser;
    if (user == null) return;

    _chatUnreadChannel = _supa.channel('home-chat-unread-${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          final row = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;

          final recipientId = row['recipient_id']?.toString();
          final senderId = row['sender_id']?.toString();

          if (recipientId != user.id && senderId != user.id) return;

          _scheduleChatUnreadReload();
        },
      )
      ..subscribe((status, [error]) {
        debugPrint('[HomeScreen] chat unread realtime status=$status error=$error');
      });
  }

  void _unsubscribeChatUnreadRealtime() {
    final channel = _chatUnreadChannel;
    _chatUnreadChannel = null;

    if (channel != null) {
      unawaited(_supa.removeChannel(channel));
    }
  }

  void _scheduleChatUnreadReload() {
    if (!mounted) return;

    _chatUnreadReloadDebounce?.cancel();
    _chatUnreadReloadDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      unawaited(_loadChatUnreadCount());
    });
  }

  void _restartRealtimeIfNeeded() {
    _startLikesRealtime();
    _startChatUnreadRealtime();
  }

  Future<void> _markLikesAsSeen() async {
    final user = _supa.auth.currentUser;
    if (user == null) return;

    final seenAt = DateTime.now().toUtc();

    if (mounted) {
      setState(() {
        _likesSeenAt = seenAt;
        _likesBadgeCount = 0;
        _loadingLikes = false;
      });
    }

    try {
      await _supa.from('profiles').upsert({
        'user_id': user.id,
        'likes_seen_at': seenAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (_) {}
  }

  Future<void> _openUpgrade() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const UpgradeScreen()),
    );

    if (!mounted) return;

    if (changed == true) {
      await _refreshHomeData();
      _restartRealtimeIfNeeded();
    }
  }

  Future<void> _openBlockedUsers() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );

    if (!mounted) return;
    await _refreshHomeData();
  }

  Future<void> _logout() async {
    await _likesSub?.cancel();
    _likesSub = null;
    _chatUnreadReloadDebounce?.cancel();
    _unsubscribeChatUnreadRealtime();
    await _supa.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
  }

  String _planRuleText(AppStrings t) {
    if (_planLabel == 'GOLD') {
      if (t.isGerman) return 'Unbegrenzte Likes • Alle Likes sichtbar';
      if (t.isThai) return 'ไลก์ไม่จำกัด • เห็นไลก์ทั้งหมด';
      return 'Unlimited likes • All likes visible';
    }

    if (_planLabel == 'PREMIUM') {
      if (t.isGerman) return '25 Likes / Tag • 25 Likes sichtbar';
      if (t.isThai) return '25 ไลก์ / วัน • เห็น 25 ไลก์';
      return '25 likes / day • 25 likes visible';
    }

    if (t.isGerman) return '10 Likes / Tag • 10 Likes sichtbar';
    if (t.isThai) return '10 ไลก์ / วัน • เห็น 10 ไลก์';
    return '10 likes / day • 10 likes visible';
  }

  Widget _buildCurrentScreen() {
    switch (_index) {
      case 0:
        return _buildDashboard();
      case 1:
        return const DiscoveryScreen();
      case 2:
        return const ProfileBrowserScreen();
      case 3:
        return const MatchesScreen();
      case 4:
        return const LikesScreen();
      case 5:
        return const ChatListScreen();
      case 6:
        return const ProfilePreviewScreen();
      default:
        return _buildDashboard();
    }
  }

  int _bottomNavSelectedIndex() {
    switch (_index) {
      case 0:
        return 0; // Dashboard
      case 1:
        return 1; // Swipes
      case 2:
        return 2; // Mitglieder
      case 4:
        return 3; // Likes
      case 5:
        return 4; // Chat
      case 6:
        return 5; // Profil
      default:
        return 0;
    }
  }

  Future<void> _onBottomNavSelected(int navIndex) async {
    final int targetIndex;

    switch (navIndex) {
      case 0:
        targetIndex = 0; // Dashboard
        break;
      case 1:
        targetIndex = 1; // Swipes
        break;
      case 2:
        targetIndex = 2; // Mitglieder
        break;
      case 3:
        targetIndex = 4; // Likes
        break;
      case 4:
        targetIndex = 5; // Chat
        break;
      case 5:
        targetIndex = 6; // Profil
        break;
      default:
        targetIndex = 0;
    }

    if (!mounted) return;

    setState(() {
      _index = targetIndex;
    });

    if (targetIndex == 4) {
      unawaited(_markLikesAsSeen());
    }

    if (targetIndex == 5) {
      await _loadChatUnreadCount();
    }
  }

  Widget _badgeContainer({
    required int count,
    required double fontSize,
    required EdgeInsets padding,
    required BoxConstraints constraints,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(999),
      ),
      constraints: constraints,
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBottomLikesIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.favorite_rounded),
        if (!_loadingLikes && _likesBadgeCount > 0)
          Positioned(
            right: -8,
            top: -6,
            child: _badgeContainer(
              count: _likesBadgeCount,
              fontSize: 9,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 16),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomChatsIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.chat_bubble_rounded),
        if (!_loadingChatUnread && _chatUnreadCount > 0)
          Positioned(
            right: -8,
            top: -6,
            child: _badgeContainer(
              count: _chatUnreadCount,
              fontSize: 9,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 16),
            ),
          ),
      ],
    );
  }

  Future<void> _openLanguageMenu() async {
    final t = AppStrings.of(context);

    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.settings_suggest_rounded),
                title: Text(t.systemLanguage),
                onTap: () => Navigator.pop(context, 'system'),
              ),
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: Text(t.germanLanguage),
                onTap: () => Navigator.pop(context, 'de'),
              ),
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: Text(t.englishLanguage),
                onTap: () => Navigator.pop(context, 'en'),
              ),
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: Text(t.thaiLanguage),
                onTap: () => Navigator.pop(context, 'th'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) return;

    switch (result) {
      case 'system':
        appLocaleController.useSystemLocale();
        break;
      case 'de':
        appLocaleController.setLocale(const Locale('de'));
        break;
      case 'en':
        appLocaleController.setLocale(const Locale('en'));
        break;
      case 'th':
        appLocaleController.setLocale(const Locale('th'));
        break;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openMoreMenu() async {
    final t = AppStrings.of(context);

    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: Text(
                  t.isGerman
                      ? 'Einstellungen'
                      : t.isThai
                          ? 'ตั้งค่า'
                          : 'Settings',
                ),
                onTap: () => Navigator.pop(context, 'settings'),
              ),
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: Text(t.language),
                onTap: () => Navigator.pop(context, 'language'),
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: Text(t.blockedUsers),
                onTap: () => Navigator.pop(context, 'blocked'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    if (result == 'blocked') {
      await _openBlockedUsers();
    } else if (result == 'language') {
      await _openLanguageMenu();
    } else if (result == 'settings') {
      await _openSettings();
    }
  }

  Widget _buildDashboard() {
    final t = AppStrings.of(context);
    final isGold = _planLabel == 'GOLD';
    final isPremium = _planLabel == 'PREMIUM';
    final userName = _displayName.isEmpty
        ? (t.isGerman
            ? 'Willkommen'
            : t.isThai
                ? 'ยินดีต้อนรับ'
                : 'Welcome')
        : _displayName;

    final helloText = t.isGerman
        ? 'Hallo, $userName 👋'
        : t.isThai
            ? 'สวัสดี, $userName 👋'
            : 'Hello, $userName 👋';

    final heroSub = t.isGerman
        ? 'Mehr Likes. Mehr Matches. Mehr Chats.'
        : t.isThai
            ? 'ไลก์มากขึ้น แมตช์มากขึ้น แชตมากขึ้น'
            : 'More likes. More matches. More chats.';

    final likesTitle =
        t.isGerman ? 'Deine Likes' : t.isThai ? 'ไลก์ของคุณ' : 'Your likes';

    final likesLoadingText = t.isGerman
        ? 'Likes werden geladen...'
        : t.isThai
            ? 'กำลังโหลดไลก์...'
            : 'Loading likes...';

    final likesLoadedText = t.isGerman
        ? 'Du hast aktuell $_likesCount eingegangene Likes.'
        : t.isThai
            ? 'ตอนนี้คุณมี $_likesCount ไลก์ที่เข้ามา'
            : 'You currently have $_likesCount incoming likes.';

    final likesOpenText =
        t.isGerman ? 'Likes öffnen' : t.isThai ? 'เปิดไลก์' : 'Open likes';

    final newProfilesText = t.isGerman
        ? 'Neue Profile ansehen'
        : t.isThai
            ? 'ดูโปรไฟล์ใหม่'
            : 'See new profiles';

    final openMatchesText = t.isGerman
        ? 'Deine Matches öffnen'
        : t.isThai
            ? 'เปิดแมตช์ของคุณ'
            : 'Open your matches';

    final readMessagesText = t.isGerman
        ? 'Nachrichten lesen'
        : t.isThai
            ? 'อ่านข้อความ'
            : 'Read messages';

    final upgradeSubtitle = isGold
        ? (t.isGerman
            ? 'Maximal freigeschaltet'
            : t.isThai
                ? 'ปลดล็อกสูงสุดแล้ว'
                : 'Fully unlocked')
        : (t.isGerman
            ? 'Mehr Sichtbarkeit & Likes'
            : t.isThai
                ? 'การมองเห็นและไลก์มากขึ้น'
                : 'More visibility & likes');

    final previewTitle = t.isGerman
        ? 'Vorschauprofile'
        : t.isThai
            ? 'โปรไฟล์ตัวอย่าง'
            : 'Preview profiles';

    final previewSub = t.isGerman
        ? 'Ein kleiner Vorgeschmack auf neue interessante Profile.'
        : t.isThai
            ? 'ตัวอย่างเล็ก ๆ ของโปรไฟล์ที่น่าสนใจใหม่ ๆ'
            : 'A small preview of interesting new profiles.';

    final noPreviewText = t.isGerman
        ? 'Aktuell keine Vorschauprofile verfügbar.'
        : t.isThai
            ? 'ขณะนี้ยังไม่มีโปรไฟล์ตัวอย่าง'
            : 'No preview profiles available at the moment.';

    final discoverNowText =
        t.isGerman ? 'Jetzt suchen' : t.isThai ? 'ค้นหาตอนนี้' : 'Search now';

    final fasterStartTitle = t.isGerman
        ? 'Schneller starten'
        : t.isThai
            ? 'เริ่มต้นได้เร็วขึ้น'
            : 'Get started faster';

    final fasterStartSub = t.isGerman
        ? 'Öffne Suche, like interessante Profile und schau regelmäßig in deine Likes — so entstehen schneller Matches und Chats.'
        : t.isThai
            ? 'เปิดการค้นหา กดไลก์โปรไฟล์ที่น่าสนใจ และเช็กไลก์ของคุณเป็นประจำ — แบบนี้จะเกิดแมตช์และแชตได้เร็วขึ้น'
            : 'Open search, like interesting profiles, and check your likes regularly — that leads to matches and chats faster.';

    final goldActiveText = t.isGerman
        ? 'Gold aktiv'
        : t.isThai
            ? 'โกลด์ใช้งานอยู่'
            : 'Gold active';

    final toGoldText =
        t.isGerman ? 'Zu Gold' : t.isThai ? 'สู่โกลด์' : 'To Gold';

    final upgradeText =
        t.isGerman ? 'Upgrade' : t.isThai ? 'อัปเกรด' : 'Upgrade';

    final profilePreviewText = t.isGerman
        ? 'Mein Profil ansehen'
        : t.isThai
            ? 'ดูโปรไฟล์ของฉัน'
            : 'View my profile';

    final profilePreviewSub = t.isGerman
        ? 'So sehen andere dein Profil'
        : t.isThai
            ? 'ดูว่าคนอื่นเห็นโปรไฟล์คุณอย่างไร'
            : 'See how others view you';

    return RefreshIndicator(
      onRefresh: () async {
        await _refreshHomeData();
        _restartRealtimeIfNeeded();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.pink.withValues(alpha: 0.18),
                  Colors.orange.withValues(alpha: 0.12),
                  Colors.purple.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.pink.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: AppLogo(size: 96),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  t.appName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  helloText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  heroSub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PlanChip(
            label: _loadingPlan ? '...' : _planLabel,
            subtitle: _loadingPlan
                ? (t.isGerman
                    ? 'Lade Status…'
                    : t.isThai
                        ? 'กำลังโหลดสถานะ…'
                        : 'Loading status…')
                : _planRuleText(t),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  likesTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadingLikes ? likesLoadingText : likesLoadedText,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _index = 4);
                          unawaited(_markLikesAsSeen());
                        },
              icon: const Icon(Icons.favorite_rounded),
                        label: Text(likesOpenText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
              icon: Icons.person_search_rounded,
                  title: profilePreviewText,
                  subtitle: profilePreviewSub,
                  onTap: () {
                    setState(() => _index = 6);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
              icon: Icons.search_rounded,
                  title: t.search,
                  subtitle: newProfilesText,
                  onTap: () {
                    setState(() => _index = 1);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
              icon: Icons.handshake_rounded,
                  title: t.matches,
                  subtitle: openMatchesText,
                  onTap: () {
                    setState(() => _index = 3);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
              icon: Icons.chat_bubble_rounded,
                  title: t.chats,
                  subtitle: readMessagesText,
                  onTap: () async {
                    setState(() => _index = 5);
                    await _loadChatUnreadCount();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _QuickActionCard(
              icon: isPremium
                ? Icons.workspace_premium_rounded
                : Icons.auto_awesome_rounded,
            title:
                isGold ? goldActiveText : (isPremium ? toGoldText : upgradeText),
            subtitle: upgradeSubtitle,
            onTap: isGold ? null : _openUpgrade,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  previewTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  previewSub,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.66),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                if (_loadingPreviewProfiles)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_previewProfiles.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      noPreviewText,
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _previewProfiles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final p = _previewProfiles[i];
                        final name =
                            (p['display_name'] ?? 'Profil').toString().trim();
                        final avatar =
                            (p['avatar_url'] ?? '').toString().trim();
                        final city = (p['city'] ?? '').toString().trim();
                        final origin =
                            (p['origin_country'] ?? '').toString().trim();
                        final isOnline = p['is_online'] == true;

                        return _PreviewProfileCard(
                          name: name.isEmpty
                              ? (t.isGerman
                                  ? 'Profil'
                                  : t.isThai
                                      ? 'โปรไฟล์'
                                      : 'Profile')
                              : name,
                          avatarUrl: avatar.isEmpty ? null : avatar,
                          subtitle: [city, origin]
                              .where((e) => e.trim().isNotEmpty)
                              .join(' • '),
                          isOnline: isOnline,
                          emptySubtitleText: t.isGerman
                              ? 'Neues Profil'
                              : t.isThai
                                  ? 'โปรไฟล์ใหม่'
                                  : 'New profile',
                          onTap: () {
                            setState(() => _index = 1);
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _index = 1);
                    },
              icon: const Icon(Icons.explore_rounded),
                    label: Text(discoverNowText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.pink.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.pink.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              children: [
                Text(
                  fasterStartTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  fasterStartSub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.68),
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final isGold = _planLabel == 'GOLD';
    final isPremium = _planLabel == 'PREMIUM';

    final upgradeText =
        t.isGerman ? 'Upgrade' : t.isThai ? 'อัปเกรด' : 'Upgrade';

    final goldText = t.isThai ? 'โกลด์' : 'Gold';

    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? t.home : t.appName),
        actions: [
          Stack(
            children: [
              IconButton(
                tooltip: t.likes,
                onPressed: () {
                  setState(() => _index = 4);
                  unawaited(_markLikesAsSeen());
                },
              icon: const Icon(Icons.favorite_rounded),
              ),
              if (!_loadingLikes && _likesBadgeCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: _badgeContainer(
                    count: _likesBadgeCount,
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                  ),
                ),
            ],
          ),
          Stack(
            children: [
              IconButton(
                tooltip: t.chats,
                onPressed: () async {
                  setState(() => _index = 5);
                  await _loadChatUnreadCount();
                },
              icon: const Icon(Icons.chat_bubble_rounded),
              ),
              if (!_loadingChatUnread && _chatUnreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: _badgeContainer(
                    count: _chatUnreadCount,
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: t.more,
            onPressed: _openMoreMenu,
              icon: const Icon(Icons.more_vert_rounded),
          ),
          IconButton(
            tooltip: t.reloadStatus,
            onPressed: () async {
              await _refreshHomeData();
              _restartRealtimeIfNeeded();
            },
              icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: t.logout,
            onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
          ),
        ],
        bottom: _index == 0
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PlanChip(
                          label: _loadingPlan ? '...' : _planLabel,
                          subtitle: _loadingPlan
                              ? (t.isGerman
                                  ? 'Lade Status…'
                                  : t.isThai
                                      ? 'กำลังโหลดสถานะ…'
                                      : 'Loading status…')
                              : _planRuleText(t),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (!isGold)
                        ElevatedButton.icon(
                          onPressed: _openUpgrade,
              icon: Icon(
                            isPremium
                                ? Icons.workspace_premium_rounded
                                : Icons.auto_awesome_rounded,
                            size: 18,
                          ),
                          label: Text(isPremium ? goldText : upgradeText),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      body: _buildCurrentScreen(),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFFF4D8D).withValues(alpha: 0.12),
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? const Color(0xFFFF4D8D) : Colors.black87,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: 25,
                color: selected ? const Color(0xFFFF4D8D) : Colors.black87,
              );
            }),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _bottomNavSelectedIndex(),
            height: 72,
            elevation: 10,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            onDestinationSelected: _onBottomNavSelected,
            destinations: [
              NavigationDestination(
              icon: Tooltip(
                  message: 'Dashboard',
                  child: const Icon(Icons.local_fire_department_rounded),
                ),
                selectedIcon: Tooltip(
                  message: 'Dashboard',
                  child: const Icon(Icons.local_fire_department_rounded),
                ),
                label: 'Dashboard',
              ),
              NavigationDestination(
              icon: Tooltip(
                  message: 'Swipes',
                  child: const Icon(Icons.style_rounded),
                ),
                selectedIcon: Tooltip(
                  message: 'Swipes',
                  child: const Icon(Icons.style_rounded),
                ),
                label: 'Swipes',
              ),
              NavigationDestination(
              icon: Tooltip(
                  message: t.isGerman
                      ? 'Mitglieder'
                      : t.isThai
                          ? 'สมาชิก'
                          : 'Members',
                  child: const Icon(Icons.groups_rounded),
                ),
                selectedIcon: Tooltip(
                  message: t.isGerman
                      ? 'Mitglieder'
                      : t.isThai
                          ? 'สมาชิก'
                          : 'Members',
                  child: const Icon(Icons.groups_rounded),
                ),
                label: t.isGerman
                    ? 'Mitglieder'
                    : t.isThai
                        ? 'สมาชิก'
                        : 'Members',
              ),
              NavigationDestination(
              icon: Tooltip(
                  message: t.likes,
                  child: _buildBottomLikesIcon(),
                ),
                selectedIcon: Tooltip(
                  message: t.likes,
                  child: _buildBottomLikesIcon(),
                ),
                label: t.likes,
              ),
              NavigationDestination(
              icon: Tooltip(
                  message: t.chats,
                  child: _buildBottomChatsIcon(),
                ),
                selectedIcon: Tooltip(
                  message: t.chats,
                  child: _buildBottomChatsIcon(),
                ),
                label: t.chats,
              ),
              NavigationDestination(
              icon: Tooltip(
                  message: t.profile,
                  child: const Icon(Icons.person_rounded),
                ),
                selectedIcon: Tooltip(
                  message: t.profile,
                  child: const Icon(Icons.person_rounded),
                ),
                label: t.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  final String label;
  final String subtitle;

  const _PlanChip({
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isGold = label == 'GOLD';
    final isPremium = label == 'PREMIUM';

    final chipColor = isGold
        ? Colors.amber
        : isPremium
            ? Colors.pink
            : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: chipColor.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: chipColor.withValues(alpha: 0.25)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isGold
                    ? Colors.amber.shade800
                    : isPremium
                        ? Colors.pink.shade700
                        : Colors.black.withValues(alpha: 0.75),
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.72),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: disabled ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: Colors.pink),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewProfileCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String subtitle;
  final bool isOnline;
  final String emptySubtitleText;
  final VoidCallback onTap;

  const _PreviewProfileCard({
    required this.name,
    required this.avatarUrl,
    required this.subtitle,
    required this.isOnline,
    required this.emptySubtitleText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    height: 110,
                    color: Colors.grey.shade300,
                    child: avatarUrl != null && avatarUrl!.trim().isNotEmpty
                        ? Image.network(
                            avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              size: 34,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 34,
                          ),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle.isEmpty ? emptySubtitleText : subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.64),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}