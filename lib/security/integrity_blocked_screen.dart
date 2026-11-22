import 'package:flutter/material.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

/// Full-screen lock shown when the APK fails integrity verification.
/// No routes, no providers, no services — the app is intentionally dead.
class IntegrityBlockedScreen extends StatelessWidget {
  const IntegrityBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.customFFF5F8FD,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.customFFC53030.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      size: 56,
                      color: AppColors.customFFC53030,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'App blocked',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.customFF253858,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This application is not authorized to run.\n'
                    'Please install the official app only.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.customFF5F6F82,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'All services are disabled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.customFF93A1B3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
