import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'candidate_registration_step2_screen.dart';
import 'welcome_screen.dart';

class CandidateRegistrationStep1Screen extends StatefulWidget {
  const CandidateRegistrationStep1Screen({super.key});

  @override
  State<CandidateRegistrationStep1Screen> createState() =>
      _CandidateRegistrationStep1ScreenState();
}

class _CandidateRegistrationStep1ScreenState
    extends State<CandidateRegistrationStep1Screen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final _fullNameController = TextEditingController();
  final _ageYearController = TextEditingController();
  final _mobileController = TextEditingController();
  final _mobileFocusNode = FocusNode();

  String _selectedTitle = 'Mr.';
  String _selectedGender = 'Male';
  bool _ageConfirmed = false;
  int? _calculatedAge;
  bool _isSaving = false;

  // Firebase Auth fields
  User? _currentUser;
  bool _isSigningIn = false;

  static const primaryBlue = Color(0xFF007BFF);
  static const int currentYear = 2025;

  @override
  void initState() {
    super.initState();
    _ageYearController.addListener(_calculateAge);
    _checkAuthState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  void _checkAuthState() {
    setState(() {
      _currentUser = FirebaseAuth.instance.currentUser;
      _populateNameFromCurrentUser();
    });
  }

  void _populateNameFromCurrentUser() {
    if (_currentUser != null) {
      final displayName = _currentUser!.displayName;
      if (displayName != null && displayName.isNotEmpty && _fullNameController.text.trim().isEmpty) {
        String nameWithoutTitle = displayName;
        String foundTitle = 'Mr.';
        if (displayName.startsWith('Mr. ')) {
          nameWithoutTitle = displayName.substring(4);
          foundTitle = 'Mr.';
        } else if (displayName.startsWith('Miss. ')) {
          nameWithoutTitle = displayName.substring(6);
          foundTitle = 'Miss.';
        } else if (displayName.startsWith('Mrs. ')) {
          nameWithoutTitle = displayName.substring(5);
          foundTitle = 'Mrs.';
        }
        _fullNameController.text = nameWithoutTitle;
        _selectedTitle = foundTitle;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset loading state when user comes back to this screen
    if (_isSaving) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _fullNameController.dispose();
    _ageYearController.dispose();
    _mobileController.dispose();
    _mobileFocusNode.dispose();
    super.dispose();
  }

  void _calculateAge() {
    final year = int.tryParse(_ageYearController.text);
    if (year != null && year >= 1961 && year <= 2008) {
      setState(() {
        _calculatedAge = currentYear - year;
      });
    } else {
      setState(() {
        _calculatedAge = null;
      });
    }
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    final mobile = _mobileController.text.trim();
    if (mobile.isNotEmpty) {
      if (mobile.length != 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter complete 10-digit mobile number'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return false;
      }
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter a valid 10-digit mobile number'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return false;
      }
    }

    // Validate age
    if (_calculatedAge == null || _calculatedAge! < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You must be 18+ years old to register'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return false;
    }

    // Validate age confirmation checkbox
    if (!_ageConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please confirm that you are 18+ years old'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      final UserCredential? userCredential =
          await AuthService.signInWithGoogleForCandidate();

      if (userCredential != null && mounted) {
        setState(() {
          _currentUser = userCredential.user;
          _isSigningIn = false;
          _populateNameFromCurrentUser();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signed in as ${_currentUser!.email}'),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        setState(() {
          _isSigningIn = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });

        // Handle existing user scenarios - redirect immediately
        if (e.toString().contains('EXISTING_USER_COMPLETE:')) {
          final mobileNumber = e.toString().split(':')[1];
          _handleExistingCompleteUser(mobileNumber);
        } else if (e.toString().contains('EXISTING_USER_INCOMPLETE:')) {
          final mobileNumber = e.toString().split(':')[1];
          _handleExistingIncompleteUser(mobileNumber);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign-in failed: $e'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      final UserCredential? userCredential =
          await AuthService.signInWithAppleForCandidate();

      if (userCredential != null && mounted) {
        setState(() {
          _currentUser = userCredential.user;
          _isSigningIn = false;
          _populateNameFromCurrentUser();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Signed in with Apple as ${_currentUser!.email ?? "user"}',
            ),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        setState(() {
          _isSigningIn = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });

        // Handle existing user scenarios - redirect immediately
        if (e.toString().contains('EXISTING_USER_COMPLETE:')) {
          final mobileNumber = e.toString().split(':')[1];
          _handleExistingCompleteUser(mobileNumber);
        } else if (e.toString().contains('EXISTING_USER_INCOMPLETE:')) {
          final mobileNumber = e.toString().split(':')[1];
          _handleExistingIncompleteUser(mobileNumber);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign-in failed: $e'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  void _handleExistingCompleteUser(String mobileNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.person_rounded, color: Colors.green.shade600, size: 24),
            const SizedBox(width: 12),
            const Text('Welcome Back!'),
          ],
        ),
        content: const Text(
          'You already have a complete candidate profile. Would you like to go to your dashboard?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await AuthService.signOut();
              Navigator.pushReplacementNamed(context, '/welcome');
            },
            child: const Text('Use Different Email'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Navigate directly to candidate dashboard
              Navigator.pushReplacementNamed(context, '/candidate_dashboard');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Go to Dashboard'),
          ),
        ],
      ),
    );
  }

  void _handleExistingIncompleteUser(String mobileNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_rounded, color: Colors.orange.shade600, size: 24),
            const SizedBox(width: 12),
            const Text('Continue Registration'),
          ],
        ),
        content: const Text(
          'You have an incomplete registration. Would you like to continue where you left off?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await AuthService.signOut();
              Navigator.pushReplacementNamed(context, '/welcome');
            },
            child: const Text('Use Different Email'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              // Load existing data and continue registration
              await _loadExistingUserData(mobileNumber);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue Registration'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadExistingUserData(String mobileNumber) async {
    try {
      final candidateData = await FirebaseService.getCandidateData(
        mobileNumber,
      );
      if (candidateData != null && mounted) {
        setState(() {
          // Populate form fields with existing data
          final fullName = candidateData['fullName'] as String? ?? '';
          final title = candidateData['title'] as String? ?? 'Mr.';

          // Extract name without title
          String nameWithoutTitle = fullName;
          if (fullName.startsWith('Mr. ')) {
            nameWithoutTitle = fullName.substring(4);
          } else if (fullName.startsWith('Miss. ')) {
            nameWithoutTitle = fullName.substring(6);
          } else if (fullName.startsWith('Mrs. ')) {
            nameWithoutTitle = fullName.substring(5);
          }

          _fullNameController.text = nameWithoutTitle;
          _selectedTitle = title;
          _selectedGender = candidateData['gender'] as String? ?? 'Male';
          _mobileController.text =
              candidateData['mobileNumber'] as String? ?? '';

          final birthYear = candidateData['birthYear'] as int?;
          if (birthYear != null) {
            _ageYearController.text = birthYear.toString();
            _calculateAge();
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Your previous data has been loaded'),
            backgroundColor: Colors.blue.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading your data: $e'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _handleNext() async {
    if (!_validateForm() || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final fullName = '${_selectedTitle} ${_fullNameController.text.trim()}';
    final mobileNumber = _mobileController.text.trim();
    final birthYear = int.parse(_ageYearController.text);

    try {
      await FirebaseService.saveCandidateStep1Data(
        fullName: fullName,
        title: _selectedTitle,
        gender: _selectedGender,
        mobileNumber: mobileNumber,
        birthYear: birthYear,
        age: _calculatedAge!,
      );

      if (mounted) {
        setState(() {
          _isSaving = false; // Reset loading state before navigation
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CandidateRegistrationStep2Screen(),
            settings: RouteSettings(arguments: mobileNumber),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        // Check if it's an authentication error
        if (e.toString().contains('sign in') ||
            e.toString().contains('Authentication')) {
          // Show authentication error dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.login_rounded, color: primaryBlue, size: 24),
                  const SizedBox(width: 12),
                  const Text('Authentication Required'),
                ],
              ),
              content: const Text(
                'You need to sign in with Google first to continue registration. Please go back and sign in.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to auth screen
                  },
                  child: const Text('Go Back'),
                ),
              ],
            ),
          );
        } else {
          // Show regular error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving data: $e'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Candidate Registration',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Change Email - Logout',
            icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Change Email?'),
                  content: const Text(
                    'Do you want to logout and use a different email address?',
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                    ),
                  ),
                );

                // Use AuthService for proper logout
                await AuthService.signOut();

                if (context.mounted) {
                  // Close loading dialog
                  Navigator.pop(context);

                  // Navigate to welcome screen and clear all routes
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const WelcomeScreen(),
                    ),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryBlue.withOpacity(0.02),
                  Colors.white,
                  Colors.white,
                ],
              ),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildProgressStep('1', true, 'Basic Info'),
                        Expanded(child: _buildProgressLine(false)),
                        _buildProgressStep('2', false, 'Details'),
                        Expanded(child: _buildProgressLine(false)),
                        _buildProgressStep('3', false, 'Review'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Google Sign-In Section
                            Container(
                              padding: const EdgeInsets.all(20),
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: _currentUser != null
                                    ? Colors.green.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _currentUser != null
                                      ? Colors.green.shade200
                                      : Colors.blue.shade200,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _currentUser != null
                                            ? Icons.check_circle_rounded
                                            : Icons.login_rounded,
                                        color: _currentUser != null
                                            ? Colors.green.shade600
                                            : primaryBlue,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _currentUser != null
                                                  ? 'Signed in as:'
                                                  : 'Sign in Required',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _currentUser != null
                                                    ? Colors.green.shade700
                                                    : primaryBlue,
                                              ),
                                            ),
                                            if (_currentUser != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                _currentUser!.email ??
                                                    'No email',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.green.shade600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_currentUser == null) ...[
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _isSigningIn
                                            ? null
                                            : _handleGoogleSignIn,
                                        icon: _isSigningIn
                                            ? SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                            : Image.asset(
                                                'assets/google_logo.png',
                                                height: 20,
                                                width: 20,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => const Icon(
                                                      Icons
                                                          .g_mobiledata_rounded,
                                                      size: 24,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                        label: Text(
                                          _isSigningIn
                                              ? 'Signing in...'
                                              : 'Sign in with Google',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryBlue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (Platform.isIOS) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _isSigningIn
                                              ? null
                                              : _handleAppleSignIn,
                                          icon: _isSigningIn
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                                  ),
                                                )
                                              : const Icon(
                                                Icons.apple,
                                                size: 24,
                                                color: Colors.white,
                                              ),
                                          label: Text(
                                            _isSigningIn
                                                ? 'Signing in...'
                                                : 'Sign in with Apple',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.black,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      Platform.isIOS
                                          ? 'You must sign in with Google or Apple to continue registration'
                                          : 'You must sign in with Google to continue registration',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Full Name with Title
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 20,
                                  color: primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Full Name',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  '*',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Title dropdown
                                Container(
                                  height: 54,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.white,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedTitle,
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 20,
                                        color: Color(0xFF6B7280),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1F2937),
                                      ),
                                      items: ['Mr.', 'Miss.', 'Mrs.']
                                          .map(
                                            (title) => DropdownMenuItem(
                                              value: title,
                                              child: Text(title),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedTitle = value!;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Name input
                                Expanded(
                                  child: TextFormField(
                                    controller: _fullNameController,
                                    decoration: InputDecoration(
                                      hintText: 'Shailesh Sharma',
                                      hintStyle: TextStyle(
                                        color: const Color(0xFF9CA3AF),
                                        fontSize: 15,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE5E7EB),
                                          width: 1.5,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE5E7EB),
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: primaryBlue,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1F2937),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter your full name';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Gender
                            Row(
                              children: [
                                Icon(
                                  Icons.wc_rounded,
                                  size: 20,
                                  color: primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Gender',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  '*',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildGenderOption(
                                    'Male',
                                    Icons.male_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildGenderOption(
                                    'Female',
                                    Icons.female_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildGenderOption(
                                    'Others',
                                    Icons.transgender_rounded,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Mobile Number
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_android_rounded,
                                  size: 20,
                                  color: primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Mobile Number (Optional)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  height: 54,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: const Color(0xFFF9FAFB),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '+91',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _mobileController,
                                    focusNode: _mobileFocusNode,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: 'Enter 10-digit number',
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 15,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE5E7EB),
                                          width: 1.5,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE5E7EB),
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: primaryBlue,
                                          width: 2,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1F2937),
                                    ),
                                    validator: (value) {
                                      if (value != null && value.trim().isNotEmpty) {
                                        if (value.length != 10) {
                                          return 'Mobile number must be 10 digits';
                                        }
                                        if (!RegExp(
                                          r'^[6-9]\d{9}$',
                                        ).hasMatch(value)) {
                                          return 'Invalid mobile number';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Age Year
                            Row(
                              children: [
                                Icon(
                                  Icons.cake_outlined,
                                  size: 20,
                                  color: primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Birth Year',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  '*',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _ageYearController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(4),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: 'e.g., 1990',
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 15,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE5E7EB),
                                          width: 1.5,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE5E7EB),
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: primaryBlue,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1F2937),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      final year = int.tryParse(value);
                                      if (year == null ||
                                          year < 1961 ||
                                          year > 2008) {
                                        return 'Invalid year';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    height: 54,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _calculatedAge != null &&
                                              _calculatedAge! >= 18
                                          ? primaryBlue.withOpacity(0.08)
                                          : Colors.red.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            _calculatedAge != null &&
                                                _calculatedAge! >= 18
                                            ? primaryBlue.withOpacity(0.2)
                                            : Colors.red.withOpacity(0.2),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _calculatedAge != null
                                            ? 'Age: $_calculatedAge Years'
                                            : 'Age: --',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              _calculatedAge != null &&
                                                  _calculatedAge! >= 18
                                              ? primaryBlue
                                              : Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Age note
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.orange.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Must be 18+ years as per Indian Labour Law',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Age confirmation checkbox
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _ageConfirmed = !_ageConfirmed;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: _ageConfirmed
                                            ? primaryBlue
                                            : Colors.white,
                                        border: Border.all(
                                          color: _ageConfirmed
                                              ? primaryBlue
                                              : const Color(0xFFE5E7EB),
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: _ageConfirmed
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'I confirm that I am 18+ years old',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom buttons
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Back button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6B7280),
                              side: const BorderSide(
                                color: Color(0xFFE5E7EB),
                                width: 2,
                              ),
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_back_ios_rounded, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Back',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: _currentUser == null
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.grey.shade400,
                                        Colors.grey.shade500,
                                      ],
                                    )
                                  : const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [primaryBlue, Color(0xFF0056CC)],
                                    ),
                              boxShadow: _currentUser == null
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: primaryBlue.withOpacity(0.35),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                            ),
                            child: ElevatedButton(
                              onPressed: (_isSaving || _currentUser == null)
                                  ? null
                                  : _handleNext,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                minimumSize: const Size(double.infinity, 54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _currentUser == null
                                              ? 'Sign in Required'
                                              : 'Next',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          _currentUser == null
                                              ? Icons.login_rounded
                                              : Icons.arrow_forward_ios_rounded,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(String step, bool isActive, String label) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryBlue, Color(0xFF0056CC)],
                  )
                : null,
            color: isActive ? null : Colors.white,
            border: Border.all(
              color: isActive ? primaryBlue : const Color(0xFFE5E7EB),
              width: 2.5,
            ),
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.edit_rounded, size: 18, color: Colors.white)
                : Text(
                    step,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(bool isActive) {
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(colors: [primaryBlue, Color(0xFF0056CC)])
            : null,
        color: isActive ? null : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildGenderOption(String gender, IconData icon) {
    final isSelected = _selectedGender == gender;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedGender = gender;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 64,
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryBlue.withOpacity(0.12),
                    primaryBlue.withOpacity(0.06),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white,
          border: Border.all(
            color: isSelected ? primaryBlue : const Color(0xFFE5E7EB),
            width: isSelected ? 2.5 : 1.5,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryBlue : const Color(0xFF6B7280),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              gender,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? primaryBlue : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
