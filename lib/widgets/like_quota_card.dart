import 'package:flutter/material.dart';

import '../services/like_quota_service.dart';

class LikeQuotaCard extends StatelessWidget {
  final LikeQuota quota;
  final VoidCallback? onUpgradeTap;

  const LikeQuotaCard({
    super.key,
    required this.quota,
    this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGold = quota.unlimited || quota.planCode == 'gold';
    final isPremium = quota.planCode == 'premium';

    final accent = isGold
        ? Colors.amber
        : isPremium
            ? Colors.pink
            : Colors.blueGrey;

    final title = isGold
        ? 'Unbegrenzte Likes heute'
        : 'Noch ${quota.remainingLikesToday ?? 0} von ${quota.dailyLikeLimit ?? 0} Likes heute';

    final subtitle = isGold
        ? 'Du kannst heute unbegrenzt liken.'
        : 'Bereits genutzt: ${quota.usedLikesToday}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.favorite_rounded,
            color: isGold
                ? Colors.amber.shade800
                : isPremium
                    ? Colors.pink.shade700
                    : Colors.blueGrey.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.68),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!isGold && onUpgradeTap != null)
            TextButton(
              onPressed: onUpgradeTap,
              child: Text(isPremium ? 'Gold' : 'Upgrade'),
            ),
        ],
      ),
    );
  }
}