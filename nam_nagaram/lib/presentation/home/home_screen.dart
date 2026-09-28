import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/complaint_repository.dart';
import '../widgets/status_badge.dart';
import '../widgets/priority_badge.dart';
import '../../core/theme/app_colors.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final profileImages = ref.watch(profileImageProvider);
    
    final user = userAsync.value;
    final profileImage = user != null ? profileImages[user.id] : null;
    
    final isMaintenance = user?.role == 'maintenance';

    return Scaffold(
      appBar: AppBar(
        title: userAsync.when(
          data: (user) => Text('Hi, ${user?.firstName ?? ''} 👋'),
          loading: () => const Text('Hi 👋'),
          error: (_, __) => const Text('Hi 👋'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () => context.go('/profile'),
              borderRadius: BorderRadius.circular(20),
              child: (profileImage != null || user?.profilePictureBase64 != null)
                ? CircleAvatar(
                    radius: 16,
                    backgroundImage: profileImage != null 
                        ? FileImage(profileImage) 
                        : MemoryImage(base64Decode(user!.profilePictureBase64!)) as ImageProvider,
                  )
                : const Icon(Icons.account_circle, size: 32),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (isMaintenance) {
              ref.invalidate(teamComplaintsProvider);
            } else {
              ref.invalidate(userComplaintsProvider);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: isMaintenance ? _buildTeamDashboard(context, ref) : _buildCitizenDashboard(context, ref),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamDashboard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final complaintsAsync = ref.watch(teamComplaintsProvider);
    final teamDetailsAsync = ref.watch(teamDetailsProvider);
    final teamMembersAsync = ref.watch(teamMembersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Manage your team\'s assigned tasks.',
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 24),

        // Team Details Section
        teamDetailsAsync.when(
          data: (team) {
            if (team == null) return const SizedBox.shrink();
            final isOnline = team['isOnline'] ?? false;
            final skills = (team['skills'] as List<dynamic>?)?.cast<String>() ?? [];
            
            return Card(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2))),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          team['name'] ?? 'Unknown Team',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOnline ? AppColors.success.withValues(alpha: 0.1) : Colors.grey.shade200,
                            border: Border.all(color: isOnline ? AppColors.success : Colors.grey),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOnline ? AppColors.success : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(isOnline ? 'Online' : 'Offline', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOnline ? AppColors.success : Colors.grey.shade700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (skills.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: skills.map((s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 10)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: Colors.white,
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 24),
        Text('Crew Roster', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        
        // Team Members Section
        teamMembersAsync.when(
          data: (members) {
            if (members.isEmpty) {
              return const Text('No other members found in your team.');
            }
            return SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final member = members[index];
                  return Column(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        child: Text(
                          member.firstName.isNotEmpty ? member.firstName[0].toUpperCase() : '?',
                          style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member.firstName,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Error loading crew members.'),
        ),

        const SizedBox(height: 24),
        Text('Task Summary', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        
        complaintsAsync.when(
          data: (complaints) {
            final active = complaints.where((c) => c.status == 'Team Assigned' || c.status == 'Work In Progress').length;
            final resolved = complaints.where((c) => c.status == 'Resolved').length;
            
            return Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    title: 'Pending',
                    count: active.toString(),
                    color: AppColors.warning,
                    onTap: () => context.go('/my-reports'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    title: 'Completed',
                    count: resolved.toString(),
                    color: AppColors.success,
                    onTap: () => context.go('/my-reports'),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => const Text('Error loading tasks'),
        ),
        
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Assignments', style: theme.textTheme.titleLarge),
            TextButton(
              onPressed: () => context.go('/my-reports'),
              child: const Text('View All'),
            ),
          ],
        ),
        
        complaintsAsync.when(
          data: (complaints) {
            if (complaints.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Text('Your team has no tasks right now.'),
                ),
              );
            }
            
            // Show up to 3 recent tasks
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: complaints.length > 3 ? 3 : complaints.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final recent = complaints[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      '${recent.assetType} - ${recent.issueType}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(recent.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            StatusBadge(status: recent.status),
                            const SizedBox(width: 8),
                            if (recent.rating != null && recent.rating! > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${recent.rating}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              PriorityBadge(priority: recent.aiPriorityLevel),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/report-detail/${recent.id}'),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: Text('Error loading recent tasks.')),
          ),
        ),
      ],
    );
  }

  Widget _buildCitizenDashboard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Help keep your city safe and well maintained.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 24),
                // Report Issue CTA Card
                Card(
                  color: theme.colorScheme.primary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    onTap: () => context.push('/report'),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Report an Issue',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Found a problem in your area? Let us know.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 48,
                            color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'My Reports Summary',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                
                // Summary Cards using provider
                Consumer(
                  builder: (context, ref, child) {
                    final complaintsAsync = ref.watch(userComplaintsProvider);
                    return complaintsAsync.when(
                      data: (complaints) {
                        final active = complaints.where((c) => c.status != 'Resolved' && c.status != 'Rejected').length;
                        final resolved = complaints.where((c) => c.status == 'Resolved').length;
                        
                        return Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                context,
                                title: 'Active',
                                count: active.toString(),
                                color: AppColors.warning,
                                onTap: () => context.go('/my-reports'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildSummaryCard(
                                context,
                                title: 'Resolved',
                                count: resolved.toString(),
                                color: AppColors.success,
                                onTap: () => context.go('/my-reports'),
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) {
                        // Fallback to 0 if there's an index error or other issue
                        return Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(context, title: 'Active', count: '0', color: AppColors.warning, onTap: () => context.go('/my-reports')),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildSummaryCard(context, title: 'Resolved', count: '0', color: AppColors.success, onTap: () => context.go('/my-reports')),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: theme.textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: () => context.go('/my-reports'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                
                // Recent activity
                Consumer(
                  builder: (context, ref, child) {
                    final complaintsAsync = ref.watch(userComplaintsProvider);
                    return complaintsAsync.when(
                      data: (complaints) {
                        if (complaints.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(
                              child: Text('You have not reported any issues yet.'),
                            ),
                          );
                        }
                        
                        final recent = complaints.first;
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              '${recent.assetType} - ${recent.issueType}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(recent.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    StatusBadge(status: recent.status),
                                    if (recent.rating != null && recent.rating! > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${recent.rating}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/report-detail/${recent.id}'),
                          ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: Text('You have not reported any issues yet.')),
                      ),
                    );
                  },
                ),
              ],
            );
  }

  Widget _buildSummaryCard(BuildContext context, {required String title, required String count, required Color color, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                count,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
