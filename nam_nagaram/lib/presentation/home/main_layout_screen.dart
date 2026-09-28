import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../data/repositories/auth_repository.dart';
import '../../core/services/location_service.dart';

class MainLayoutScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainLayoutScreen({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends ConsumerState<MainLayoutScreen> with WidgetsBindingObserver {
  bool _isTrackingStarted = false;
  bool _isFCMSubscribed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = ref.read(currentUserProvider).value;
    final locationService = ref.read(locationServiceProvider);
    
    if (user != null && user.role == 'maintenance' && user.teamId != null) {
      if (state == AppLifecycleState.resumed) {
        // App is back in foreground, start tracking and mark Online
        if (!_isTrackingStarted) {
          _isTrackingStarted = true;
          locationService.startTracking(user.teamId!);
        }
      } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
        // App went to background or was closed, stop tracking and mark Offline
        _isTrackingStarted = false;
        locationService.stopTracking(user.teamId!);
      }
    }
  }

  void _onTap(BuildContext context, int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    
    // Ensure tracking starts immediately if the user is already loaded
    if (userAsync.value != null) {
      if (!_isFCMSubscribed) {
        _isFCMSubscribed = true;
        FirebaseMessaging.instance.subscribeToTopic('user_${userAsync.value!.id}');
        if (userAsync.value!.role == 'maintenance' && userAsync.value!.teamId != null) {
          FirebaseMessaging.instance.subscribeToTopic('team_${userAsync.value!.teamId}');
        }
      }

      if (userAsync.value?.role == 'maintenance' && userAsync.value?.teamId != null && !_isTrackingStarted) {
        _isTrackingStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(locationServiceProvider).startTracking(userAsync.value!.teamId!);
        });
      }
    }
    
    // Listen for changes in the user auth state (like logging in/out)
    ref.listen(currentUserProvider, (previous, next) {
      final user = next.value;
      final locationService = ref.read(locationServiceProvider);
      
      if (user != null) {
        // Everyone subscribes to their own user ID topic to receive personal notifications
        FirebaseMessaging.instance.subscribeToTopic('user_${user.id}');
        
        if (user.role == 'maintenance' && user.teamId != null) {
          if (!_isTrackingStarted) {
            _isTrackingStarted = true;
            locationService.startTracking(user.teamId!);
            // Subscribe to push notifications for this team
            FirebaseMessaging.instance.subscribeToTopic('team_${user.teamId}');
          }
        }
      } else {
        _isTrackingStarted = false;
        locationService.stopTracking(previous?.value?.teamId);
        if (previous?.value != null) {
          // Unsubscribe from user topic
          FirebaseMessaging.instance.unsubscribeFromTopic('user_${previous!.value!.id}');
          if (previous.value!.teamId != null) {
            // Unsubscribe from old team
            FirebaseMessaging.instance.unsubscribeFromTopic('team_${previous.value!.teamId}');
          }
        }
      }
    });
    
    // Team complaints listener removed to prevent duplicate in-app notifications.

    final isMaintenance = userAsync.value?.role == 'maintenance';
    return PopScope(
      canPop: widget.navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // If we didn't pop (because we're not on Home), navigate to Home
          _onTap(context, 0);
        }
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: (index) => _onTap(context, index),
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: isMaintenance ? const Icon(Icons.assignment) : const Icon(Icons.list_alt), 
              label: isMaintenance ? 'Tasks' : 'Reports'
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
            const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
