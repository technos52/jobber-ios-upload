import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import '../services/auth_service.dart';

class EmployerLoginScreen extends StatefulWidget {
  const EmployerLoginScreen({super.key});

  @override
  State<EmployerLoginScreen> createState() => _EmployerLoginScreenState();
}

class _EmployerLoginScreenState extends State<EmployerLoginScreen> {
  bool _isSigningIn = false;

  Future<void> _handleSignIn(Future<UserCredential?> Function() signInMethod, String providerName) async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      debugPrint('🔍 Employer login: Starting $providerName sign in');
      
      final UserCredential? userCredential = await signInMethod();

      if (userCredential == null) {
        debugPrint('🔍 Employer login: $providerName sign in returned null');
        setState(() {
          _isSigningIn = false;
        });
        return;
      }

      debugPrint('🔍 Employer login: Got user credential: ${userCredential.user?.email}');

      if (userCredential.user != null && mounted) {
        // Check if employer exists in database using UID
        debugPrint('🔍 Employer login: Checking if employer document exists for UID: ${userCredential.user!.uid}');
        final employerDoc = await FirebaseFirestore.instance
            .collection('employers')
            .doc(userCredential.user!.uid)
            .get();

        debugPrint('🔍 Employer login: Employer document exists: ${employerDoc.exists}');
        
        if (!employerDoc.exists) {
          // Employer not found, show error
          debugPrint('🔍 Employer login: No employer account found');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No employer account found. Please create a new account first.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            // Sign out the user
            await FirebaseAuth.instance.signOut();
            await GoogleSignIn().signOut();
          }
        } else {
          // Employer found, navigate to dashboard
          debugPrint('🔍 Employer login: Employer account found, navigating to AuthWrapper');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login successful!'),
                backgroundColor: Colors.green,
              ),
            );
            // Let AuthWrapper handle navigation properly
            Navigator.of(context).pushReplacementNamed('/auth');
          }
        }
      }
    } catch (e) {
      debugPrint('🔍 Employer login: Error signing in with $providerName: $e');
      if (mounted) {
        String errorMessage = 'Error signing in. Please try again.';
        if (e.toString().contains('permission-denied')) {
          errorMessage =
              'Unable to verify account. Please try again or contact support.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );

        // Sign out on error to ensure clean state
        try {
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn().signOut();
        } catch (signOutError) {
          debugPrint('Error signing out after failed login: $signOutError');
        }
      }
    }

    if (mounted) {
      setState(() {
        _isSigningIn = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    await _handleSignIn(() => AuthService.signInWithGoogle(), 'Google');
  }

  Future<void> _signInWithApple() async {
    await _handleSignIn(() => AuthService.signInWithApple(), 'Apple');
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF007BFF);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Employer Login',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              // Top section with icon and text
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryBlue.withOpacity(0.15),
                            primaryBlue.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: primaryBlue.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.login_rounded,
                        size: 56,
                        color: primaryBlue,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Title
                    const Text(
                      'Welcome Back!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Sign in to your employer account to continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.1,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom section with login button
              Column(
                children: [
                   // Google Sign In Button
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSigningIn ? null : _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSigningIn
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/google_logo.png',
                                  height: 24,
                                  width: 24,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.login,
                                      size: 24,
                                      color: Colors.white,
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Sign In with Google',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  if (Platform.isIOS) ...[
                    const SizedBox(height: 16),
                    // Apple Sign In Button
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSigningIn ? null : _signInWithApple,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSigningIn
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.apple,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Sign In with Apple',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],

                  ),

                  const SizedBox(height: 24),

                  // Don't have account link
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    child: RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF6B7280),
                              letterSpacing: 0.1,
                            ),
                          ),
                          TextSpan(
                            text: 'Create One',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.04),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
