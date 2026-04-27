import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n/app_strings.dart';
import 'user_profile_screen.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _supa = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _error;

  final List<Map<String, dynamic>> _items = [];
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredItems {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _items;

    return _items.where((item) {
      final name = (item['display_name'] ?? '').toString().toLowerCase();
      final city = (item['city'] ?? '').toString().toLowerCase();
      final origin = (item['origin_country'] ?? '').toString().toLowerCase();

      return name.contains(q) || city.contains(q) || origin.contains(q);
    }).toList();
  }

  String _titleText(AppStrings t) {
    final total = _items.length;
    if (t.isGerman) return 'Blockierte Nutzer ($total)';
    if (t.isThai) return 'ผู้ใช้ที่ถูกบล็อก ($total)';
    return 'Blocked users ($total)';
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
    );
  }

  Future<void> _load() async {
    final t = AppStrings.of(context);
    final me = _supa.auth.currentUser;
    if (me == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = t.loginRequired;
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
      final blockRows = await _supa
          .from('user_blocks')
          .select('blocked_user_id, created_at')
          .eq('blocker_user_id', me.id)
          .order('created_at', ascending: false);

      final blocks = (blockRows as List).cast<Map<String, dynamic>>();
      if (blocks.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
        return;
      }

      final blockedIds = blocks
          .map((e) => e['blocked_user_id']?.toString())
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toList();

      Map<String, Map<String, dynamic>> profileById = {};
      if (blockedIds.isNotEmpty) {
        try {
          final profileRows = await _supa
              .from('profiles')
              .select(
                'user_id, display_name, avatar_url, city, origin_country, is_online',
              )
              .inFilter('user_id', blockedIds);

          final list = (profileRows as List).cast<Map<String, dynamic>>();
          profileById = {
            for (final p in list) p['user_id'].toString(): p,
          };
        } catch (_) {}
      }

      for (final block in blocks) {
        final uid = block['blocked_user_id']?.toString();
        if (uid == null || uid.isEmpty) continue;

        final p = profileById[uid];

        _items.add({
          'user_id': uid,
          'display_name': p?['display_name']?.toString(),
          'avatar_url': p?['avatar_url']?.toString(),
          'city': p?['city']?.toString(),
          'origin_country': p?['origin_country']?.toString(),
          'is_online': p?['is_online'] == true,
          'blocked_at': block['created_at']?.toString(),
        });
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = t.isGerman
            ? 'Blockierte Nutzer konnten nicht geladen werden: $e'
            : t.isThai
                ? 'ไม่สามารถโหลดผู้ใช้ที่ถูกบล็อกได้: $e'
                : 'Blocked users could not be loaded: $e';
      });
    }
  }

  Future<void> _unblockItem(Map<String, dynamic> item) async {
    if (_busy) return;

    final t = AppStrings.of(context);
    final userId = (item['user_id'] ?? '').toString().trim();
    final rawName = (item['display_name'] ?? '').toString().trim();
    final name = rawName.isEmpty
        ? (t.isGerman
            ? 'dieses Profil'
            : t.isThai
                ? 'โปรไฟล์นี้'
                : 'this profile')
        : rawName;

    if (userId.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              t.isGerman
                  ? 'Entblocken?'
                  : t.isThai
                      ? 'เลิกบล็อก?'
                      : 'Unblock?',
            ),
            content: Text(
              t.isGerman
                  ? 'Möchtest du $name wirklich entblocken?'
                  : t.isThai
                      ? 'คุณต้องการเลิกบล็อก $name ใช่ไหม?'
                      : 'Do you really want to unblock $name?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  t.isGerman
                      ? 'Entblocken'
                      : t.isThai
                          ? 'เลิกบล็อก'
                          : 'Unblock',
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _busy = true;
    });

    try {
      await _supa.rpc(
        'unblock_user',
        params: {
          'p_blocked_user_id': userId,
        },
      );

      if (!mounted) return;

      setState(() {
        _items.removeWhere(
          (e) => (e['user_id'] ?? '').toString() == userId,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.isGerman
                ? '$name wurde entblockt.'
                : t.isThai
                    ? 'เลิกบล็อก $name แล้ว'
                    : '$name was unblocked.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.isGerman
                ? 'Entblocken fehlgeschlagen: $e'
                : t.isThai
                    ? 'เลิกบล็อกไม่สำเร็จ: $e'
                    : 'Unblock failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _openProfile(Map<String, dynamic> item) async {
    final userId = (item['user_id'] ?? '').toString().trim();
    if (userId.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  String _subtitle(Map<String, dynamic> item, AppStrings t) {
    final parts = <String>[];

    final city = (item['city'] ?? '').toString().trim();
    final origin = (item['origin_country'] ?? '').toString().trim();

    if (city.isNotEmpty) parts.add(city);
    if (origin.isNotEmpty) parts.add(origin);

    if (parts.isEmpty) {
      if (t.isGerman) return 'Blockiertes Profil';
      if (t.isThai) return 'โปรไฟล์ที่ถูกบล็อก';
      return 'Blocked profile';
    }
    return parts.join(' • ');
  }

  Widget _buildSearchField(AppStrings t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: TextField(
        controller: _searchController,
        enabled: !_busy,
        decoration: InputDecoration(
          hintText: t.isGerman
              ? 'Suchen nach Name, Stadt oder Herkunft'
              : t.isThai
                  ? 'ค้นหาจากชื่อ เมือง หรือถิ่นกำเนิด'
                  : 'Search by name, city, or origin',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: t.isGerman
                      ? 'Suche löschen'
                      : t.isThai
                          ? 'ล้างการค้นหา'
                          : 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultInfo(AppStrings t) {
    if (_items.isEmpty) return const SizedBox.shrink();

    final searching = _searchQuery.trim().isNotEmpty;
    final filteredCount = _filteredItems.length;
    final totalCount = _items.length;

    final text = searching
        ? (t.isGerman
            ? '$filteredCount von $totalCount blockierten Nutzern'
            : t.isThai
                ? '$filteredCount จาก $totalCount ผู้ใช้ที่ถูกบล็อก'
                : '$filteredCount of $totalCount blocked users')
        : (t.isGerman
            ? '$totalCount blockierte Nutzer'
            : t.isThai
                ? '$totalCount ผู้ใช้ที่ถูกบล็อก'
                : '$totalCount blocked users');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.black.withOpacity(0.62),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearchState(AppStrings t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 44),
            const SizedBox(height: 10),
            Text(
              t.isGerman
                  ? 'Keine blockierten Nutzer gefunden.'
                  : t.isThai
                      ? 'ไม่พบผู้ใช้ที่ถูกบล็อก'
                      : 'No blocked users found.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.isGerman
                  ? 'Versuche einen anderen Suchbegriff.'
                  : t.isThai
                      ? 'ลองใช้คำค้นหาอื่น'
                      : 'Try a different search term.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withOpacity(0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final filtered = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleText(t)),
        actions: [
          IconButton(
            tooltip: t.home,
            icon: const Icon(Icons.home_rounded),
            onPressed: _goHome,
          ),
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: t.refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          t.isGerman
                              ? 'Du hast aktuell keine Nutzer blockiert.'
                              : t.isThai
                                  ? 'ตอนนี้คุณยังไม่ได้บล็อกผู้ใช้คนใด'
                                  : 'You currently have no blocked users.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        if (_busy) const LinearProgressIndicator(),
                        _buildSearchField(t),
                        _buildSearchResultInfo(t),
                        Expanded(
                          child: filtered.isEmpty
                              ? _buildEmptySearchState(t)
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final item = filtered[i];
                                    final name = (item['display_name'] ?? '')
                                        .toString()
                                        .trim();
                                    final avatar = (item['avatar_url'] ?? '')
                                        .toString()
                                        .trim();

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage: avatar.isNotEmpty
                                            ? NetworkImage(avatar)
                                            : null,
                                        child: avatar.isEmpty
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                      title: Text(
                                        name.isEmpty
                                            ? (t.isGerman
                                                ? 'Profil'
                                                : t.isThai
                                                    ? 'โปรไฟล์'
                                                    : 'Profile')
                                            : name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        _subtitle(item, t),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Wrap(
                                        spacing: 4,
                                        children: [
                                          IconButton(
                                            tooltip: t.isGerman
                                                ? 'Profil ansehen'
                                                : t.isThai
                                                    ? 'ดูโปรไฟล์'
                                                    : 'View profile',
                                            onPressed: _busy
                                                ? null
                                                : () => _openProfile(item),
                                            icon: const Icon(
                                              Icons.visibility_rounded,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: t.isGerman
                                                ? 'Entblocken'
                                                : t.isThai
                                                    ? 'เลิกบล็อก'
                                                    : 'Unblock',
                                            onPressed: _busy
                                                ? null
                                                : () => _unblockItem(item),
                                            icon: const Icon(
                                              Icons.lock_open_rounded,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
    );
  }
}