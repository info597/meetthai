import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiscoveryProfile {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? city;
  final String? originCountry;
  final String? job;
  final bool isOnline;
  final bool isGold;
  final bool isPremium;
  final String? desiredPartner;
  final String? hobbies;
  final List<String> languages;

  const DiscoveryProfile({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.city,
    required this.originCountry,
    required this.job,
    required this.isOnline,
    required this.isGold,
    required this.isPremium,
    required this.desiredPartner,
    required this.hobbies,
    required this.languages,
  });

  factory DiscoveryProfile.fromRow(Map<String, dynamic> row) {
    final planCode = (row['plan_code'] ?? '').toString().trim().toLowerCase();
    final rawIsGold = row['is_gold'] == true;
    final rawIsPremium = row['is_premium'] == true;

    final normalizedIsGold = rawIsGold || planCode == 'gold';
    final normalizedIsPremium =
        normalizedIsGold || rawIsPremium || planCode == 'premium';

    final parsedLanguages = <String>[];
    final rawLanguages = row['languages'];

    if (rawLanguages is List) {
      for (final item in rawLanguages) {
        final value = item.toString().trim();
        if (value.isNotEmpty) {
          parsedLanguages.add(value);
        }
      }
    }

    String? hobbiesText;
    final rawHobbies = row['hobbies'];
    if (rawHobbies is List) {
      final values = rawHobbies
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      hobbiesText = values.isEmpty ? null : values.join(', ');
    } else {
      final text = rawHobbies?.toString().trim();
      hobbiesText = (text == null || text.isEmpty) ? null : text;
    }

    return DiscoveryProfile(
      userId: row['user_id'].toString(),
      displayName: (row['display_name'] ?? '').toString().trim(),
      avatarUrl: row['avatar_url']?.toString(),
      city: row['city']?.toString(),
      originCountry: row['origin_country']?.toString(),
      job: row['job']?.toString(),
      isOnline: row['is_online'] == true,
      isGold: normalizedIsGold,
      isPremium: normalizedIsPremium,
      desiredPartner: row['desired_partner']?.toString(),
      hobbies: hobbiesText,
      languages: parsedLanguages,
    );
  }
}

class DiscoveryService {
  static final SupabaseClient _supa = Supabase.instance.client;

  static String _requireUserId() {
    final user = _supa.auth.currentUser;
    if (user == null) {
      throw Exception('Nicht eingeloggt.');
    }
    return user.id;
  }

  static Future<void> pingOnline() async {
    final me = _supa.auth.currentUser;
    if (me == null) return;

    try {
      await _supa.from('profiles').update({
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('user_id', me.id);
    } catch (_) {}
  }

  static Future<Set<String>> _loadBlockedUserIds(String me) async {
    final blocked = <String>{};

    final rows = await _supa
        .from('user_blocks')
        .select('blocker_user_id, blocked_user_id')
        .or('blocker_user_id.eq.$me,blocked_user_id.eq.$me');

    for (final raw in (rows as List).cast<Map<String, dynamic>>()) {
      final blocker = raw['blocker_user_id']?.toString();
      final blockedUser = raw['blocked_user_id']?.toString();

      if (blocker == null || blockedUser == null) continue;

      if (blocker == me) {
        blocked.add(blockedUser);
      } else if (blockedUser == me) {
        blocked.add(blocker);
      }
    }

    return blocked;
  }

  static Future<Set<String>> _loadMatchedUserIds(String me) async {
    final matched = <String>{};

    final rows = await _supa
        .from('matches')
        .select('user_a, user_b')
        .or('user_a.eq.$me,user_b.eq.$me');

    for (final raw in (rows as List).cast<Map<String, dynamic>>()) {
      final a = raw['user_a']?.toString();
      final b = raw['user_b']?.toString();

      if (a == null || b == null) continue;

      matched.add(a == me ? b : a);
    }

    return matched;
  }

  static Future<Set<String>> _loadAlreadyLikedUserIds(String me) async {
    final liked = <String>{};

    final rows =
        await _supa.from('likes').select('to_user_id').eq('from_user_id', me);

    for (final raw in (rows as List).cast<Map<String, dynamic>>()) {
      final toUserId = raw['to_user_id']?.toString();
      if (toUserId != null && toUserId.isNotEmpty) {
        liked.add(toUserId);
      }
    }

    return liked;
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

  static Future<List<DiscoveryProfile>> loadDiscoveryProfiles({
    int limit = 30,
    bool excludeAlreadyLiked = true,
  }) async {
    final me = _requireUserId();

    debugPrint('DISCOVERY me=$me');

    final blockedIds = await _loadBlockedUserIds(me);
    final matchedIds = await _loadMatchedUserIds(me);
    final likedIds =
        excludeAlreadyLiked ? await _loadAlreadyLikedUserIds(me) : <String>{};
    final deletedIds = await _loadDeletedUserIds();

    debugPrint('DISCOVERY blockedIds=$blockedIds');
    debugPrint('DISCOVERY matchedIds=$matchedIds');
    debugPrint('DISCOVERY likedIds=$likedIds');
    debugPrint('DISCOVERY deletedIds=$deletedIds');

    final rows = await _supa
        .from('profiles')
        .select('''
          user_id,
          display_name,
          avatar_url,
          city,
          origin_country,
          job,
          is_online,
          is_gold,
          is_premium,
          plan_code,
          is_hidden,
          is_deleted,
          deleted_at,
          updated_at,
          desired_partner,
          hobbies,
          languages
        ''')
        .neq('user_id', me)
        .eq('is_hidden', false)
        .order('is_gold', ascending: false)
        .order('is_premium', ascending: false)
        .order('updated_at', ascending: false)
        .limit(limit * 4);

    debugPrint('DISCOVERY raw rows count=${(rows as List).length}');

    final out = <DiscoveryProfile>[];

    for (final raw in rows.cast<Map<String, dynamic>>()) {
      final userId = raw['user_id']?.toString();
      final displayName = raw['display_name']?.toString();
      final isDeleted = raw['is_deleted'] == true;
      final hasDeletedAt = raw['deleted_at'] != null;

      debugPrint('DISCOVERY raw profile userId=$userId displayName=$displayName');

      if (userId == null || userId.isEmpty) continue;
      if (isDeleted || hasDeletedAt) {
        debugPrint('DISCOVERY skip deleted flag $userId');
        continue;
      }
      if (deletedIds.contains(userId)) {
        debugPrint('DISCOVERY skip deleted set $userId');
        continue;
      }
      if (blockedIds.contains(userId)) {
        debugPrint('DISCOVERY skip blocked $userId');
        continue;
      }
      if (matchedIds.contains(userId)) {
        debugPrint('DISCOVERY skip matched $userId');
        continue;
      }
      if (likedIds.contains(userId)) {
        debugPrint('DISCOVERY skip liked $userId');
        continue;
      }

      out.add(DiscoveryProfile.fromRow(raw));
      debugPrint('DISCOVERY add profile $userId');

      if (out.length >= limit) break;
    }

    debugPrint('DISCOVERY final result count=${out.length}');
    return out;
  }
}