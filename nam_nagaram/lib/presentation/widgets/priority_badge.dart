import 'package:flutter/material.dart';

class PriorityBadge extends StatelessWidget {
  final String? priority;

  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    if (priority == null) return const SizedBox.shrink();
    
    Color backgroundColor;
    Color textColor;

    switch (priority) {
      case 'Critical':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      case 'High':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case 'Medium':
        backgroundColor = Colors.yellow.shade100;
        textColor = Colors.yellow.shade900;
        break;
      case 'Low':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      default:
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            priority!,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
