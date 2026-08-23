import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/complaint_repository.dart';
import '../widgets/status_badge.dart';
import '../../core/theme/app_colors.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: userAsync.when(
          data: (user) => Text('Hi, ${user?.firstName ?? ''} 👋'),
          loading: () => const Text('Hi 👋'),
          error: (_, __) => const Text('Hi 👋'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // refresh providers if needed
            // ignore: unused_result
            ref.refresh(userComplaintsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
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
                                onTap: () => context.push('/my-reports'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildSummaryCard(
                                context,
                                title: 'Resolved',
                                count: resolved.toString(),
                                color: AppColors.success,
                                onTap: () => context.push('/my-reports'),
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Text('Error loading summary: $err'),
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
                      onPressed: () => context.push('/my-reports'),
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
                                StatusBadge(status: recent.status),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/report-detail/${recent.id}'),
                          ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => const SizedBox(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          switch(index) {
            case 0: break;
            case 1: context.push('/my-reports'); break;
            case 2: context.push('/notifications'); break;
            case 3: context.push('/profile'); break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
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
