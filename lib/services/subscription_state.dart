import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'plan_service.dart';

class SubscriptionState extends ChangeNotifier {
  SubscriptionState._();
  static final SubscriptionState instance = SubscriptionState._();

  final SupabaseClient _supa = Supabase.instance.client;

  bool _loaded = false;
  bool _loading = false;
  bool _revenueCatReady = false;

  bool _isPremium = false;
  bool _isGold = false;
  bool _cancelAtPeriodEnd = false;

  String _planLabel = 'FREE';
  String _billingPeriod = '';
  String? _activeProductId;
  DateTime? _expiresAt;

  bool get loaded => _loaded;
  bool get loading => _loading;
  bool get revenueCatReady => _revenueCatReady;

  bool get isPremium => _isPremium || _isGold;
  bool get isGold => _isGold;
  bool get cancelAtPeriodEnd => _cancelAtPeriodEnd;

  String get planLabel => _planLabel;
  String get billingPeriod => _billingPeriod;
  String? get activeProductId => _activeProductId;
  DateTime? get expiresAt => _expiresAt;

  void setRevenueCatReady(bool value) {
    if (_revenueCatReady == value) return;
    _revenueCatReady = value;
    notifyListeners();
  }

  Future<void> refreshFromSupabase() async {
    final user = _supa.auth.currentUser;
    if (user == null) {
      final changed = _applyFreeState();
      if (!_loaded) _loaded = true;
      if (_loading) _loading = false;
      if (changed || !_loaded) {
        notifyListeners();
      }
      return;
    }

    final oldSnapshot = _stateSnapshot();

    _loading = true;
    notifyListeners();

    try {
      final row = await _supa
          .from('profiles')
          .select('''
            is_premium,
            is_gold,
            plan_code,
            billing_period,
            subscription_expires_at,
            subscription_source,
            subscription_status,
            cancel_at_period_end,
            promo_granted,
            promo_type
          ''')
          .eq('user_id', user.id)
          .maybeSingle();

      final isPremiumFlag = row?['is_premium'] == true;
      final isGoldFlag = row?['is_gold'] == true;

      final planCode =
          (row?['plan_code'] ?? 'free').toString().trim().toLowerCase();
      final billingPeriod =
          (row?['billing_period'] ?? '').toString().trim().toLowerCase();
      final subscriptionSource =
          (row?['subscription_source'] ?? '').toString().trim().toLowerCase();
      final subscriptionStatus =
          (row?['subscription_status'] ?? '').toString().trim().toLowerCase();
      final promoGranted = row?['promo_granted'] == true;
      final promoType =
          (row?['promo_type'] ?? '').toString().trim().toLowerCase();
      final expiresAtRaw = row?['subscription_expires_at']?.toString();
      final cancelAtPeriodEnd = row?['cancel_at_period_end'] == true;

      final parsedExpiresAt =
          expiresAtRaw != null && expiresAtRaw.isNotEmpty
              ? DateTime.tryParse(expiresAtRaw)
              : null;

      final hasPromoPremium =
          (planCode == 'premium' || isPremiumFlag) &&
          (billingPeriod == 'promo' ||
              subscriptionSource == 'promo' ||
              promoGranted ||
              promoType.isNotEmpty);

      final hasActivePremiumStatus =
          planCode == 'premium' &&
          (subscriptionStatus.isEmpty ||
              subscriptionStatus == 'active' ||
              subscriptionStatus == 'trialing' ||
              subscriptionStatus == 'promo');

      final hasActiveGoldStatus =
          planCode == 'gold' &&
          (subscriptionStatus.isEmpty ||
              subscriptionStatus == 'active' ||
              subscriptionStatus == 'trialing');

      final normalizedIsGold = isGoldFlag || hasActiveGoldStatus;

      final normalizedIsPremium =
          normalizedIsGold ||
          isPremiumFlag ||
          hasPromoPremium ||
          hasActivePremiumStatus;

      _isGold = normalizedIsGold;
      _isPremium = normalizedIsPremium;
      _cancelAtPeriodEnd = cancelAtPeriodEnd;
      _planLabel =
          normalizedIsGold
              ? 'GOLD'
              : normalizedIsPremium
                  ? 'PREMIUM'
                  : 'FREE';
      _billingPeriod =
          normalizedIsPremium && billingPeriod.isNotEmpty ? billingPeriod : '';
      _activeProductId = null;
      _expiresAt = parsedExpiresAt;
      _loaded = true;
    } catch (_) {
      _applyFreeState();
      _loaded = true;
    } finally {
      _loading = false;
      final changed = oldSnapshot != _stateSnapshot();
      if (changed) {
        notifyListeners();
      }
    }
  }

  Future<void> refreshFromRevenueCat() async {
    if (kIsWeb || !_revenueCatReady) {
      await refreshFromSupabase();
      return;
    }

    final oldSnapshot = _stateSnapshot();

    _loading = true;
    notifyListeners();

    try {
      final info = await Purchases.getCustomerInfo();
      _applyCustomerInfo(info);
      _loaded = true;
    } catch (_) {
      await refreshFromSupabase();
      return;
    } finally {
      _loading = false;
      final changed = oldSnapshot != _stateSnapshot();
      if (changed) {
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    if (kIsWeb || !_revenueCatReady) {
      await refreshFromSupabase();
      return;
    }

    try {
      await refreshFromRevenueCat();

      final hasRcPlan = _isGold || _isPremium;
      if (!hasRcPlan) {
        await refreshFromSupabase();
      }
    } catch (_) {
      await refreshFromSupabase();
    }
  }

  Future<void> configureForCurrentUser() async {
    final user = _supa.auth.currentUser;
    if (user == null) {
      final changed = _applyFreeState();
      if (changed) notifyListeners();
      return;
    }

    if (kIsWeb || !_revenueCatReady) {
      await refreshFromSupabase();
      return;
    }

    try {
      await Purchases.logIn(user.id);
    } catch (_) {}

    await refresh();
  }

  Future<void> logOutRevenueCat() async {
    if (!kIsWeb && _revenueCatReady) {
      try {
        final appUserId = await Purchases.appUserID;
        final isAnonymous = appUserId.startsWith(r'$RCAnonymousID:');

        if (!isAnonymous) {
          await Purchases.logOut();
        }
      } catch (_) {}
    }

    final changed = _applyFreeState();
    if (changed) notifyListeners();
  }

  void _applyCustomerInfo(CustomerInfo info) {
    final active = info.entitlements.active;

    final gold = active['gold'];
    if (gold != null && gold.isActive) {
      _isGold = true;
      _isPremium = true;
      _cancelAtPeriodEnd = false;
      _planLabel = 'GOLD';
      _activeProductId = gold.productIdentifier;
      _billingPeriod = _periodFromProductId(gold.productIdentifier);
      _expiresAt =
          gold.expirationDate != null
              ? DateTime.tryParse(gold.expirationDate!)
              : null;
      return;
    }

    final premium = active['premium'];
    if (premium != null && premium.isActive) {
      _isGold = false;
      _isPremium = true;
      _cancelAtPeriodEnd = false;
      _planLabel = 'PREMIUM';
      _activeProductId = premium.productIdentifier;
      _billingPeriod = _periodFromProductId(premium.productIdentifier);
      _expiresAt =
          premium.expirationDate != null
              ? DateTime.tryParse(premium.expirationDate!)
              : null;
      return;
    }

    _applyFreeState();
  }

  String _periodFromProductId(String? productId) {
    final p = (productId ?? '').trim().toLowerCase();

    if (p.contains('semiannual') ||
        p.contains('semi_annual') ||
        p.contains('halfyear') ||
        p.contains('half_year') ||
        p.contains('semi')) {
      return 'semiannual';
    }

    if (p.contains('yearly') || p.contains('annual') || p.contains('year')) {
      return 'yearly';
    }

    if (p.contains('monthly') || p.contains('month')) {
      return 'monthly';
    }

    return '';
  }

  bool _applyFreeState() {
    final before = _stateSnapshot();

    _isPremium = false;
    _isGold = false;
    _cancelAtPeriodEnd = false;
    _planLabel = 'FREE';
    _billingPeriod = '';
    _activeProductId = null;
    _expiresAt = null;
    _loaded = true;
    _loading = false;

    return before != _stateSnapshot();
  }

  String _stateSnapshot() {
    return [
      _loaded,
      _loading,
      _revenueCatReady,
      _isPremium,
      _isGold,
      _cancelAtPeriodEnd,
      _planLabel,
      _billingPeriod,
      _activeProductId ?? '',
      _expiresAt?.toIso8601String() ?? '',
    ].join('|');
  }

  String humanPlanText() {
    if (_isGold) {
      final status = _mapCurrentStatus();
      final period = PlanService.periodLabelFor(status);
      return period.isEmpty ? 'GOLD' : 'GOLD • $period';
    }

    if (_isPremium) {
      if (_billingPeriod == 'promo') {
        return 'PREMIUM • Gratis Promo';
      }

      final status = _mapCurrentStatus();
      final period = PlanService.periodLabelFor(status);
      return period.isEmpty ? 'PREMIUM' : 'PREMIUM • $period';
    }

    return 'Free';
  }

  PlanStatus _mapCurrentStatus() {
    if (_isGold) {
      switch (_billingPeriod) {
        case 'semiannual':
          return PlanStatus.goldSemiannual;
        case 'yearly':
          return PlanStatus.goldYearly;
        default:
          return PlanStatus.goldMonthly;
      }
    }

    if (_isPremium) {
      switch (_billingPeriod) {
        case 'semiannual':
          return PlanStatus.premiumSemiannual;
        case 'yearly':
          return PlanStatus.premiumYearly;
        case 'promo':
          return PlanStatus.premiumMonthly;
        default:
          return PlanStatus.premiumMonthly;
      }
    }

    return PlanStatus.free;
  }
}