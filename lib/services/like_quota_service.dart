import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LikeQuota {
  final String planCode;
  final int? dailyLikeLimit;
  final int usedLikesToday;
  final int? remainingLikesToday;
  final bool unlimited;

  const LikeQuota({
    required this.planCode,
    required this.dailyLikeLimit,
    required this.usedLikesToday,
    required this.remainingLikesToday,
    required this.unlimited,
  });

  factory LikeQuota.fromMap(Map<String, dynamic> map) {
    final normalizedPlanCode =
        (map['plan_code'] ?? 'free').toString().trim().toLowerCase();

    final dailyLikeLimit = _toIntOrNull(map['daily_like_limit']);
    final usedLikesToday = _toIntOrNull(map['used_likes_today']) ?? 0;
    final remainingLikesTodayRaw = _toIntOrNull(map['remaining_likes_today']);

    final normalizedUnlimited =
        map['unlimited'] == true || normalizedPlanCode == 'gold';

    int? normalizedRemaining;
    if (normalizedUnlimited) {
      normalizedRemaining = null;
    } else if (remainingLikesTodayRaw != null) {
      normalizedRemaining = remainingLikesTodayRaw < 0
          ? 0
          : remainingLikesTodayRaw;
    } else if (dailyLikeLimit != null) {
      final computed = dailyLikeLimit - usedLikesToday;
      normalizedRemaining = computed < 0 ? 0 : computed;
    } else {
      normalizedRemaining = 0;
    }

    return LikeQuota(
      planCode: normalizedPlanCode,
      dailyLikeLimit: normalizedUnlimited ? null : dailyLikeLimit,
      usedLikesToday: usedLikesToday < 0 ? 0 : usedLikesToday,
      remainingLikesToday: normalizedRemaining,
      unlimited: normalizedUnlimited,
    );
  }

  static int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  bool get hasLikesRemaining {
    if (unlimited) return true;
    return (remainingLikesToday ?? 0) > 0;
  }
}

class LikeQuotaService {
  LikeQuotaService._();

  static final SupabaseClient _supa = Supabase.instance.client;
  static const Duration _timeout = Duration(seconds: 8);

  static const LikeQuota _fallbackQuota = LikeQuota(
    planCode: 'free',
    dailyLikeLimit: 10,
    usedLikesToday: 0,
    remainingLikesToday: 10,
    unlimited: false,
  );

  static Future<LikeQuota> getMyQuota() async {
    final user = _supa.auth.currentUser;

    if (user == null) {
      debugPrint('[LikeQuotaService] no user -> fallback quota');
      return _fallbackQuota;
    }

    try {
      debugPrint('[LikeQuotaService] get_my_like_quota start user=${user.id}');

      final res = await _supa
          .rpc('get_my_like_quota')
          .timeout(_timeout);

      debugPrint('[LikeQuotaService] get_my_like_quota raw result: $res');

      if (res is List && res.isNotEmpty) {
        final first = res.first;
        if (first is Map) {
          final quota = LikeQuota.fromMap(Map<String, dynamic>.from(first));
          debugPrint(
            '[LikeQuotaService] parsed quota from list: '
            'plan=${quota.planCode}, used=${quota.usedLikesToday}, '
            'remaining=${quota.remainingLikesToday}, unlimited=${quota.unlimited}',
          );
          return quota;
        }
      }

      if (res is Map) {
        final quota = LikeQuota.fromMap(Map<String, dynamic>.from(res));
        debugPrint(
          '[LikeQuotaService] parsed quota from map: '
          'plan=${quota.planCode}, used=${quota.usedLikesToday}, '
          'remaining=${quota.remainingLikesToday}, unlimited=${quota.unlimited}',
        );
        return quota;
      }

      debugPrint(
        '[LikeQuotaService] unexpected response type -> fallback quota',
      );
      return _fallbackQuota;
    } on TimeoutException catch (e) {
      debugPrint('[LikeQuotaService] timeout: $e');
      return _fallbackQuota;
    } catch (e) {
      debugPrint('[LikeQuotaService] error: $e');
      return _fallbackQuota;
    }
  }
}