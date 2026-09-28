import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Show splash screen for 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      // Navigate to the auth checker route which will decide login vs home
      context.go('/auth-check');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Using errorBuilder to fallback to text if the image is missing, 
            // so the app doesn't crash if the user forgot to add it.
            Image.asset(
              'assets/images/logo.png',
              width: 250,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  'Nam Nagaram',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F3E70), // Deep blue
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
