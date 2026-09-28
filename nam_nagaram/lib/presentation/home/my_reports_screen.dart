import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/complaint_model.dart';
import '../../data/repositories/complaint_repository.dart';
import '../widgets/status_badge.dart';
import '../widgets/priority_badge.dart';
import '../../data/repositories/auth_repository.dart';

class MyReportsScreen extends ConsumerStatefulWidget {
  const MyReportsScreen({super.key});

  @override
  ConsumerState<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends ConsumerState<MyReportsScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final isMaintenance = userAsync.value?.role == 'maintenance';
    final complaintsAsync = isMaintenance 
        ? ref.watch(teamComplaintsProvider) 
        : ref.watch(userComplaintsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/home');
        }
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: Text(isMaintenance ? 'My Tasks' : 'My Reports'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Active', 'Resolved'].map((filter) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (selected) {
                        setState(() => _filter = filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
      body: complaintsAsync.when(
        data: (complaints) {
          List<ComplaintModel> filtered = complaints;
          if (_filter == 'Active') {
            filtered = complaints.where((c) => c.status != 'Resolved' && c.status != 'Rejected').toList();
          } else if (_filter == 'Resolved') {
            filtered = complaints.where((c) => c.status == 'Resolved').toList();
          }

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isMaintenance ? Icons.assignment_turned_in_outlined : Icons.assignment_outlined, size: 64, color: Theme.of(context).disabledColor),
                  const SizedBox(height: 16),
                  Text(isMaintenance ? 'No tasks assigned' : 'No reports found', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final complaint = filtered[index];
              return Card(
                child: InkWell(
                  onTap: () => context.push('/report-detail/${complaint.id}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ID: ${complaint.id.substring(0, 8).toUpperCase()}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                            ),
                            Text(
                              DateFormat('dd MMM yyyy').format(complaint.createdAt),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${complaint.assetType} - ${complaint.issueType}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                complaint.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                StatusBadge(status: complaint.status),
                                const SizedBox(width: 8),
                                PriorityBadge(priority: complaint.aiPriorityLevel),
                              ],
                            ),
                            if (complaint.citizenPriority == 'Critical' || complaint.citizenPriority == 'Urgent')
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: complaint.citizenPriority == 'Critical' ? Colors.red : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    complaint.citizenPriority,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: complaint.citizenPriority == 'Critical' ? Colors.red : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      ),
    );
  }
}
