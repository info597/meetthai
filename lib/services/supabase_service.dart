import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._internal();
  static final SupabaseService instance = SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  /// ------------------------------------------------------------
  /// AUTH
  /// ------------------------------------------------------------

  User? get currentUser => client.auth.currentUser;

  String? get currentUserId => currentUser?.id;

  bool get isLoggedIn => currentUser != null;

  /// ------------------------------------------------------------
  /// PROFILE
  /// ------------------------------------------------------------

  /// Profil sicher anlegen, falls noch keines existiert.
  /// Gibt true zurück, wenn der Vorgang erfolgreich war.
  Future<bool> ensureProfileExists() async {
    final user = currentUser;
    if (user == null) {
      debugPrint('[SupabaseService] ensureProfileExists: kein User eingeloggt');
      return false;
    }

    try {
      final existing = await client
          .from('profiles')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null) {
        debugPrint('[SupabaseService] Profil existiert bereits für ${user.id}');
        return true;
      }

      debugPrint('[SupabaseService] Erstelle neues Profil für ${user.id}');

      await client.from('profiles').upsert(
        {
          'user_id': user.id,
          'is_premium': false,
          'is_gold': false,
          'plan_code': 'free',
          'billing_period': null,
          'subscription_source': null,
          'subscription_status': 'expired',
          'subscription_expires_at': null,
          'revenuecat_app_user_id': user.id,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );

      debugPrint('[SupabaseService] Profil erfolgreich angelegt für ${user.id}');
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] ensureProfileExists Fehler: $e');
      return false;
    }
  }

  /// Eigenes Profil laden
  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = currentUser;
    if (user == null) {
      debugPrint('[SupabaseService] getMyProfile: kein User eingeloggt');
      return null;
    }

    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      return data;
    } catch (e) {
      debugPrint('[SupabaseService] getMyProfile Fehler: $e');
      return null;
    }
  }

  /// Fremdes Profil laden
  Future<Map<String, dynamic>?> getProfileByUserId(String userId) async {
    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return data;
    } catch (e) {
      debugPrint('[SupabaseService] getProfileByUserId Fehler: $e');
      return null;
    }
  }

  /// ------------------------------------------------------------
  /// SUBSCRIPTION
  /// ------------------------------------------------------------

  Future<bool> isPremium() async {
    final profile = await getMyProfile();
    if (profile == null) return false;

    final isPremiumFlag = profile['is_premium'] == true;
    final isGoldFlag = profile['is_gold'] == true;

    final planCode =
        (profile['plan_code'] ?? 'free').toString().trim().toLowerCase();
    final billingPeriod =
        (profile['billing_period'] ?? '').toString().trim().toLowerCase();
    final subscriptionSource =
        (profile['subscription_source'] ?? '').toString().trim().toLowerCase();
    final promoGranted = profile['promo_granted'] == true;
    final promoType =
        (profile['promo_type'] ?? '').toString().trim().toLowerCase();

    final hasPromoPremium =
        planCode == 'premium' &&
        (billingPeriod == 'promo' ||
            subscriptionSource == 'promo' ||
            promoGranted ||
            promoType.isNotEmpty);

    return isGoldFlag || isPremiumFlag || planCode == 'gold' || planCode == 'premium' || hasPromoPremium;
  }

  Future<bool> isGold() async {
    final profile = await getMyProfile();
    if (profile == null) return false;

    final isGoldFlag = profile['is_gold'] == true;
    final planCode =
        (profile['plan_code'] ?? 'free').toString().trim().toLowerCase();

    return isGoldFlag || planCode == 'gold';
  }

  Future<String> getPlan() async {
    final profile = await getMyProfile();
    if (profile == null) return 'free';

    final planCode =
        (profile['plan_code'] ?? 'free').toString().trim().toLowerCase();

    if (planCode == 'gold') return 'gold';
    if (planCode == 'premium') return 'premium';
    return 'free';
  }

  Future<String?> getBillingPeriod() async {
    final profile = await getMyProfile();
    if (profile == null) return null;

    final value = profile['billing_period']?.toString().trim().toLowerCase();
    if (value == null || value.isEmpty) return null;

    return value;
  }

  /// ------------------------------------------------------------
  /// DEBUG
  /// ------------------------------------------------------------

  Future<void> debugPrintProfile() async {
    final profile = await getMyProfile();

    debugPrint('----- PROFILE DEBUG -----');
    debugPrint('User: $currentUserId');
    debugPrint('LoggedIn: $isLoggedIn');
    debugPrint('Profile: $profile');
    debugPrint('-------------------------');
  }
}