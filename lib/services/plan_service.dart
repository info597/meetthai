enum PlanStatus {
  free,
  premiumMonthly,
  premiumSemiannual,
  premiumYearly,
  goldMonthly,
  goldSemiannual,
  goldYearly,
}

class PlanService {
  static String labelFor(PlanStatus status) {
    switch (status) {
      case PlanStatus.free:
        return 'FREE';
      case PlanStatus.premiumMonthly:
      case PlanStatus.premiumSemiannual:
      case PlanStatus.premiumYearly:
        return 'PREMIUM';
      case PlanStatus.goldMonthly:
      case PlanStatus.goldSemiannual:
      case PlanStatus.goldYearly:
        return 'GOLD';
    }
  }

  static String periodLabelFor(PlanStatus status) {
    switch (status) {
      case PlanStatus.free:
        return '';
      case PlanStatus.premiumMonthly:
      case PlanStatus.goldMonthly:
        return 'Monatlich';
      case PlanStatus.premiumSemiannual:
      case PlanStatus.goldSemiannual:
        return '6 Monate';
      case PlanStatus.premiumYearly:
      case PlanStatus.goldYearly:
        return 'Jährlich';
    }
  }

  static String fullLabelFor(PlanStatus status) {
    final label = labelFor(status);
    final period = periodLabelFor(status);

    if (period.isEmpty) return label;
    return '$label • $period';
  }

  static bool isPremium(PlanStatus status) {
    switch (status) {
      case PlanStatus.premiumMonthly:
      case PlanStatus.premiumSemiannual:
      case PlanStatus.premiumYearly:
      case PlanStatus.goldMonthly:
      case PlanStatus.goldSemiannual:
      case PlanStatus.goldYearly:
        return true;
      case PlanStatus.free:
        return false;
    }
  }

  static bool isGold(PlanStatus status) {
    switch (status) {
      case PlanStatus.goldMonthly:
      case PlanStatus.goldSemiannual:
      case PlanStatus.goldYearly:
        return true;
      case PlanStatus.free:
      case PlanStatus.premiumMonthly:
      case PlanStatus.premiumSemiannual:
      case PlanStatus.premiumYearly:
        return false;
    }
  }

  static String likesRuleTextFor(PlanStatus status) {
    switch (status) {
      case PlanStatus.free:
        return '10 Likes / Tag • 10 Likes sichtbar';
      case PlanStatus.premiumMonthly:
      case PlanStatus.premiumSemiannual:
      case PlanStatus.premiumYearly:
        return '25 Likes / Tag • 25 Likes sichtbar';
      case PlanStatus.goldMonthly:
      case PlanStatus.goldSemiannual:
      case PlanStatus.goldYearly:
        return 'Unbegrenzte Likes • Alle Likes sichtbar';
    }
  }

  static String benefitsTextFor(PlanStatus status) {
    switch (status) {
      case PlanStatus.free:
        return '10 Likes pro Tag senden und die ersten 10 Likes sehen.';
      case PlanStatus.premiumMonthly:
      case PlanStatus.premiumSemiannual:
      case PlanStatus.premiumYearly:
        return '25 Likes pro Tag senden und die ersten 25 Likes sehen.';
      case PlanStatus.goldMonthly:
      case PlanStatus.goldSemiannual:
      case PlanStatus.goldYearly:
        return 'Unbegrenzte Likes senden und alle Likes sehen.';
    }
  }
}