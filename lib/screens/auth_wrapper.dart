import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'welcome_screen.dart';
import 'candidate_job_search_screen.dart';
import 'employer_dashboard_screen.dart';
import 'employer_verification_screen.dart';
import '../services/auth_service.dart';
import '../simple_candidate_dashboard.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Add app lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    // Verify auth state when wrapper initializes
    _verifyAuthState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh auth when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _verifyAuthState();
    }
  }

  Future<void> _verifyAuthState() async {
    await AuthService.verifyAuthState();
  }

  // Get fresh approval status from server (not cached)
  Future<Map<String, dynamic>> _getFreshApprovalStatus() async {
    return await AuthService.getApprovalStatus();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007BFF)),
              ),
            ),
          );
        }

        // If there's an error, show welcome screen
        if (snapshot.hasError) {
          debugPrint('Auth stream error: ${snapshot.error}');
          return const WelcomeScreen();
        }

        // Get the current user
        final user = snapshot.data;

        // If no user is signed in, show welcome screen
        if (user == null) {
          return const WelcomeScreen();
        }

        // User is signed in - check user type and registration status using AuthService
        return FutureBuilder<Map<String, dynamic>>(
          future: AuthService.checkAuthStatus(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF007BFF),
                    ),
                  ),
                ),
              );
            }

            // Handle errors in auth status check
            if (userSnapshot.hasError) {
              debugPrint('Auth status check error: ${userSnapshot.error}');
              return const WelcomeScreen();
            }

            final authData = userSnapshot.data ?? {};
            final userType = authData['userType'] as String?;
            final isComplete =
                authData['isRegistrationComplete'] as bool? ?? false;
            final isAuthenticated =
                authData['isAuthenticated'] as bool? ?? false;

            debugPrint('🔍 Auth Status Check Result:');
            debugPrint('  - userType: $userType');
            debugPrint('  - isComplete: $isComplete');
            debugPrint('  - isAuthenticated: $isAuthenticated');
            debugPrint('  - user.uid: ${user.uid}');
            debugPrint('  - user.isAnonymous: ${user.isAnonymous}');

            // If not properly authenticated, show welcome screen
            if (!isAuthenticated) {
              debugPrint('  - Not authenticated, showing welcome screen');
              return const WelcomeScreen();
            }

            if (isComplete) {
              if (userType == 'candidate') {
                debugPrint('  - Authenticated candidate, showing dashboard');
                return const SimpleCandidateDashboard();
              } else if (userType == 'employer') {
                debugPrint(
                  '  - Authenticated employer, checking approval status',
                );
                // Get company name from user data
                final userData = authData['userData'] as Map<String, dynamic>?;
                final companyName =
                    (userData?['companyName'] as String?) ?? 'Your Company';

                // Simplified approach - just check approval status directly
                return FutureBuilder<Map<String, dynamic>>(
                  future: _getFreshApprovalStatus(),
                  builder: (context, approvalSnapshot) {
                    if (approvalSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Scaffold(
                        backgroundColor: Colors.white,
                        body: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF007BFF),
                            ),
                          ),
                        ),
                      );
                    }

                    // Handle errors in approval status check
                    if (approvalSnapshot.hasError) {
                      debugPrint(
                        'Approval status error: ${approvalSnapshot.error}',
                      );
                      return EmployerVerificationScreen(
                        companyName: companyName,
                      );
                    }

                    final approvalData = approvalSnapshot.data ?? {};
                    final approvalStatus =
                        approvalData['approvalStatus'] as String? ?? 'pending';
                    final normalizedStatus = approvalStatus.toLowerCase();

                    debugPrint('  - Approval Status: $normalizedStatus');

                    if (normalizedStatus == 'approved') {
                      debugPrint('  - Employer approved, showing dashboard');
                      return const EmployerDashboardScreen();
                    } else {
                      debugPrint(
                        '  - Employer pending/rejected, showing verification',
                      );
                      return EmployerVerificationScreen(
                        companyName: companyName,
                      );
                    }
                  },
                );
              }
            }

            // User is signed in but registration is not complete
            debugPrint('  - Registration not complete, showing welcome screen');
            return const WelcomeScreen();
          },
        );
      },
    );
  }
}
