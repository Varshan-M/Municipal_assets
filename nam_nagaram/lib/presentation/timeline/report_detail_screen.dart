import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/repositories/complaint_repository.dart';
import '../widgets/status_badge.dart';

class ReportDetailScreen extends ConsumerWidget {
  final String complaintId;

  const ReportDetailScreen({super.key, required this.complaintId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintAsync = ref.watch(complaintRepositoryProvider).getComplaint(complaintId);
    final timelineAsync = ref.watch(complaintTimelineProvider(complaintId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Report Detail')),
      body: StreamBuilder(
        stream: complaintAsync,
        builder: (context, complaintSnapshot) {
          if (complaintSnapshot.hasError) return Center(child: Text('Error: ${complaintSnapshot.error}'));
          if (!complaintSnapshot.hasData) return const Center(child: CircularProgressIndicator());

          final complaint = complaintSnapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ID: ${complaint.id.substring(0, 8).toUpperCase()}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    StatusBadge(status: complaint.status),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${complaint.assetType} - ${complaint.issueType}',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(complaint.address, style: theme.textTheme.bodyMedium)),
                  ],
                ),
                if (complaint.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Description', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(complaint.description, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 24),
                
                // Images Section
                Text('Evidence', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Before', style: theme.textTheme.labelMedium),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildImage(complaint.imageUrl),
                          ),
                        ],
                      ),
                    ),
                    if (complaint.resolutionImageUrl != null) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('After', style: theme.textTheme.labelMedium),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                                child: _buildImage(complaint.resolutionImageUrl!),
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // AI Section (Backend driven, placeholder for future)
                if (complaint.aiCategory != null) ...[
                  Text('AI Analysis', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Detected: ${complaint.aiCategory}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (complaint.aiSeverity != null) Text('Severity: ${complaint.aiSeverity}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Timeline
                Text('Status Timeline', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                timelineAsync.when(
                  data: (timelineEvents) {
                    if (timelineEvents.isEmpty) {
                      return const Text('No timeline events yet.');
                    }
                    
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: timelineEvents.length,
                      itemBuilder: (context, index) {
                        final event = timelineEvents[index];
                        final isFirst = index == 0;
                        final isLast = index == timelineEvents.length - 1;
                        
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isFirst ? theme.colorScheme.primary : Colors.grey[400],
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: isFirst ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: Colors.grey[300],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.status,
                                        style: TextStyle(
                                          fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                                          color: isFirst ? theme.colorScheme.onSurface : Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        event.message,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('dd MMM yyyy, hh:mm a').format(event.timestamp),
                                        style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Text('Error loading timeline: $err'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      final base64String = imageUrl.split(',').last;
      return Image.memory(
        base64Decode(base64String),
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: const Icon(Icons.error)),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
        errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.error)),
      );
    }
  }
}
