import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Note: The user needs to run `flutterfire configure` to generate `firebase_options.dart`.
  // If the file is missing, the app will fail to compile. I'm importing it assuming the user
  // will perform this step as described in the verification plan.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed (did you run flutterfire configure?): $e');
  }

  runApp(
    const ProviderScope(
      child: CivicCareApp(),
    ),
  );
}

class CivicCareApp extends ConsumerWidget {
  const CivicCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'CivicCare',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
