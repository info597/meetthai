// lib/widgets/plan_status_chip.dart
import 'package:flutter/material.dart';

enum PlanStatus {
  free,
  premiumPaid,
  premiumPromo,
  premiumUnknown,
  gold,
}

class PlanStatusChip extends StatelessWidget {
  final PlanStatus status;
  final VoidCallback? onTap;

  const PlanStatusChip({
    super.key,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final IconData icon;
    late final Color bg;
    late final Color fg;

    switch (status) {
      case PlanStatus.gold:
        text = 'GOLD';
        icon = Icons.auto_awesome;
        bg = const Color(0xFFFFF3CD);
        fg = const Color(0xFF8A6D1D);
        break;
      case PlanStatus.premiumPaid:
        text = 'PREMIUM';
        icon = Icons.star;
        bg = const Color(0xFFE8F0FF);
        fg = const Color(0xFF1E3A8A);
        break;
      case PlanStatus.premiumPromo:
        text = 'PREMIUM';
        icon = Icons.card_giftcard;
        bg = const Color(0xFFE7F7ED);
        fg = const Color(0xFF0F6B2E);
        break;
      case PlanStatus.premiumUnknown:
        text = 'PREMIUM';
        icon = Icons.star_border;
        bg = const Color(0xFFEFF0F2);
        fg = const Color(0xFF374151);
        break;
      case PlanStatus.free:
      default:
        text = 'FREE';
        icon = Icons.lock_open;
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF374151);
        break;
    }

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: fg, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: chip,
    );
  }
}