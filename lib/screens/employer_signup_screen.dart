import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/dropdown_service.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/locations_data.dart';
import '../widgets/searchable_dropdown.dart';
import 'welcome_screen.dart';

class EmployerSignupScreen extends StatefulWidget {
  const EmployerSignupScreen({super.key});

  @override
  State<EmployerSignupScreen> createState() => _EmployerSignupScreenState();
}

class _EmployerSignupScreenState extends State<EmployerSignupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final _companyNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _mobileController = TextEditingController();
  final _gstinController = TextEditingController();

  String? _selectedIndustry;
  String? _selectedCompanyType;
  String? _selectedState;
  String? _selectedDistrict;

  bool _isGoogleSigningIn = false;
  bool _gmailVerified = false;
  bool _isSaving = false;

  String? _gmailAccount;
  User? _googleUser;

  List<String> _industryTypes = []; // Firebase industry types
  List<String> _companyTypes = []; // Firebase company types

  static const primaryBlue = Color(0xFF007BFF);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Load industry types from Firebase
    _loadIndustryTypes();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _companyNameController.dispose();
    _contactPersonController.dispose();
    _mobileController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  Future<void> _loadIndustryTypes() async {
    try {
      debugPrint(
        '🔍 Loading industry types and company types from Firebase...',
      );

      final industryOptions = await DropdownService.getDropdownOptions(
        'industryType',
      );

      final companyTypeOptions = await DropdownService.getDropdownOptions(
        'companyType',
      );

      if (industryOptions.isNotEmpty) {
        setState(() {
          _industryTypes = industryOptions;
        });
        debugPrint(
          '✅ Loaded ${industryOptions.length} industry types from Firebase',
        );
      } else {
        debugPrint('⚠️ No industry types found in Firebase, using fallback');
        // Fallback to a basic list if Firebase data is not available
        setState(() {
          _industryTypes = [
            'Information Technology',
            'Healthcare',
            'Finance',
            'Education',
            'Manufacturing',
            'Retail',
            'Construction',
            'Transportation',
            'Hospitality',
            'Agriculture',
          ];
        });
      }

      if (companyTypeOptions.isNotEmpty) {
        setState(() {
          _companyTypes = companyTypeOptions;
        });
        debugPrint(
          '✅ Loaded ${companyTypeOptions.length} company types from Firebase',
        );
      } else {
        debugPrint('⚠️ No company types found in Firebase, using fallback');
        // Fallback to a basic list if Firebase data is not available
        setState(() {
          _companyTypes = [
            'Private Limited Company',
            'Public Limited Company',
            'Partnership Firm',
            'Sole Proprietorship',
            'Limited Liability Partnership (LLP)',
            'One Person Company (OPC)',
            'Section 8 Company (NGO)',
            'Startup',
          ];
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading dropdown options: $e');
      // Fallback to basic lists on error
      setState(() {
        _industryTypes = [
          'Information Technology',
          'Healthcare',
          'Finance',
          'Education',
          'Manufacturing',
          'Retail',
          'Construction',
          'Transportation',
          'Hospitality',
          'Agriculture',
        ];
        _companyTypes = [
          'Private Limited Company',
          'Public Limited Company',
          'Partnership Firm',
          'Sole Proprietorship',
          'Limited Liability Partnership (LLP)',
          'One Person Company (OPC)',
          'Section 8 Company (NGO)',
          'Startup',
        ];
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleSigningIn = true;
    });

    try {
      // Use the enhanced employer-specific Google sign-in
      final UserCredential? userCredential =
          await AuthService.signInWithGoogleForEmployer();

      if (userCredential == null) {
        setState(() {
          _isGoogleSigningIn = false;
        });
        return;
      }

      if (userCredential.user != null && mounted) {
        setState(() {
          _googleUser = userCredential.user;
          _gmailAccount = userCredential.user!.email;
          _gmailVerified = true;
          _isGoogleSigningIn = false;
          _populateNameFromCurrentUser();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email verified: ${_gmailAccount}'),
            backgroundColor: Colors.green.shade500,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleSigningIn = false;
        });

        String errorMessage = 'Email verification failed. Please try again.';
        if (e.toString().contains('already associated') ||
            e.toString().contains('conflict detected')) {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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

  void _populateNameFromCurrentUser() {
    if (_googleUser != null) {
      final displayName = _googleUser!.displayName;
      if (displayName != null && displayName.isNotEmpty && _contactPersonController.text.trim().isEmpty) {
        _contactPersonController.text = displayName;
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isGoogleSigningIn = true;
    });

    try {
      // Use the enhanced employer-specific Apple sign-in
      final UserCredential? userCredential =
          await AuthService.signInWithAppleForEmployer();

      if (userCredential == null) {
        setState(() {
          _isGoogleSigningIn = false;
        });
        return;
      }

      if (userCredential.user != null && mounted) {
        setState(() {
          _googleUser = userCredential.user;
          _gmailAccount = userCredential.user!.email;
          _gmailVerified = true;
          _isGoogleSigningIn = false;
          _populateNameFromCurrentUser();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email verified: ${_gmailAccount}'),
            backgroundColor: Colors.green.shade500,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleSigningIn = false;
        });

        String errorMessage = 'Verification failed. Please try again.';
        if (e.toString().contains('already associated') ||
            e.toString().contains('conflict detected') ||
            e.toString().contains('registered with a different provider')) {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }

        if (Platform.isIOS) {
          errorMessage = errorMessage
              .replaceAll(RegExp(r'Google', caseSensitive: false), 'original provider')
              .replaceAll(RegExp(r'Android', caseSensitive: false), 'mobile');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_companyNameController.text.trim().isEmpty) {
      _showValidationError('Please enter company name');
      return false;
    }

    if (_contactPersonController.text.trim().isEmpty) {
      _showValidationError('Please enter contact person name');
      return false;
    }

    if (!_gmailVerified) {
      _showValidationError('Please verify your email first');
      return false;
    }

    final mobileVal = _mobileController.text.trim();
    if (mobileVal.isNotEmpty) {
      if (mobileVal.length != 10) {
        _showValidationError('Please enter a valid 10-digit mobile number');
        return false;
      }
    }

    if (_selectedIndustry == null || _selectedIndustry!.isEmpty) {
      _showValidationError('Please select an industry type');
      return false;
    }

    if (_selectedCompanyType == null || _selectedCompanyType!.isEmpty) {
      _showValidationError('Please select a company type');
      return false;
    }

    if (_selectedState == null || _selectedState!.isEmpty) {
      _showValidationError('Please select a state');
      return false;
    }

    if (_selectedDistrict == null || _selectedDistrict!.isEmpty) {
      _showValidationError('Please select a district');
      return false;
    }

    return true;
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Verify user is still authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || _googleUser == null) {
        throw Exception(
          'User not authenticated. Please verify your email first.',
        );
      }

      // Wait a moment to ensure auth state is properly set
      await Future.delayed(const Duration(milliseconds: 500));

      // STRICT DUPLICATE PREVENTION: Check for existing candidate with same email
      final candidateExists = await FirebaseService.candidateExistsByEmail(
        _gmailAccount!,
      );
      if (candidateExists) {
        // Delete the Firebase Auth user since we can't proceed
        await _deleteCurrentAuthUser();
        throw Exception(
          'A candidate account already exists with this email. Please use a different email address.',
        );
      }

      // STRICT DUPLICATE PREVENTION: Check for existing employer with same email
      final employerQuery = await FirebaseFirestore.instance
          .collection('employers')
          .where('email', isEqualTo: _gmailAccount!)
          .limit(1)
          .get();

      // If email exists and it's not the current user, reject and delete auth user
      if (employerQuery.docs.isNotEmpty) {
        final existingEmployer = employerQuery.docs.first;
        if (existingEmployer.id != _googleUser!.uid) {
          // Delete the Firebase Auth user since we can't proceed
          await _deleteCurrentAuthUser();
          throw Exception(
            'An employer account already exists with this email. Please use a different email address.',
          );
        }
      }

      // STRICT DUPLICATE PREVENTION: Check for existing employer with same UID
      final existingEmployerDoc = await FirebaseFirestore.instance
          .collection('employers')
          .doc(_googleUser!.uid)
          .get();

      if (existingEmployerDoc.exists) {
        // Check if it's the same email - if not, it's a duplicate UID issue
        final existingData = existingEmployerDoc.data()!;
        final existingEmail = existingData['email'] as String?;

        if (existingEmail != null && existingEmail != _gmailAccount!) {
          // Delete the Firebase Auth user since we can't proceed
          await _deleteCurrentAuthUser();
          throw Exception(
            'This account is already associated with a different email address. Please use a different Google account.',
          );
        }

        // If same email, update the existing record instead of creating new
        await FirebaseFirestore.instance
            .collection('employers')
            .doc(_googleUser!.uid)
            .update({
              'companyName': _companyNameController.text.trim(),
              'contactPerson': _contactPersonController.text.trim(),
              'mobileNumber': _mobileController.text.trim(),
              'industryType': _selectedIndustry!,
              'companyType': _selectedCompanyType!,
              'gstinNumber': _gstinController.text.trim(),
              'state': _selectedState!,
              'district': _selectedDistrict!,
              'updatedAt': FieldValue.serverTimestamp(),
              'registrationComplete': true,
            });
      } else {
        // Create new employer record
        await FirebaseFirestore.instance
            .collection('employers')
            .doc(_googleUser!.uid)
            .set({
              'companyName': _companyNameController.text.trim(),
              'contactPerson': _contactPersonController.text.trim(),
              'email': _gmailAccount!,
              'mobileNumber': _mobileController.text.trim(),
              'industryType': _selectedIndustry!,
              'companyType': _selectedCompanyType!,
              'gstinNumber': _gstinController.text.trim(),
              'state': _selectedState!,
              'district': _selectedDistrict!,
              'uid': _googleUser!.uid,
              'createdAt': FieldValue.serverTimestamp(),
              'emailVerified': true,
              'registrationComplete': true,
              'approvalStatus':
                  'pending', // 'pending', 'approved', or 'rejected'
              'approvedAt': null,
              'approvedBy': null,
              'reason': '', // Empty by default, admin can add rejection reason
            });
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Registration completed! Your company details are under admin review.',
            ),
            backgroundColor: Colors.orange.shade500,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // Navigate to auth wrapper which will show approval pending screen
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/auth');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        String errorMessage = 'Registration failed. Please try again.';
        if (e.toString().contains('PERMISSION_DENIED')) {
          errorMessage =
              'Authentication required. Please verify your email first.';
        } else if (e.toString().contains(
          'Missing or insufficient permissions',
        )) {
          errorMessage =
              'Permission denied. Please ensure you are signed in.';
        } else if (e.toString().contains('already exists') ||
            e.toString().contains('already associated')) {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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

  Future<void> _deleteCurrentAuthUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Sign out first to clear auth state
        await AuthService.signOut();
        // Delete the user account
        await user.delete();
      }
    } catch (e) {
      debugPrint('Error deleting auth user: $e');
      // Even if deletion fails, sign out to clear the state
      await AuthService.signOut();
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
          'Company Registration',
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
      body: GestureDetector(
        onTap: () {
          // Remove focus when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
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
                    color: primaryBlue.withValues(alpha: 0.03),
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
                    color: primaryBlue.withValues(alpha: 0.04),
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Header
                      const Text(
                        'Company Registration',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Create your company profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Company Name Field
                            _buildTextField(
                              controller: _companyNameController,
                              label: 'Company Name',
                              hint: 'Enter company name',
                              icon: Icons.domain_rounded,
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Company name is required';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Company Type Dropdown
                            SearchableDropdown(
                              value: _selectedCompanyType,
                              items: _companyTypes,
                              labelText: 'Company Type',
                              hintText: 'Search and select company type',
                              prefixIcon: Icons.business_rounded,
                              primaryColor: primaryBlue,
                              onChanged: (value) {
                                setState(() {
                                  _selectedCompanyType = value;
                                });
                              },
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please select a company type';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // GSTIN Number Field
                            _buildTextField(
                              controller: _gstinController,
                              label: 'GSTIN Number (Optional)',
                              hint: 'Enter 15-digit GSTIN number',
                              icon: Icons.receipt_long_rounded,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Z0-9]'),
                                ),
                                LengthLimitingTextInputFormatter(15),
                              ],
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (value.length != 15) {
                                    return 'GSTIN must be 15 characters';
                                  }
                                  // Basic GSTIN format validation
                                  if (!RegExp(
                                    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
                                  ).hasMatch(value)) {
                                    return 'Invalid GSTIN format';
                                  }
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Contact Person Name Field
                            _buildTextField(
                              controller: _contactPersonController,
                              label: 'Contact Person Name',
                              hint: 'Enter contact person name',
                              icon: Icons.person_rounded,
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Contact person name is required';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Email Authentication Section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Email Authentication'),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _gmailVerified
                                          ? Colors.green.shade300
                                          : Colors.grey.shade200,
                                      width: 1,
                                    ),
                                    color: _gmailVerified
                                        ? Colors.green.shade50
                                        : Colors.grey.shade50,
                                  ),
                                  child: Column(
                                    children: [
                                      if (_gmailVerified) ...[
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green.shade500,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Email Verified',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF1F2937),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _gmailAccount ?? '',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else ...[
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.email_rounded,
                                              color: primaryBlue.withValues(
                                                alpha: 0.6,
                                              ),
                                              size: 24,
                                            ),
                                            const SizedBox(width: 12),
                                            const Expanded(
                                              child: Text(
                                                'Verify your email address',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF1F2937),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: _isGoogleSigningIn
                                                    ? null
                                                    : _handleGoogleSignIn,
                                                icon: _isGoogleSigningIn
                                                    ? const SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                        ),
                                                      )
                                                    : Image.asset(
                                                        'assets/google_logo.png',
                                                        height: 20,
                                                        width: 20,
                                                        errorBuilder: (context, error, stackTrace) =>
                                                            const Icon(Icons.login_rounded, size: 20, color: Colors.white),
                                                      ),
                                                label: const Text('Verify Google'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: primaryBlue,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                              ),
                                            ),
                                            if (Platform.isIOS) ...[
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: _isGoogleSigningIn
                                                      ? null
                                                      : _handleAppleSignIn,
                                                  icon: _isGoogleSigningIn
                                                      ? const SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                          ),
                                                        )
                                                      : const Icon(Icons.apple, size: 24, color: Colors.white),
                                                  label: const Text('Verify Apple'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.black,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Mobile Number Field
                            _buildTextField(
                              controller: _mobileController,
                              label: 'Mobile Number (Optional)',
                              hint: 'Enter 10-digit mobile number',
                              icon: Icons.phone_rounded,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (value.length != 10) {
                                    return 'Mobile number must be 10 digits';
                                  }
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            const SizedBox(height: 16),

                            // Industry Type Dropdown
                            SearchableDropdown(
                              value: _selectedIndustry,
                              items: _industryTypes,
                              labelText: 'Industry Type',
                              hintText: 'Search and select industry type',
                              prefixIcon: Icons.category_rounded,
                              primaryColor: primaryBlue,
                              onChanged: (value) {
                                setState(() {
                                  _selectedIndustry = value;
                                });
                              },
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please select an industry type';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // State Dropdown
                            SearchableDropdown(
                              value: _selectedState,
                              items: indianStates,
                              labelText: 'State',
                              hintText: 'Search and select state',
                              prefixIcon: Icons.location_on_rounded,
                              primaryColor: primaryBlue,
                              onChanged: (value) {
                                setState(() {
                                  _selectedState = value;
                                  _selectedDistrict =
                                      null; // Reset district when state changes
                                });
                              },
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please select a state';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // District Dropdown
                            SearchableDropdown(
                              value: _selectedDistrict,
                              items: _selectedState != null
                                  ? (districtsByState[_selectedState!] ??
                                        <String>[])
                                  : <String>[],
                              labelText: 'District',
                              hintText: _selectedState != null
                                  ? 'Search and select district'
                                  : 'Select state first',
                              prefixIcon: Icons.location_city_rounded,
                              primaryColor: primaryBlue,
                              onChanged: (value) {
                                setState(() {
                                  _selectedDistrict = value;
                                });
                              },
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please select a district';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            const SizedBox(height: 32),

                            // Back and Submit Buttons
                            Row(
                              children: [
                                // Back Button
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withValues(
                                            alpha: 0.15,
                                          ),
                                          blurRadius: 15,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isSaving
                                          ? null
                                          : () => Navigator.pop(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade100,
                                        foregroundColor: Color(0xFF1F2937),
                                        elevation: 0,
                                        disabledBackgroundColor:
                                            Colors.grey.shade200,
                                        minimumSize: const Size(
                                          double.infinity,
                                          56,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '‹ Back',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 16),

                                // Submit Button
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryBlue.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isSaving ? null : _submitForm,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryBlue,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        disabledBackgroundColor:
                                            Colors.grey.shade300,
                                        minimumSize: const Size(
                                          double.infinity,
                                          56,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _isSaving
                                            ? 'Submitting...'
                                            : 'Submit ›',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: TextFormField(
            controller: controller,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(
                icon,
                color: primaryBlue.withValues(alpha: 0.6),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2937),
        letterSpacing: 0.3,
      ),
    );
  }
}
