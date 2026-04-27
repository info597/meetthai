import 'package:flutter/material.dart';

class OnlineBadge extends StatelessWidget {
  final bool isOnline;
  const OnlineBadge({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isOnline ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(blurRadius: 2, offset: Offset(0,1))],
      ),
    );
  }
}
