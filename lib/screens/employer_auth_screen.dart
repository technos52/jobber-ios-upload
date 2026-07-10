import 'package:flutter/material.dart';
import 'employer_signup_screen.dart';
import 'employer_login_screen.dart';

class EmployerAuthScreen extends StatelessWidget {
  const EmployerAuthScreen({super.key});

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
      ),
      body: Stack(
        children: [
          // Background decorative elements
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryBlue.withOpacity(0.03),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: -60,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryBlue.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryBlue.withOpacity(0.03),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -50,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryBlue.withOpacity(0.04),
              ),
            ),
          ),
          // Decorative icons
          Positioned(
            top: 60,
            right: 40,
            child: Icon(
              Icons.business_rounded,
              size: 40,
              color: primaryBlue.withOpacity(0.15),
            ),
          ),
          Positioned(
            top: 180,
            left: 30,
            child: Icon(
              Icons.corporate_fare_rounded,
              size: 35,
              color: primaryBlue.withOpacity(0.18),
            ),
          ),
          Positioned(
            bottom: 200,
            right: 30,
            child: Icon(
              Icons.groups_rounded,
              size: 38,
              color: primaryBlue.withOpacity(0.15),
            ),
          ),
          Positioned(
            bottom: 150,
            left: 35,
            child: Icon(
              Icons.trending_up_rounded,
              size: 32,
              color: primaryBlue.withOpacity(0.15),
            ),
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                children: [
                  // Top section with icon and text
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon with enhanced styling
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primaryBlue.withOpacity(0.15),
                                primaryBlue.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: primaryBlue.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.business_center_rounded,
                            size: 48,
                            color: primaryBlue,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Title
                        const Text(
                          'Employer Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Subtitle
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Create your company profile or sign in',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
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

                  // Bottom section with buttons
                  Column(
                    children: [
                      // Divider for visual separation
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(bottom: 32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.grey.shade200,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),

                      // Create New Account Button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryBlue.withOpacity(0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            // Navigate to Employer Signup
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const EmployerSignupScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Create New Account',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Login Link with better styling
                      TextButton(
                        onPressed: () {
                          // Navigate to Employer Login Screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EmployerLoginScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Already have an account? ',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: 0.1,
                                ),
                              ),
                              TextSpan(
                                text: 'Login',
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

                      SizedBox(height: size.height * 0.02),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
