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
import '../../presentation/home/analytics_screen.dart';
import '../../presentation/splash/splash_screen.dart';
import '../../presentation/home/main_layout_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final currentUserAsync = ref.watch(currentUserProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth-check',
        builder: (context, state) {
          // Auth flow decision logic
          return authState.when(
            data: (user) {
              if (user == null) {
                return const SignInScreen();
              }
              
              // We have a firebase user, check if we have full user data
              return currentUserAsync.when(
                data: (userData) {
                  if (userData == null) {
                    // If user document is missing in Firestore, sign them out and redirect to login
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref.read(authRepositoryProvider).signOut();
                      context.go('/login');
                    });
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  
                  // Redirect to home if logged in
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    context.go('/home');
                  });
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      // Stateful shell route for persistent bottom navigation bar
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainLayoutScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-reports',
                builder: (context, state) => const MyReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const AnalyticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/report',
        builder: (context, state) => const ReportIssueScreen(),
      ),
      GoRoute(
        path: '/report-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReportDetailScreen(complaintId: id);
        },
      ),
    ],
  );
});
