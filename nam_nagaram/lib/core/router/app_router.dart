import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../presentation/auth/sign_in_screen.dart';
import '../../presentation/auth/sign_up_screen.dart';
import '../../presentation/auth/otp_verification_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/home/my_reports_screen.dart';
import '../../presentation/report/report_issue_screen.dart';
import '../../presentation/timeline/report_detail_screen.dart';
import '../../presentation/profile/profile_screen.dart';
import '../../presentation/profile/notifications_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final currentUserAsync = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          // Auth flow decision logic
          return authState.when(
            data: (user) {
              if (user == null) {
                return const SignInScreen();
              }
              
              // We have a firebase user, check if we have full user data and if phone is verified
              return currentUserAsync.when(
                data: (userData) {
                  if (userData == null) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  
                  // OTP bypassed
                  // if (!userData.phoneVerified) {
                  //   return OtpVerificationScreen(phoneNumber: userData.phoneNumber);
                  // }
                  
                  return const HomeScreen();
                },
                loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
                error: (e, st) => Scaffold(body: Center(child: Text('Error loading user data: $e'))),
              );
            },
            loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
            error: (e, st) => Scaffold(body: Center(child: Text('Auth error: $e'))),
          );
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpVerificationScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/report',
        builder: (context, state) => const ReportIssueScreen(),
      ),
      GoRoute(
        path: '/my-reports',
        builder: (context, state) => const MyReportsScreen(),
      ),
      GoRoute(
        path: '/report-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReportDetailScreen(complaintId: id);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
