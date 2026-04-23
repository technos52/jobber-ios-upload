import 'package:flutter/material.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';
import 'candidate_auth_screen.dart';
import 'employer_auth_screen.dart';
import '../services/auth_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Fade animation for content
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Scale animation for cards
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _scaleController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const primaryBlue = Color(0xFF007BFF);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: size.height * 0.02),

                    // Clean Logo without any shadow or background
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.elasticOut,
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: value,
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                width: 100,
                                height: 100,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Brand name with custom styling
                    Center(
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF007BFF), Color(0xFF0056D2)],
                        ).createShader(bounds),
                        child: const Text(
                          'All Job Open',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Headline with better styling
                    const Text(
                      'Welcome',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Choose your role to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.15,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Enhanced Cards with blue theme
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        children: [
                          // Job Seeker Card - Enhanced with blue accents
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: primaryBlue.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CandidateAuthScreen(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              primaryBlue.withValues(
                                                alpha: 0.1,
                                              ),
                                              primaryBlue.withValues(
                                                alpha: 0.05,
                                              ),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person_search_rounded,
                                          size: 32,
                                          color: Color(0xFF007BFF),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Apply for Job',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1F2937),
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Browse and apply to opportunities',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                                color: Colors.grey.shade600,
                                                letterSpacing: 0.1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primaryBlue.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Color(0xFF007BFF),
                                          size: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Employer Card - Enhanced with blue accents
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: primaryBlue.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const EmployerAuthScreen(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              primaryBlue.withValues(
                                                alpha: 0.1,
                                              ),
                                              primaryBlue.withValues(
                                                alpha: 0.05,
                                              ),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.business_center_rounded,
                                          size: 32,
                                          color: Color(0xFF007BFF),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Hire Candidate',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1F2937),
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Post jobs and find top talent',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                                color: Colors.grey.shade600,
                                                letterSpacing: 0.1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primaryBlue.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Color(0xFF007BFF),
                                          size: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Enhanced privacy policy and terms buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PrivacyPolicyScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.privacy_tip_outlined,
                            size: 18,
                            color: Color(0xFF007BFF),
                          ),
                          label: const Text(
                            'Privacy\nPolicy',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF007BFF),
                              letterSpacing: 0.1,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TermsConditionsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.gavel_outlined,
                            size: 18,
                            color: Color(0xFF007BFF),
                          ),
                          label: const Text(
                            'Terms &\nConditions',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF007BFF),
                              letterSpacing: 0.1,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Guest Login Option for Play Store Reviewers
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: primaryBlue.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: TextButton.icon(
                        onPressed: _handleGuestEntry,
                        icon: const Icon(
                          Icons.explore_outlined,
                          color: primaryBlue,
                        ),
                        label: const Text(
                          'Continue as Guest (Demo Mode)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: primaryBlue,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Perfect for reviewers to explore app features',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleGuestEntry() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Explore Demo Mode'),
        content: const Text(
          'Would you like to explore the app as an Applicant or an Employer?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _signInAsGuest('candidate');
            },
            child: const Text('Applicant'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _signInAsGuest('employer');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Employer'),
          ),
        ],
      ),
    );
  }

  Future<void> _signInAsGuest(String role) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)),
            ),
          ),
    );

    try {
      debugPrint('🚀 Starting anonymous sign-in as $role...');
      await AuthService.signInAnonymously();

      if (context.mounted) {
        Navigator.pop(context); // Close loading

        if (role == 'candidate') {
          Navigator.of(context).pushReplacementNamed('/candidate_dashboard');
        } else {
          Navigator.of(context).pushReplacementNamed('/employer_dashboard');
        }
      }
    } catch (e) {
      debugPrint('❌ Anonymous sign-in failed: $e');
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guest login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
