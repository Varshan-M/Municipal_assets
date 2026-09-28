import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/auth_repository.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

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
          title: const Text('Notifications'),
        ),
        body: userAsync.when(
          data: (user) {
            if (user == null) {
              return const Center(child: Text('Not logged in'));
            }
            return StreamBuilder<QuerySnapshot>(
              stream: user.role == 'maintenance'
                  ? FirebaseFirestore.instance
                      .collection('notifications')
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('notifications')
                      .where('userId', isEqualTo: user.id)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.where((doc) {
                  if (user.role == 'maintenance') {
                    final data = doc.data() as Map<String, dynamic>;
                    return data.containsKey('teamId') && data['teamId'] != null;
                  }
                  return true;
                }).toList();
                
                // Sort in memory to avoid needing a composite index in Firestore
                final now = DateTime.now();
                docs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  // Use static DateTime.now() for pending writes (null timestamp) so they confidently appear at the top
                  final timeA = (dataA['createdAt'] as Timestamp?)?.toDate() ?? now;
                  final timeB = (dataB['createdAt'] as Timestamp?)?.toDate() ?? now;
                  return timeB.compareTo(timeA); // Descending
                });

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No notifications yet.'),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final timestamp = (data['createdAt'] as Timestamp?)?.toDate();
                    final complaintId = data['complaintId'] as String?;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.amber,
                          child: Icon(Icons.star, color: Colors.white),
                        ),
                        title: Text(data['title'] ?? 'Notification', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(data['body'] ?? ''),
                            const SizedBox(height: 8),
                            if (timestamp != null)
                              Text(
                                DateFormat('MMM dd, hh:mm a').format(timestamp),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                              ),
                          ],
                        ),
                        onTap: () {
                          if (complaintId != null) {
                            context.push('/report/$complaintId');
                          }
                        },
                      ),
                    );
                  },
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
