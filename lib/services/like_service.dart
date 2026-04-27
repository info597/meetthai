import 'package:supabase_flutter/supabase_flutter.dart';

class LikeResult {
  final bool matched;
  final String? conversationId;

  const LikeResult({
    required this.matched,
    required this.conversationId,
  });

  factory LikeResult.fromMap(Map<String, dynamic> map) {
    final matchedValue = map['matched'];
    final conversationIdRaw = map['conversation_id']?.toString().trim();

    return LikeResult(
      matched: matchedValue == true,
      conversationId:
          conversationIdRaw == null || conversationIdRaw.isEmpty
              ? null
              : conversationIdRaw,
    );
  }
}

class LikeService {
  static final SupabaseClient _supa = Supabase.instance.client;

  static const String _freeLikeLimitReached = 'FREE_LIKE_LIMIT_REACHED:10';
  static const String _premiumLikeLimitReached =
      'PREMIUM_LIKE_LIMIT_REACHED:25';
  static const String _freeSuperLikeLimitReached =
      'FREE_SUPER_LIKE_LIMIT_REACHED:1';
  static const String _premiumSuperLikeLimitReached =
      'PREMIUM_SUPER_LIKE_LIMIT_REACHED:5';
  static const String _blocked = 'BLOCKED';
  static const String _cannotLikeSelf = 'CANNOT_LIKE_SELF';
  static const String _notAuthenticated = 'NOT_AUTHENTICATED';
  static const String _invalidTargetUser = 'INVALID_TARGET_USER';
  static const String _userDeleted = 'USER_DELETED';

  static const List<String> _knownErrorMarkers = [
    _freeLikeLimitReached,
    _premiumLikeLimitReached,
    _freeSuperLikeLimitReached,
    _premiumSuperLikeLimitReached,
    _blocked,
    _cannotLikeSelf,
    _notAuthenticated,
    _invalidTargetUser,
    _userDeleted,
  ];

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

  static Future<LikeResult> likeUser({
    required String targetUserId,
    bool superLike = false,
  }) async {
    final normalizedTargetUserId = targetUserId.trim();
    if (normalizedTargetUserId.isEmpty) {
      throw Exception(_invalidTargetUser);
    }

    final deletedUserIds = await _loadDeletedUserIds();
    if (deletedUserIds.contains(normalizedTargetUserId)) {
      throw Exception(_userDeleted);
    }

    try {
      final res = await _supa.rpc(
        'like_user',
        params: {
          'p_target_user_id': normalizedTargetUserId,
          'p_is_super_like': superLike,
        },
      );

      return _parseLikeResult(res);
    } on PostgrestException catch (e) {
      throw Exception(_normalizeLikeError(e));
    } catch (e) {
      final normalized = _extractKnownErrorMarker(e.toString());
      if (normalized != null) {
        throw Exception(normalized);
      }

      rethrow;
    }
  }

  static LikeResult _parseLikeResult(dynamic res) {
    if (res == null) {
      return const LikeResult(
        matched: false,
        conversationId: null,
      );
    }

    if (res is List && res.isNotEmpty) {
      final first = res.first;

      if (first is Map<String, dynamic>) {
        return LikeResult.fromMap(first);
      }

      if (first is Map) {
        return LikeResult.fromMap(Map<String, dynamic>.from(first));
      }
    }

    if (res is Map<String, dynamic>) {
      return LikeResult.fromMap(res);
    }

    if (res is Map) {
      return LikeResult.fromMap(Map<String, dynamic>.from(res));
    }

    return const LikeResult(
      matched: false,
      conversationId: null,
    );
  }

  static String _normalizeLikeError(PostgrestException e) {
    final parts = <String>[
      if (e.message.isNotEmpty) e.message,
      if (e.details != null) e.details.toString(),
      if (e.hint != null) e.hint.toString(),
      if (e.code != null) e.code.toString(),
    ];

    final raw = parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' | ');

    final known = _extractKnownErrorMarker(raw);
    if (known != null) return known;

    return raw.isNotEmpty ? raw : e.toString();
  }

  static String? _extractKnownErrorMarker(String raw) {
    for (final marker in _knownErrorMarkers) {
      if (raw.contains(marker)) {
        return marker;
      }
    }
    return null;
  }
}