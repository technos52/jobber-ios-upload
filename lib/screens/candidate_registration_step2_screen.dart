import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/google_search_service.dart';
import '../services/dropdown_service.dart';
import '../widgets/searchable_dropdown.dart';
import '../dropdown_options/dropdown_options.dart';
import '../dropdown_options/qualification.dart';
import '../dropdown_options/job_category.dart';
import '../dropdown_options/job_type.dart';
import '../dropdown_options/designation.dart';
import 'welcome_screen.dart';

class CandidateRegistrationStep2Screen extends StatefulWidget {
  const CandidateRegistrationStep2Screen({super.key});

  @override
  State<CandidateRegistrationStep2Screen> createState() =>
      _CandidateRegistrationStep2ScreenState();
}

class _CandidateRegistrationStep2ScreenState
    extends State<CandidateRegistrationStep2Screen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final _qualificationController = TextEditingController();

  final _departmentController = TextEditingController();
  final _jobCategoryController = TextEditingController();
  final _jobTypeController = TextEditingController();
  final _designationController = TextEditingController();
  final _companyController = TextEditingController();

  String? _selectedQualification;

  int _experienceYears = 0;
  int _experienceMonths = 0;
  String? _currentlyWorking;
  int? _selectedNoticePeriod;
  bool _isSubmitting = false;
  bool _isVerifyingCompany = false;
  bool _companyVerified = false;

  // Dynamic dropdown options from Firebase
  List<String> _qualifications = [];
  List<String> _jobCategories = [];
  List<String> _jobTypes = [];
  List<String> _designations = [];
  List<String> _companyTypes = [];
  List<String> _departments = [];
  String? _selectedCompanyType;
  String? _selectedJobCategory;
  String? _selectedJobType;
  String? _selectedDesignation;
  String? _selectedDepartment;

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
    _companyController.addListener(_verifyCompanyName);

    // Load dropdown options from Firebase
    _loadDropdownOptions();
  }

  /// Load dropdown options - prioritize Firebase for qualifications, local for others
  Future<void> _loadDropdownOptions() async {
    try {
      print('🔍 Loading dropdown options (Firebase + local)...');

      // Load local options as defaults first
      setState(() {
        _qualifications = QualificationOptions.values;
        _jobCategories = JobCategoryOptions.values;
        _jobTypes = JobTypeOptions.values;
        _designations = DesignationOptions.values;
        _departments = ['IT', 'HR', 'Finance', 'Marketing', 'Sales', 'Operations'];
      });

      print('✅ Loaded local dropdown options as defaults');

      // Try to get options from Firebase, prioritizing qualifications
      try {
        final options = await DropdownService.getAllDropdownOptions();
        if (mounted && options.isNotEmpty) {
          setState(() {
            // Update qualifications from Firebase if available
            if (options.containsKey('qualifications') &&
                options['qualifications']!.isNotEmpty) {
              _qualifications = options['qualifications']!;
              print(
                '✅ Updated qualifications from Firebase: ${_qualifications.length} items',
              );
            } else {
              print('⚠️ No qualifications in Firebase, using local options');
            }

            // Update other dropdowns from Firebase if available
            if (options.containsKey('job_categories') &&
                options['job_categories']!.isNotEmpty) {
              _jobCategories = options['job_categories']!;
              print(
                '✅ Updated job categories from Firebase: ${_jobCategories.length} items',
              );
            }

            if (options.containsKey('job_types') &&
                options['job_types']!.isNotEmpty) {
              _jobTypes = options['job_types']!;
              print(
                '✅ Updated job types from Firebase: ${_jobTypes.length} items',
              );
            }

            if (options.containsKey('designations') &&
                options['designations']!.isNotEmpty) {
              _designations = options['designations']!;
              print(
                '✅ Updated designations from Firebase: ${_designations.length} items',
              );
            }

            // Company types from Firebase
            if (options.containsKey('company_types')) {
              _companyTypes = options['company_types'] ?? [];
            }

            // Departments from Firebase (candidateDepartment or departments key)
            if (options.containsKey('candidate_departments') &&
                options['candidate_departments']!.isNotEmpty) {
              _departments = options['candidate_departments']!;
              print(
                '✅ Updated departments from Firebase (candidateDepartment): ${_departments.length} items',
              );
            } else if (options.containsKey('departments') &&
                options['departments']!.isNotEmpty) {
              _departments = options['departments']!;
              print(
                '✅ Updated departments from Firebase: ${_departments.length} items',
              );
            }
          });
          print('✅ Loaded Firebase options successfully');
        }
      } catch (e) {
        print('⚠️ Firebase options not available, using local/defaults: $e');
      }

      // Ensure company types has fallback values
      if (_companyTypes.isEmpty) {
        print('⚠️ Company types empty, loading defaults...');
        _companyTypes = DropdownService.getDefaultOptions('company_types');
        print('🔄 Loaded ${_companyTypes.length} default company types');
      }

      // Always perform direct Firebase fetch for departments to override static data
      try {
        final deptOptions = await DropdownService.getDropdownOptions('department');
        if (mounted && deptOptions.isNotEmpty) {
          setState(() => _departments = deptOptions);
          print('✅ Force loaded departments from Firebase directly: ${_departments.length} items');
        }
      } catch (e) {
        print('⚠️ Could not fetch explicit departments: $e');
      }

      print('🎯 Final dropdown counts:');
      print('- Qualifications: ${_qualifications.length}');
      print('- Job Categories: ${_jobCategories.length}');
      print('- Job Types: ${_jobTypes.length}');
      print('- Designations: ${_designations.length}');
      print('- Company Types: ${_companyTypes.length}');
      print('- Departments: ${_departments.length}');
    } catch (e) {
      print('❌ Error loading dropdown options: $e');
      if (mounted) {
        setState(() {
          // Use centralized local options as fallback
          _qualifications = QualificationOptions.values;
          _jobCategories = JobCategoryOptions.values;
          _jobTypes = JobTypeOptions.values;
          _designations = DesignationOptions.values;
          _companyTypes = DropdownService.getDefaultOptions('company_types');
          _departments = DropdownService.getDefaultOptions('departments');
        });
        print('🔄 Using local fallback options');
      }
    }
  }

  Future<void> _verifyCompanyName() async {
    final companyName = _companyController.text.trim();
    if (companyName.isEmpty) {
      setState(() {
        _companyVerified = false;
        _isVerifyingCompany = false;
      });
      return;
    }

    if (companyName.length < 3) {
      return;
    }

    setState(() {
      _isVerifyingCompany = true;
      _companyVerified = false;
    });

    final exists = await GoogleSearchService.verifyCompanyExists(companyName);

    if (mounted) {
      setState(() {
        _isVerifyingCompany = false;
        _companyVerified = exists;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _qualificationController.dispose();

    _departmentController.dispose(); // Keep for backward compatibility
    _jobCategoryController.dispose(); // New job category controller
    _jobTypeController.dispose(); // New job type controller
    _designationController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_selectedQualification == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select your qualification'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return false;
    }



    // Validate notice period if currently working is yes
    if (_currentlyWorking == 'yes' && _selectedNoticePeriod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select your notice period'),
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

  void _handleNext() async {
    if (!_validateForm() || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get current user email from Firebase Auth
      final currentUser = FirebaseAuth.instance.currentUser;
      final email = currentUser?.email ?? '';
      final mobileNumber = await _getMobileNumberFromStep1();

      // Use qualification directly
      String qualificationToSave = _selectedQualification!;

      await FirebaseService.updateCandidateStep2Data(
        mobileNumber: mobileNumber,
        qualification: qualificationToSave,
        experienceYears: _experienceYears,
        experienceMonths: _experienceMonths,
        jobCategory: _selectedJobCategory ?? '',
        department: _selectedDepartment ?? '',
        jobType: _selectedJobType ?? '',
        designation: _selectedDesignation ?? '',
        companyName: _companyController.text.trim(),
        companyType: _selectedCompanyType ?? '',
        email: email,
        currentlyWorking: _currentlyWorking,
        noticePeriod: _selectedNoticePeriod,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        // Navigate to Step 3
        Navigator.pushNamed(
          context,
          '/candidate_registration_step3',
          arguments: mobileNumber,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
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

  Future<String> _getMobileNumberFromStep1() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      return args;
    }
    final step1Data = await FirebaseService.getLatestCandidateData();
    return step1Data?['mobileNumber'] ?? '';
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
                        _buildProgressStep('1', false, 'Basic Info'),
                        Expanded(child: _buildProgressLine(true)),
                        _buildProgressStep('2', true, 'Details'),
                        Expanded(child: _buildProgressLine(false)),
                        _buildProgressStep('3', false, 'Review'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _buildQualificationField(),
                            const SizedBox(height: 24),
                            _buildJobCategoryField(),
                            const SizedBox(height: 24),
                            _buildDepartmentField(),
                            const SizedBox(height: 24),
                            _buildJobTypeField(),
                            const SizedBox(height: 24),
                            _buildDesignationField(),
                            const SizedBox(height: 24),
                            _buildCompanyTypeField(),
                            const SizedBox(height: 24),
                            _buildExperienceField(),
                            const SizedBox(height: 24),
                            _buildEmploymentStatusField(),
                            const SizedBox(height: 24),
                            _buildCompanyField(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
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
                            child: const Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Next',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
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

  Widget _buildProgressStep(String number, bool isActive, String label) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? primaryBlue : const Color(0xFFF3F4F6),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? primaryBlue : const Color(0xFFE5E7EB),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF9CA3AF),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? primaryBlue : const Color(0xFF9CA3AF),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(bool isCompleted) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isCompleted ? primaryBlue : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildQualificationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchableDropdown(
          value: _selectedQualification,
          items: _qualifications,
          hintText: 'Select or type qualification',
          labelText: 'Qualification *',
          prefixIcon: Icons.school_rounded,
          primaryColor: primaryBlue,
          onChanged: (value) {
            setState(() {
              _selectedQualification = value;
              _qualificationController.text = value ?? '';
            });
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please select your qualification';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildExperienceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Experience *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Years',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _experienceYears,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: primaryBlue,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: List.generate(31, (index) => index)
                        .map(
                          (year) => DropdownMenuItem(
                            value: year,
                            child: Text('$year'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _experienceYears = value ?? 0;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Months',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _experienceMonths,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: primaryBlue,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: List.generate(12, (index) => index)
                        .map(
                          (month) => DropdownMenuItem(
                            value: month,
                            child: Text('$month'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _experienceMonths = value ?? 0;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmploymentStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Currently Working? *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                title: const Text('Yes'),
                value: 'yes',
                groupValue: _currentlyWorking,
                onChanged: (value) {
                  setState(() {
                    _currentlyWorking = value;
                  });
                },
                activeColor: primaryBlue,
              ),
              RadioListTile<String>(
                title: const Text('No'),
                value: 'no',
                groupValue: _currentlyWorking,
                onChanged: (value) {
                  setState(() {
                    _currentlyWorking = value;
                    _selectedNoticePeriod =
                        null; // Clear notice period if not working
                  });
                },
                activeColor: primaryBlue,
              ),
            ],
          ),
        ),
        if (_currentlyWorking == 'yes') ...[
          const SizedBox(height: 16),
          const Text(
            'Notice Period *',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: DropdownButtonFormField<int>(
              value: _selectedNoticePeriod,
              decoration: const InputDecoration(
                labelText: 'Notice Period (days)',
                prefixIcon: Icon(Icons.schedule_rounded),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: [15, 30, 45, 60, 90]
                  .map(
                    (days) => DropdownMenuItem(
                      value: days,
                      child: Text('$days days'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedNoticePeriod = value;
                });
              },
              validator: (value) {
                if (_currentlyWorking == 'yes' && value == null) {
                  return 'Please select your notice period';
                }
                return null;
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompanyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _companyController,
          decoration: InputDecoration(
            labelText: 'Company Name *',
            hintText: 'Enter your company name',
            prefixIcon: const Icon(Icons.business_rounded),
            suffixIcon: _isVerifyingCompany
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _companyController.text.isNotEmpty
                ? Icon(
                    _companyVerified ? Icons.verified : Icons.error,
                    color: _companyVerified ? Colors.green : Colors.orange,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryBlue, width: 2),
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your company name';
            }
            return null;
          },
        ),
        if (_companyController.text.isNotEmpty && !_isVerifyingCompany) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _companyVerified ? Icons.check_circle : Icons.info,
                size: 16,
                color: _companyVerified ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _companyVerified
                      ? 'Company verified'
                      : 'Company not found in our database',
                  style: TextStyle(
                    fontSize: 12,
                    color: _companyVerified ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCompanyTypeField() {
    return SearchableDropdown(
      value: _selectedCompanyType,
      items: _companyTypes,
      hintText: 'Select or type company type',
      labelText: 'Company Type *',
      prefixIcon: Icons.corporate_fare_rounded,
      primaryColor: primaryBlue,
      onChanged: (value) {
        setState(() {
          _selectedCompanyType = value;
        });
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please select company type';
        }
        return null;
      },
    );
  }

  Widget _buildJobCategoryField() {
    return SearchableDropdown(
      value: _selectedJobCategory,
      items: _jobCategories,
      hintText: 'Select or type job category',
      labelText: 'Job Category *',
      prefixIcon: Icons.category_rounded,
      primaryColor: primaryBlue,
      onChanged: (value) {
        setState(() {
          _selectedJobCategory = value;
          _jobCategoryController.text = value ?? '';
        });
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please select your job category';
        }
        return null;
      },
    );
  }

  Widget _buildDepartmentField() {
    return SearchableDropdown(
      value: _selectedDepartment,
      items: _departments,
      hintText: 'Select or type department',
      labelText: 'Department *',
      prefixIcon: Icons.apartment_rounded,
      primaryColor: primaryBlue,
      onChanged: (value) {
        setState(() {
          _selectedDepartment = value;
          _departmentController.text = value ?? '';
        });
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please select your department';
        }
        return null;
      },
    );
  }

  Widget _buildJobTypeField() {
    return SearchableDropdown(
      value: _selectedJobType,
      items: _jobTypes,
      hintText: 'Select or type job type',
      labelText: 'Job Type *',
      prefixIcon: Icons.work_history_rounded,
      primaryColor: primaryBlue,
      onChanged: (value) {
        setState(() {
          _selectedJobType = value;
          _jobTypeController.text = value ?? '';
        });
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please select your job type';
        }
        return null;
      },
    );
  }

  Widget _buildDesignationField() {
    return SearchableDropdown(
      value: _selectedDesignation,
      items: _designations,
      hintText: 'Select or type designation',
      labelText: 'Designation *',
      prefixIcon: Icons.work_outline_rounded,
      primaryColor: primaryBlue,
      onChanged: (value) {
        setState(() {
          _selectedDesignation = value;
          _designationController.text = value ?? '';
        });
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please select your designation';
        }
        return null;
      },
    );
  }
}
