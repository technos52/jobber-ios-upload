import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/dropdown_service.dart';
import 'job_applications_screen.dart';
import 'company_profile_screen.dart';
import 'employer_profile_overview_screen.dart';

class EmployerDashboardScreen extends StatefulWidget {
  const EmployerDashboardScreen({super.key});

  @override
  State<EmployerDashboardScreen> createState() =>
      _EmployerDashboardScreenState();
}

class _EmployerDashboardScreenState extends State<EmployerDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const primaryBlue = Color(0xFF007BFF);
  String _companyName = 'Company';
  String _approvalStatus = 'pending';
  int _currentBottomNavIndex = 0;
  late PageController _pageController;
  int _currentJobPageIndex = 0;
  bool _isNavigating = false;

  // Cache for applicant counts to enable instant updates
  final Map<String, int> _applicantCounts = {};
  bool _isRefreshingCounts = false;

  // Form controllers
  late final TextEditingController _jobTitleController;
  late final TextEditingController _jobDescriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _salaryRangeController;
  late final TextEditingController _experienceController;
  final _formKey = GlobalKey<FormState>();

  // Dropdown values
  final ValueNotifier<String?> _selectedDepartment = ValueNotifier(null);
  final ValueNotifier<String?> _selectedIndustryType = ValueNotifier(null);
  final ValueNotifier<String?> _selectedJobCategory = ValueNotifier(null);
  final ValueNotifier<String?> _selectedJobType = ValueNotifier(null);
  final ValueNotifier<String?> _selectedWorkMode = ValueNotifier(null);
  final ValueNotifier<String?> _selectedQualification = ValueNotifier(null);

  // Dropdown options from Firebase
  List<String> _departments = [];
  List<String> _industryTypes = [];
  List<String> _jobCategories = [];
  List<String> _jobTypes = [];
  List<String> _workModes = [];
  List<String> _qualifications = [];

  bool _isLoadingDropdowns = false;
  bool _isPostingJob = false;
  bool _isEditMode = false;
  String? _editingJobId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _jobTitleController = TextEditingController();
    _jobDescriptionController = TextEditingController();
    _locationController = TextEditingController();
    _salaryRangeController = TextEditingController();
    _experienceController = TextEditingController();
    _loadEmployerData();
    _loadDropdownOptions();
    _listenToApprovalStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentJobPageIndex = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _jobTitleController.dispose();
    _jobDescriptionController.dispose();
    _locationController.dispose();
    _salaryRangeController.dispose();
    _experienceController.dispose();
    _selectedDepartment.dispose();
    _selectedIndustryType.dispose();
    _selectedJobCategory.dispose();
    _selectedJobType.dispose();
    _selectedWorkMode.dispose();
    super.dispose();
  }

  Future<void> _loadEmployerData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final employerDoc = await FirebaseFirestore.instance
            .collection('employers')
            .doc(user.uid)
            .get();

        if (employerDoc.exists) {
          final employerData = employerDoc.data()!;
          final approvalStatus = employerData['approvalStatus'] ?? 'pending';
          final companyName = employerData['companyName'] ?? 'Company';

          if (mounted) {
            setState(() {
              _companyName = companyName;
              _approvalStatus = approvalStatus;
            });

            if (approvalStatus.toLowerCase() != 'approved') {
              debugPrint(
                'Company not approved ($approvalStatus), redirecting to verification',
              );
              Navigator.of(
                context,
              ).pushReplacementNamed('/employer_verification');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading employer data: $e');
    }
  }

  void _listenToApprovalStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('employers')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists && mounted) {
              final data = snapshot.data() as Map<String, dynamic>?;
              final approvalStatus = data?['approvalStatus'] ?? 'pending';

              setState(() {
                _approvalStatus = approvalStatus;
              });

              if (approvalStatus.toLowerCase() != 'approved') {
                debugPrint(
                  'Approval status changed to $approvalStatus, redirecting to verification',
                );
                Navigator.of(context).pushReplacementNamed('/auth');
              }
            }
          });
    }
  }

  Future<void> _loadDropdownOptions() async {
    setState(() {
      _isLoadingDropdowns = true;
    });

    try {
      final results = await Future.wait([
        DropdownService.getDropdownOptions('departments'),
        DropdownService.getDropdownOptions('industry_types'),
        DropdownService.getDropdownOptions('job_categories'),
        DropdownService.getDropdownOptions('job_types'),
        DropdownService.getDropdownOptions('work_modes'),
        DropdownService.getDropdownOptions('qualifications'),
      ]);

      if (mounted) {
        setState(() {
          _departments = results[0];
          _industryTypes = results[1];
          _jobCategories = results[2];
          _jobTypes = results[3];
          _workModes = results[4];
          _qualifications = results[5];
        });

        debugPrint('✅ Loaded dropdown options from Firebase');
      }
    } catch (e) {
      debugPrint('Error loading dropdown options: $e');

      if (mounted) {
        setState(() {
          _departments = DropdownService.getDefaultOptions('departments');
          _industryTypes = DropdownService.getDefaultOptions('industry_types');
          _jobCategories = DropdownService.getDefaultOptions('job_categories');
          _jobTypes = DropdownService.getDefaultOptions('job_types');
          _workModes = DropdownService.getDefaultOptions('work_modes');
          _qualifications = DropdownService.getDefaultOptions('qualifications');
        });
        debugPrint('⚠️ Using fallback dropdown options');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDropdowns = false;
        });
      }
    }
  }

  Future<void> _handlePostJob() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedJobCategory.value == null) {
      _showSnackBar('Please select a job category', Colors.red);
      return;
    }
    if (_selectedJobType.value == null) {
      _showSnackBar('Please select a job type', Colors.red);
      return;
    }
    if (_selectedDepartment.value == null) {
      _showSnackBar('Please select a department', Colors.red);
      return;
    }
    if (_experienceController.text.trim().isEmpty) {
      _showSnackBar('Please enter experience required', Colors.red);
      return;
    }
    if (_selectedQualification.value == null) {
      _showSnackBar('Please select required qualification', Colors.red);
      return;
    }
    if (_salaryRangeController.text.trim().isEmpty) {
      _showSnackBar('Please enter salary range', Colors.red);
      return;
    }
    if (_selectedWorkMode.value == null) {
      _showSnackBar('Please select work mode', Colors.red);
      return;
    }

    setState(() {
      _isPostingJob = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final jobData = <String, dynamic>{
        'companyName': _companyName,
        'employerId': user.uid,
        'jobTitle': _jobTitleController.text.trim(),
        'jobDescription': _jobDescriptionController.text.trim(),
        'department': _selectedDepartment.value,
        'location': _locationController.text.trim(),
        'experienceRequired': _experienceController.text.trim(),
        'qualification': _selectedQualification.value,
        'jobCategory': _selectedJobCategory.value,
        'industryType': _selectedIndustryType.value,
        'jobType': _selectedJobType.value,
        'salaryRange': _salaryRangeController.text.trim(),
        'workMode': _selectedWorkMode.value,
      };

      if (_isEditMode && _editingJobId != null) {
        jobData['updatedDate'] = FieldValue.serverTimestamp();
        jobData['approvalStatus'] = 'pending';

        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(_editingJobId!)
            .update(jobData);

        if (mounted) {
          _clearForm();
          _showSnackBar(
            'Job updated successfully! Awaiting admin approval.',
            Colors.green,
          );
        }
      } else {
        jobData['postedDate'] = FieldValue.serverTimestamp();
        jobData['approvalStatus'] = 'pending';
        jobData['applications'] = 0;

        await FirebaseFirestore.instance.collection('jobs').add(jobData);

        if (mounted) {
          _clearForm();
          _showSnackBar(
            'Job posted successfully! Awaiting admin approval.',
            Colors.green,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Error ${_isEditMode ? 'updating' : 'posting'} job: $e',
          Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPostingJob = false;
        });
      }
    }
  }

  void _clearForm() {
    _jobTitleController.clear();
    _jobDescriptionController.clear();
    _locationController.clear();
    _salaryRangeController.clear();
    _experienceController.clear();
    _selectedDepartment.value = null;
    _selectedIndustryType.value = null;
    _selectedJobCategory.value = null;
    _selectedJobType.value = null;
    _selectedQualification.value = null;
    _selectedWorkMode.value = null;

    final wasEditMode = _isEditMode;

    setState(() {
      _isEditMode = false;
      _editingJobId = null;
      _currentJobPageIndex = 0;
    });

    if (_pageController.hasClients && mounted) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    // Only show "Edit canceled" if we were actually in edit mode
    if (wasEditMode) {
      _showSnackBar('Edit canceled', Colors.grey);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  bool _canPostJobs() {
    return _approvalStatus.toLowerCase() == 'approved';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isEditMode,
      onPopInvokedWithResult: (didPop, result) {
        if (_isEditMode && !didPop) {
          _clearForm();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Builder(
              builder: (context) {
                debugPrint(
                  '🔍 Building employer main content for index: $_currentBottomNavIndex',
                );

                if (_currentBottomNavIndex == 0) {
                  debugPrint('🏠 Showing jobs page');
                  return _buildJobsPage();
                } else {
                  debugPrint(
                    '👤 Showing profile overview page (not edit screen)',
                  );
                  return _buildProfilePage();
                }
              },
            ),
            Positioned(
              left: 40,
              right: 40,
              bottom: 20,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withValues(alpha: 0.1),
                      blurRadius: 30,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBottomNavItem(
                      icon: Icons.work_rounded,
                      label: 'Jobs',
                      index: 0,
                    ),
                    _buildBottomNavItem(
                      icon: Icons.person_rounded,
                      label: 'Profile',
                      index: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentBottomNavIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentBottomNavIndex = index;
            if (index == 0) {
              _currentJobPageIndex = 0;
            }
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 26,
                color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobsPage() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [primaryBlue, Color(0xFF0056CC)]),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All Job Open',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome\n$_companyName',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        Container(
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildJobTabButton(
                  _isEditMode ? 'Edit Job' : 'Post Job',
                  Icons.add_circle_outline,
                  0,
                ),
              ),
              Expanded(
                child: _buildJobTabButton('Manage Jobs', Icons.list_alt, 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentJobPageIndex = index;
              });

              // Refresh applicant counts when switching to Manage Jobs tab
              if (index == 1) {
                _refreshApplicantCounts();
              }
            },
            children: [_buildPostJobScreen(), _buildManageJobsScreen()],
          ),
        ),
      ],
    );
  }

  Widget _buildJobTabButton(String title, IconData icon, int index) {
    final isSelected = _currentJobPageIndex == index;

    return InkWell(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        // Refresh applicant counts when clicking Manage Jobs tab
        if (index == 1) {
          _refreshApplicantCounts();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? primaryBlue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryBlue : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? primaryBlue : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostJobScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditMode ? 'Edit Job' : 'Post New Job',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          if (!_canPostJobs())
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Company Under Review',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your company is currently being verified. You can prepare job postings, but posting will be enabled once approved.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ],
              ),
            ),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingDropdowns)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  _buildFormField(
                    'Job Title',
                    'Enter job title',
                    controller: _jobTitleController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter job title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    'Job Description',
                    'Enter job description',
                    maxLines: 4,
                    controller: _jobDescriptionController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter job description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    'Job Category',
                    _selectedJobCategory,
                    _jobCategories,
                    'Select job category',
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    'Job Type',
                    _selectedJobType,
                    _jobTypes,
                    'Select job type',
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    'Department',
                    _selectedDepartment,
                    _departments,
                    'Select department',
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    'Experience Required',
                    'Enter experience required (e.g., 2-5 years)',
                    controller: _experienceController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter experience required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    'Required Qualification',
                    _selectedQualification,
                    _qualifications,
                    'Select required qualification',
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    'Location',
                    'Enter job location',
                    controller: _locationController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter location';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    'Salary Range',
                    'e.g., ₹5-8 LPA, ₹50,000-80,000 per month',
                    controller: _salaryRangeController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter salary range';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    'Work Mode',
                    _selectedWorkMode,
                    _workModes,
                    'Select work mode',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isPostingJob || !_canPostJobs())
                          ? null
                          : _handlePostJob,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canPostJobs()
                            ? primaryBlue
                            : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isPostingJob
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
                          : Text(
                              _isEditMode ? 'Update Job' : 'Post Job',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(
    String label,
    String hint, {
    TextEditingController? controller,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: primaryBlue, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    ValueNotifier<String?> selectedValue,
    List<String> options,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<String?>(
          valueListenable: selectedValue,
          builder: (context, value, child) {
            return DropdownButtonFormField<String>(
              value: value,
              hint: Text(hint),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryBlue, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
              ),
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: (String? newValue) {
                selectedValue.value = newValue;
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select $label';
                }
                return null;
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildManageJobsScreen() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('jobs')
                .where(
                  'employerId',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                )
                .snapshots(),
            builder: (context, snapshot) {
              final jobCount = snapshot.data?.docs.length ?? 0;

              return Row(
                children: [
                  const Icon(Icons.list_alt, color: primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Posted Jobs ($jobCount)',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('jobs')
                .where(
                  'employerId',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                )
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                debugPrint('❌ Jobs query error: ${snapshot.error}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to load jobs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please check your internet connection',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {}); // Trigger rebuild
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final jobs = snapshot.data?.docs ?? [];

              // Sort jobs by postedDate in memory since we can't use orderBy with where clause
              jobs.sort((a, b) {
                final aDate =
                    (a.data() as Map<String, dynamic>)['postedDate']
                        as Timestamp?;
                final bDate =
                    (b.data() as Map<String, dynamic>)['postedDate']
                        as Timestamp?;

                if (aDate == null && bDate == null) return 0;
                if (aDate == null) return 1;
                if (bDate == null) return -1;

                return bDate.compareTo(aDate); // Descending order
              });

              if (jobs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.work_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No jobs posted yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  final jobData = job.data() as Map<String, dynamic>;
                  return _buildJobCard(job.id, jobData);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJobCard(String jobId, Map<String, dynamic> jobData) {
    final approvalStatus = jobData['approvalStatus'] ?? 'pending';
    final applications = jobData['applications'] ?? 0;
    final jobTitle = jobData['jobTitle'] ?? 'No Title';
    final companyName = jobData['companyName'] ?? _companyName;
    final location = jobData['location'] ?? 'No Location';
    final jobType = jobData['jobType'] ?? 'Contract';
    final department = jobData['department'] ?? '';
    final experienceLevel = jobData['experienceLevel'] ?? '';
    final salaryRange = jobData['salaryRange'] ?? '';
    final postedDate = jobData['postedDate'] as Timestamp?;

    // Format posted date
    String timeAgo = 'Just now';
    if (postedDate != null) {
      final now = DateTime.now();
      final postDate = postedDate.toDate();
      final difference = now.difference(postDate);

      if (difference.inDays > 0) {
        timeAgo =
            '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        timeAgo =
            '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        timeAgo =
            '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jobTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          companyName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(approvalStatus),
                ],
              ),

              const SizedBox(height: 16),

              // Job details in a more organized layout
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // Location and job type row
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 18, color: primaryBlue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            location,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF374151),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.work, size: 18, color: primaryBlue),
                        const SizedBox(width: 6),
                        Text(
                          jobType,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    if (department.isNotEmpty ||
                        experienceLevel.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (department.isNotEmpty) ...[
                            Icon(Icons.business, size: 18, color: primaryBlue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                department,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF374151),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          if (experienceLevel.isNotEmpty) ...[
                            const SizedBox(width: 16),
                            Icon(
                              Icons.trending_up,
                              size: 18,
                              color: primaryBlue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              experienceLevel,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],

                    // 2x2 layout for salary and time
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Left column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (salaryRange.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Text(
                                      '₹',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: primaryBlue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        salaryRange,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF374151),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Right column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 16,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeAgo,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Column(
                children: [
                  // Show different buttons based on approval status
                  if (approvalStatus.toLowerCase() == 'approved') ...[
                    // Applicants button for approved jobs with count
                    StreamBuilder<int>(
                      stream: _getApplicantCount(jobId),
                      initialData:
                          _applicantCounts[jobId], // Use cached value as initial data
                      builder: (context, snapshot) {
                        // Use cached value if available, otherwise use snapshot data
                        final applicantCount =
                            snapshot.data ?? _applicantCounts[jobId] ?? 0;

                        return Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: primaryBlue, width: 2),
                          ),
                          child: ElevatedButton(
                            onPressed: () =>
                                _viewJobApplications(jobId, jobData),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: primaryBlue,
                              shadowColor: Colors.transparent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people,
                                  size: 20,
                                  color: primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'View Applicants',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: primaryBlue,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$applicantCount',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ] else if (approvalStatus.toLowerCase() == 'rejected') ...[
                    // Rejected status button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: OutlinedButton.icon(
                        onPressed: null, // Disabled for rejected
                        icon: Icon(
                          Icons.cancel,
                          size: 20,
                          color: Colors.red.shade600,
                        ),
                        label: Text(
                          'Job Rejected',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Under Review button for pending jobs
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: OutlinedButton.icon(
                        onPressed: null, // Disabled for under review
                        icon: Icon(
                          Icons.schedule,
                          size: 20,
                          color: Colors.orange.shade600,
                        ),
                        label: Text(
                          'Under Review',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Delete Job button (always available)
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: OutlinedButton.icon(
                      onPressed: () => _handleDeleteJob(jobId, jobTitle),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Delete Job',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color backgroundColor;
    String text;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green.shade700;
        backgroundColor = Colors.green.shade100;
        text = 'Approved';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red.shade700;
        backgroundColor = Colors.red.shade100;
        text = 'Rejected';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange.shade700;
        backgroundColor = Colors.orange.shade100;
        text = 'Under Review';
        icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Method to refresh applicant counts cache
  Future<void> _refreshApplicantCounts() async {
    if (_isRefreshingCounts) return;

    setState(() {
      _isRefreshingCounts = true;
    });

    try {
      debugPrint('⏰ Background check: Refreshing applicant counts');

      // Get all jobs for this employer
      final jobsSnapshot = await FirebaseFirestore.instance
          .collection('jobs')
          .where(
            'employerId',
            isEqualTo: FirebaseAuth.instance.currentUser?.uid,
          )
          .get();

      // Clear existing counts
      _applicantCounts.clear();

      // Count applicants for each job
      for (final jobDoc in jobsSnapshot.docs) {
        final jobId = jobDoc.id;
        int totalCount = 0;

        try {
          // Get all candidates
          final candidatesSnapshot = await FirebaseFirestore.instance
              .collection('candidates')
              .get();

          // Check each candidate's applications subcollection
          for (final candidateDoc in candidatesSnapshot.docs) {
            try {
              final applicationsQuery = await FirebaseFirestore.instance
                  .collection('candidates')
                  .doc(candidateDoc.id)
                  .collection('applications')
                  .where('jobId', isEqualTo: jobId)
                  .get();

              totalCount += applicationsQuery.docs.length;
            } catch (e) {
              debugPrint('Error checking candidate ${candidateDoc.id}: $e');
              // Continue with other candidates
            }
          }

          _applicantCounts[jobId] = totalCount;
        } catch (e) {
          debugPrint('Error counting applicants for job $jobId: $e');
          _applicantCounts[jobId] = 0;
        }
      }

      // Refresh applicant counts after posting
      await _refreshApplicantCounts();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error refreshing applicant counts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingCounts = false;
        });
      }
    }
  }

  // Method to count applicants for a job with caching to prevent resets during scrolling
  Stream<int> _getApplicantCount(String jobId) async* {
    debugPrint('🔍 Getting applicant count for job: $jobId');

    // First, yield cached count immediately if available
    if (_applicantCounts.containsKey(jobId)) {
      yield _applicantCounts[jobId]!;
      debugPrint(
        '📊 Yielded cached count for job $jobId: ${_applicantCounts[jobId]}',
      );
    }

    // Then get fresh count and update cache
    try {
      final freshCount = await _getApplicantCountOnce(jobId);

      // Only update and yield if count changed or no cache exists
      if (!_applicantCounts.containsKey(jobId) ||
          _applicantCounts[jobId] != freshCount) {
        _applicantCounts[jobId] = freshCount;
        yield freshCount;
        debugPrint('📈 Updated count for job $jobId: $freshCount');
      }
    } catch (e) {
      debugPrint('❌ Error getting fresh count for job $jobId: $e');
      // If we have cached count, keep using it
      if (_applicantCounts.containsKey(jobId)) {
        yield _applicantCounts[jobId]!;
      } else {
        yield 0;
      }
    }

    // Set up periodic refresh (every 30 seconds) to keep counts updated
    await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
      try {
        final newCount = await _getApplicantCountOnce(jobId);
        if (_applicantCounts[jobId] != newCount) {
          _applicantCounts[jobId] = newCount;
          yield newCount;
          debugPrint('🔄 Periodic update for job $jobId: $newCount');
        }
      } catch (e) {
        debugPrint('❌ Error in periodic update for job $jobId: $e');
        // Keep existing cached value
      }
    }
  }

  // Helper method to get applicant count once using optimized collection group query
  Future<int> _getApplicantCountOnce(String jobId) async {
    try {
      debugPrint('📊 Getting count for job: $jobId');

      // Use collection group query for better performance
      final applicationsQuery = await FirebaseFirestore.instance
          .collectionGroup('applications')
          .where('jobId', isEqualTo: jobId)
          .get(const GetOptions(source: Source.server));

      final count = applicationsQuery.docs.length;
      debugPrint('✅ Collection group count for job $jobId: $count');
      return count;
    } catch (e) {
      debugPrint('❌ Collection group query failed for job $jobId: $e');

      // Fallback to individual candidate queries if collection group fails
      try {
        debugPrint('🔄 Falling back to individual candidate queries...');

        final candidatesSnapshot = await FirebaseFirestore.instance
            .collection('candidates')
            .get(const GetOptions(source: Source.server));

        int totalCount = 0;

        for (final candidateDoc in candidatesSnapshot.docs) {
          try {
            final applicationsQuery = await FirebaseFirestore.instance
                .collection('candidates')
                .doc(candidateDoc.id)
                .collection('applications')
                .where('jobId', isEqualTo: jobId)
                .get(const GetOptions(source: Source.server));

            totalCount += applicationsQuery.docs.length;
          } catch (candidateError) {
            debugPrint(
              '❌ Error checking candidate ${candidateDoc.id}: $candidateError',
            );
            // Continue with other candidates
          }
        }

        debugPrint('📈 Fallback count for job $jobId: $totalCount');
        return totalCount;
      } catch (fallbackError) {
        debugPrint('❌ Fallback also failed for job $jobId: $fallbackError');
        return 0;
      }
    }
  }

  Widget _buildProfilePage() {
    debugPrint('🔍 Building employer profile overview page');
    return const EmployerProfileOverviewScreen();
  }

  Future<void> _handleEditJob(
    String jobId,
    Map<String, dynamic> jobData,
  ) async {
    if (!mounted) return;

    try {
      setState(() {
        _isEditMode = true;
        _editingJobId = jobId;
      });

      _jobTitleController.text = jobData['jobTitle'] ?? '';
      _jobDescriptionController.text = jobData['jobDescription'] ?? '';
      _locationController.text = jobData['location'] ?? '';
      _experienceController.text = jobData['experienceRequired'] ?? '';

      final jobCategory = jobData['jobCategory'];
      if (jobCategory != null && _jobCategories.contains(jobCategory)) {
        _selectedJobCategory.value = jobCategory;
      } else {
        _selectedJobCategory.value = null;
      }

      final jobType = jobData['jobType'];
      if (jobType != null && _jobTypes.contains(jobType)) {
        _selectedJobType.value = jobType;
      } else {
        _selectedJobType.value = null;
      }

      final department = jobData['department'];
      if (department != null && _departments.contains(department)) {
        _selectedDepartment.value = department;
      } else {
        _selectedDepartment.value = null;
      }

      final qualification = jobData['qualification'];
      if (qualification != null && _qualifications.contains(qualification)) {
        _selectedQualification.value = qualification;
      } else {
        _selectedQualification.value = null;
      }

      final salaryRange = jobData['salaryRange'];
      if (salaryRange != null) {
        _salaryRangeController.text = salaryRange;
      } else {
        _salaryRangeController.clear();
      }

      final workMode = jobData['workMode'];
      if (workMode != null && _workModes.contains(workMode)) {
        _selectedWorkMode.value = workMode;
      } else {
        _selectedWorkMode.value = null;
      }

      if (_pageController.hasClients && mounted) {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        setState(() {
          _currentJobPageIndex = 0;
        });
      }

      if (mounted) {
        _showSnackBar('Editing job: ${jobData['jobTitle']}', Colors.blue);
      }
    } catch (e) {
      debugPrint('Error in _handleEditJob: $e');
      if (mounted) {
        _showSnackBar('Error entering edit mode: $e', Colors.red);
      }
    }
  }

  Future<void> _handleDeleteJob(String jobId, String jobTitle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: Text(
          'Are you sure you want to delete "$jobTitle"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('jobs').doc(jobId).delete();

        if (mounted) {
          _showSnackBar('Job deleted successfully', Colors.green);
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error deleting job: $e', Colors.red);
        }
      }
    }
  }

  Future<void> _viewJobApplications(
    String jobId,
    Map<String, dynamic> jobData,
  ) async {
    if (!mounted || _isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => JobApplicationsScreen(
            jobId: jobId,
            jobTitle: jobData['jobTitle'] ?? 'Job Applications',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Navigation error: $e');
      if (mounted) {
        _showSnackBar('Error opening applications: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }
}
