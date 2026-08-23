import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/auth_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No user data found.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                    style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.onPrimary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${user.firstName} ${user.lastName}',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  user.email,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  user.phoneNumber,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 32),
                
                _buildListTile(
                  context, 
                  icon: Icons.person_outline, 
                  title: 'Edit Profile', 
                  onTap: () {} // placeholder
                ),
                _buildListTile(
                  context, 
                  icon: Icons.notifications_outlined, 
                  title: 'Notification Settings', 
                  onTap: () {}
                ),
                _buildListTile(
                  context, 
                  icon: Icons.lock_outline, 
                  title: 'Privacy', 
                  onTap: () {}
                ),
                _buildListTile(
                  context, 
                  icon: Icons.help_outline, 
                  title: 'Help & Support', 
                  onTap: () {}
                ),
                _buildListTile(
                  context, 
                  icon: Icons.description_outlined, 
                  title: 'Terms & Conditions', 
                  onTap: () {}
                ),
                const SizedBox(height: 24),
                
                ListTile(
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text('Logout', style: TextStyle(color: theme.colorScheme.error)),
                  onTap: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) {
                      context.go('/');
                    }
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
