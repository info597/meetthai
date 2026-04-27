// lib/services/access_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AccessService {
  static final SupabaseClient _supa = Supabase.instance.client;

  // ✅ Upload-Limit pro Profil
  static const int maxUploadPhotosPerProfile = 30;

  // ✅ Sichtbare Fotos je nach Plan
  static const int freeVisiblePhotos = 5;
  static const int premiumVisiblePhotos = 10;
  static const int goldVisiblePhotos = 999;

  // ✅ Fehlercodes
  static const String errNotLoggedIn = 'NOT_LOGGED_IN';
  static const String errUploadLimitExceeded = 'UPLOAD_LIMIT_EXCEEDED';

  // optionaler Cache
  static _Plan? _cachedPlan;

  static String _requireUserId() {
    final user = _supa.auth.currentUser;
    if (user == null) {
      throw Exception(errNotLoggedIn);
    }
    return user.id;
  }

  // ------------------------------------------------------------
  // Cache
  // ------------------------------------------------------------
  static void invalidateCache() {
    _cachedPlan = null;
  }

  // ------------------------------------------------------------
  // PLAN
  // ------------------------------------------------------------
  static Future<_Plan> getMyPlan() async {
    if (_cachedPlan != null) return _cachedPlan!;

    final me = _requireUserId();

    final row = await _supa
        .from('profiles')
        .select('is_premium, is_gold')
        .eq('user_id', me)
        .maybeSingle();

    final isGold = row?['is_gold'] == true;
    final isPremium = row?['is_premium'] == true;

    if (isGold) {
      _cachedPlan = _Plan.gold;
    } else if (isPremium) {
      _cachedPlan = _Plan.premium;
    } else {
      _cachedPlan = _Plan.free;
    }

    return _cachedPlan!;
  }

  static Future<bool> isGold() async => (await getMyPlan()) == _Plan.gold;
  static Future<bool> isPremium() async =>
      (await getMyPlan()) == _Plan.premium;

  static Future<int> getMaxVisiblePhotosForViewer() async {
    final plan = await getMyPlan();

    switch (plan) {
      case _Plan.gold:
        return goldVisiblePhotos;
      case _Plan.premium:
        return premiumVisiblePhotos;
      case _Plan.free:
        return freeVisiblePhotos;
    }
  }

  // ------------------------------------------------------------
  // UPLOAD LIMIT
  // ------------------------------------------------------------
  static Future<int> getMyUploadedPhotoCount() async {
    final me = _requireUserId();

    final rows = await _supa
        .from('profile_photos')
        .select('id')
        .eq('user_id', me);

    return (rows as List).length;
  }

  static Future<void> ensureCanUploadOneMore() async {
    final count = await getMyUploadedPhotoCount();
    if (count >= maxUploadPhotosPerProfile) {
      throw Exception(errUploadLimitExceeded);
    }
  }

  static Future<int> getRemainingUploadSlots() async {
    final count = await getMyUploadedPhotoCount();
    final left = maxUploadPhotosPerProfile - count;
    return left <= 0 ? 0 : left;
  }

  // ------------------------------------------------------------
  // DAILY QUOTA (vorläufiger Fallback)
  // ------------------------------------------------------------
  static Future<_QuotaResult> consumeDailyQuota({
    required String kind,
    int amount = 1,
  }) async {
    final plan = await getMyPlan();

    int limit;
    switch (kind) {
      case 'like':
        switch (plan) {
          case _Plan.gold:
            limit = 999999;
            break;
          case _Plan.premium:
            limit = 50;
            break;
          case _Plan.free:
            limit = 20;
            break;
        }
        break;
      default:
        limit = 999999;
    }

    // ✅ Vorläufig immer erlaubt, damit die App kompiliert/läuft.
    return _QuotaResult(
      allowed: true,
      remaining: limit,
      limit: limit,
      reason: null,
    );
  }
}

enum _Plan { free, premium, gold }

class _QuotaResult {
  final bool allowed;
  final int remaining;
  final int limit;
  final String? reason;

  _QuotaResult({
    required this.allowed,
    required this.remaining,
    required this.limit,
    required this.reason,
  });

  // ✅ für alten Code wie q.ok
  bool get ok => allowed;

  Map<String, dynamic> toMap() {
    return {
      'allowed': allowed,
      'remaining': remaining,
      'limit': limit,
      'reason': reason,
    };
  }
}