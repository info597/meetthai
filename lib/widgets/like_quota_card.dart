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

    final ctaText = isPremium ? 'Gold holen' : 'Mehr Likes';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.16),
            accent.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: isGold
                  ? Colors.amber.shade800
                  : isPremium
                      ? Colors.pink.shade700
                      : Colors.blueGrey.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!isGold && onUpgradeTap != null)
            TextButton(
              onPressed: onUpgradeTap,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                ctaText,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
