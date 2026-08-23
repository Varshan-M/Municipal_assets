import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This is a mocked UI for notifications.
    // In a real app, this would stream from Firestore 'notifications' collection
    // based on Firebase Cloud Messaging.
    
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(
        child: Text('No notifications yet.'),
      ),
    );
  }


}
