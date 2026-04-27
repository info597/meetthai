import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'subscription_state.dart';
import 'supabase_service.dart';

class SubscriptionService {
  SubscriptionService._internal();
  static final SubscriptionService instance = SubscriptionService._internal();

  static const String premiumEntitlementId = 'premium';
  static const String goldEntitlementId = 'gold';

  static const String promoTypeFemaleFreelancerFirst100 =
      'female_freelancer_first_100';

  static const String betaTesterCode = 'MEETTHAI-TESTER';
  static const String betaTesterPromoType = 'beta_tester';

  bool _initialized = false;
  bool _available = false;
  String? _configuredPublicKey;
  String? _currentAppUserId;

  bool get isAvailable => _available;

  Future<void> init({
    required String publicKey,
  }) async {
    if (_initialized) return;

    _configuredPublicKey = publicKey;

    if (kIsWeb) {
      _initialized = true;
      _available = false;
      debugPrint('[SubscriptionService] Web erkannt -> RevenueCat deaktiviert');
      return;
    }

    final cleanKey = publicKey.trim();

    if (cleanKey.isEmpty) {
      _initialized = true;
      _available = false;
      debugPrint('[SubscriptionService] Kein RevenueCat Public Key gesetzt');
      return;
    }

    if (cleanKey.startsWith('test_')) {
      _initialized = true;
      _available = false;
      debugPrint(
        '[SubscriptionService] RevenueCat Test-Key erkannt -> deaktiviert',
      );
      return;
    }

    try {
      await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(cleanKey));

      _initialized = true;
      _available = true;

      debugPrint('[SubscriptionService] RevenueCat konfiguriert');
    } catch (e) {
      _initialized = true;
      _available = false;
      debugPrint('[SubscriptionService] RevenueCat Fehler -> deaktiviert: $e');
    }
  }

  Future<void> onAuthChanged(String? userId) async {
    await _ensureInitialized();

    if (kIsWeb || !_available) {
      await SubscriptionState.instance.refreshFromSupabase();
      return;
    }

    try {
      if (userId == null || userId.isEmpty) {
        _currentAppUserId = null;

        try {
          final appUserId = await Purchases.appUserID;
          final isAnonymous = appUserId.startsWith(r'$RCAnonymousID:');

          if (!isAnonymous) {
            await Purchases.logOut();
          }
        } catch (_) {}

        await SubscriptionState.instance.logOutRevenueCat();
        return;
      }

      if (_currentAppUserId != userId) {
        final result = await Purchases.logIn(userId);
        debugPrint(
          '[SubscriptionService] RevenueCat logIn: created=${result.created}',
        );
        _currentAppUserId = userId;
      }

      await refreshAndSync();
    } catch (e) {
      debugPrint('[SubscriptionService] onAuthChanged Fehler: $e');
      await SubscriptionState.instance.refreshFromSupabase();
    }
  }

  Future<Offerings?> getOfferings() async {
    await _ensureInitialized();

    if (kIsWeb || !_available) return null;

    return await Purchases.getOfferings();
  }

  Future<void> purchasePackage(Package package) async {
    await _ensureInitialized();

    if (kIsWeb) {
      throw Exception('Käufe im Web nicht möglich');
    }

    if (!_available) {
      throw Exception('RevenueCat nicht konfiguriert');
    }

    await Purchases.purchasePackage(package);

    await Future.delayed(const Duration(milliseconds: 1200));
    await refreshAndSync();
  }

  Future<void> restorePurchases() async {
    await _ensureInitialized();

    if (kIsWeb) {
      throw Exception('Käufe im Web nicht möglich');
    }

    if (!_available) {
      throw Exception('RevenueCat nicht konfiguriert');
    }

    await Purchases.restorePurchases();

    await Future.delayed(const Duration(milliseconds: 1200));
    await refreshAndSync();
  }

  Future<bool> activateBetaTesterCode(String enteredCode) async {
    await _ensureInitialized();

    final code = enteredCode.trim().toUpperCase();
    final expectedCode = betaTesterCode.trim().toUpperCase();

    if (code != expectedCode) {
      return false;
    }

    final supa = Supabase.instance.client;
    final user = supa.auth.currentUser;

    if (user == null) {
      throw Exception('Du musst eingeloggt sein, um den Beta-Zugang zu nutzen.');
    }

    await SupabaseService.instance.ensureProfileExists();

    await supa
        .from('profiles')
        .update({
          'is_premium': true,
          'is_gold': true,
          'plan_code': 'gold',
          'billing_period': null,
          'subscription_source': 'beta',
          'subscription_status': 'active',
          'subscription_expires_at': null,
          'revenuecat_app_user_id': user.id,
          'promo_granted': true,
          'promo_type': betaTesterPromoType,
          'promo_awarded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', user.id);

    await SubscriptionState.instance.refreshFromSupabase();
    await SubscriptionState.instance.refresh();

    debugPrint('[SubscriptionService] Beta Tester freigeschaltet');

    return true;
  }

  Future<void> refreshAndSync() async {
    await _ensureInitialized();

    final supa = Supabase.instance.client;
    final user = supa.auth.currentUser;

    if (user == null) {
      await SubscriptionState.instance.logOutRevenueCat();
      return;
    }

    if (kIsWeb || !_available) {
      await SubscriptionState.instance.refreshFromSupabase();
      return;
    }

    try {
      await SupabaseService.instance.ensureProfileExists();

      final existingProfile = await _loadExistingProfile(user.id);

      CustomerInfo info = await Purchases.getCustomerInfo();
      await Future.delayed(const Duration(milliseconds: 250));
      info = await Purchases.getCustomerInfo();

      final active = info.entitlements.active;

      debugPrint('[RC] active entitlement keys: ${active.keys.toList()}');
      debugPrint('[RC] full entitlements: $active');

      final goldInfo = active[goldEntitlementId];
      final premiumInfo = active[premiumEntitlementId];

      debugPrint('[RC] premium active: ${premiumInfo?.isActive}');
      debugPrint('[RC] premium product: ${premiumInfo?.productIdentifier}');
      debugPrint('[RC] gold active: ${goldInfo?.isActive}');
      debugPrint('[RC] gold product: ${goldInfo?.productIdentifier}');

      final hasGold = goldInfo?.isActive == true;
      final hasPremium = hasGold || (premiumInfo?.isActive == true);

      String planCode = 'free';
      String? billingPeriod;
      DateTime? expiresAt;

      if (hasGold) {
        planCode = 'gold';
        billingPeriod = _periodFromProductId(goldInfo?.productIdentifier);
        expiresAt = _parseDate(goldInfo?.expirationDate);
      } else if (premiumInfo?.isActive == true) {
        planCode = 'premium';
        billingPeriod = _periodFromProductId(premiumInfo?.productIdentifier);
        expiresAt = _parseDate(premiumInfo?.expirationDate);
      }

      debugPrint('[SYNC] user=${user.id}');
      debugPrint('[SYNC] rcPlan=$planCode premium=$hasPremium gold=$hasGold');
      debugPrint('[SYNC] billingPeriod=$billingPeriod');
      debugPrint('[SYNC] expiresAt=${expiresAt?.toIso8601String()}');
      debugPrint('[SYNC] existingProfile=$existingProfile');

      if (hasPremium || hasGold) {
        await _syncRevenueCatPlan(
          supa: supa,
          userId: user.id,
          hasPremium: hasPremium,
          hasGold: hasGold,
          planCode: planCode,
          billingPeriod: billingPeriod,
          expiresAt: expiresAt,
        );

        await SubscriptionState.instance.refreshFromSupabase();
        await SubscriptionState.instance.refresh();

        debugPrint(
          '[SubscriptionService] SYNC ERFOLGREICH (RevenueCat aktiv)',
        );
        return;
      }

      final keepPromo = _shouldKeepPromo(existingProfile);

      if (keepPromo) {
        debugPrint(
          '[SubscriptionService] Promo/Beta aktiv -> kein Downgrade auf free',
        );

        await SubscriptionState.instance.refreshFromSupabase();
        debugPrint(
          '[SubscriptionService] SYNC ERFOLGREICH (Promo/Beta beibehalten)',
        );
        return;
      }

      await _syncFreePlan(
        supa: supa,
        userId: user.id,
      );

      await SubscriptionState.instance.refreshFromSupabase();
      await SubscriptionState.instance.refresh();

      debugPrint(
        '[SubscriptionService] SYNC ERFOLGREICH (auf free gesetzt)',
      );
    } catch (e) {
      debugPrint('[SubscriptionService] refreshAndSync Fehler: $e');
      await SubscriptionState.instance.refreshFromSupabase();
    }
  }

  Future<Map<String, dynamic>?> _loadExistingProfile(String userId) async {
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('''
            user_id,
            is_premium,
            is_gold,
            plan_code,
            billing_period,
            subscription_source,
            subscription_status,
            subscription_expires_at,
            promo_granted,
            promo_type,
            promo_awarded_at
          ''')
          .eq('user_id', userId)
          .maybeSingle();

      return row;
    } catch (e) {
      debugPrint('[SubscriptionService] _loadExistingProfile Fehler: $e');
      return null;
    }
  }

  bool _shouldKeepPromo(Map<String, dynamic>? profile) {
    if (profile == null) return false;

    final promoGranted = profile['promo_granted'] == true;
    final promoType = (profile['promo_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final subscriptionSource = (profile['subscription_source'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final subscriptionStatus = (profile['subscription_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final billingPeriod = (profile['billing_period'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final isPremium = profile['is_premium'] == true;
    final isGold = profile['is_gold'] == true;
    final planCode = (profile['plan_code'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final isBetaTester =
        promoType == betaTesterPromoType ||
        subscriptionSource == 'beta' ||
        billingPeriod == 'beta';

    if (isBetaTester &&
        isPremium &&
        isGold &&
        planCode == 'gold' &&
        (subscriptionStatus.isEmpty || subscriptionStatus == 'active')) {
      return true;
    }

    final hasKnownPromoType =
        promoType == promoTypeFemaleFreelancerFirst100;

    final hasPromoMarkers =
        promoGranted ||
        hasKnownPromoType ||
        subscriptionSource == 'promo' ||
        billingPeriod == 'promo';

    final looksLikePromoPremium =
        !isGold &&
        planCode == 'premium' &&
        isPremium &&
        hasPromoMarkers;

    final promoStatusAllowed =
        subscriptionStatus.isEmpty ||
        subscriptionStatus == 'active' ||
        subscriptionStatus == 'promo' ||
        subscriptionStatus == 'granted';

    return looksLikePromoPremium && promoStatusAllowed;
  }

  Future<void> _syncRevenueCatPlan({
    required SupabaseClient supa,
    required String userId,
    required bool hasPremium,
    required bool hasGold,
    required String planCode,
    required String? billingPeriod,
    required DateTime? expiresAt,
  }) async {
    await supa.rpc(
      'sync_my_subscription_status',
      params: {
        'p_is_premium': hasPremium,
        'p_is_gold': hasGold,
        'p_plan_code': planCode,
        'p_billing_period': billingPeriod,
        'p_subscription_source': 'revenuecat',
        'p_subscription_status': 'active',
        'p_subscription_expires_at': expiresAt?.toIso8601String(),
        'p_revenuecat_app_user_id': userId,
      },
    );
  }

  Future<void> _syncFreePlan({
    required SupabaseClient supa,
    required String userId,
  }) async {
    await supa.rpc(
      'sync_my_subscription_status',
      params: {
        'p_is_premium': false,
        'p_is_gold': false,
        'p_plan_code': 'free',
        'p_billing_period': null,
        'p_subscription_source': null,
        'p_subscription_status': 'expired',
        'p_subscription_expires_at': null,
        'p_revenuecat_app_user_id': userId,
      },
    );
  }

  DateTime? _parseDate(String? d) {
    if (d == null || d.trim().isEmpty) return null;
    try {
      return DateTime.parse(d);
    } catch (_) {
      return null;
    }
  }

  String? _periodFromProductId(String? productId) {
    final p = (productId ?? '').trim().toLowerCase();

    if (p.isEmpty) return null;
    if (p.contains('semi')) return 'semiannual';
    if (p.contains('year')) return 'yearly';
    if (p.contains('month')) return 'monthly';

    return null;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await init(publicKey: _configuredPublicKey ?? '');
  }
}