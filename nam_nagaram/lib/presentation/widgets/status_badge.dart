import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'resolved':
        return AppColors.success;
      case 'under review':
      case 'team assigned':
      case 'work in progress':
        return AppColors.warning;
      case 'rejected':
      case 'duplicate':
        return AppColors.error;
      case 'submitted':
      case 'verified':
      case 'ai analysed':
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
