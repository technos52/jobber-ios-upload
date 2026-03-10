import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/dropdown_service.dart';

class CandidateRegistrationStep3Screen extends StatefulWidget {
  const CandidateRegistrationStep3Screen({super.key});

  @override
  State<CandidateRegistrationStep3Screen> createState() =>
      _CandidateRegistrationStep3ScreenState();
}

class _CandidateRegistrationStep3ScreenState
    extends State<CandidateRegistrationStep3Screen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Text controllers for autocomplete fields
  final _stateController = TextEditingController();
  final _districtController = TextEditingController();

  // Simple dropdown values using ValueNotifier to prevent rebuilds
  final ValueNotifier<String?> _selectedMaritalStatus = ValueNotifier(null);
  final ValueNotifier<bool> _currentlyWorking = ValueNotifier(false);
  final ValueNotifier<int?> _selectedNoticePeriod = ValueNotifier(null);

  // Autocomplete state - only rebuild when necessary
  List<String> _filteredStates = [];
  List<String> _filteredDistricts = [];
  bool _showStateDropdown = false;
  bool _showDistrictDropdown = false;

  // Dynamic dropdown options from Firebase
  bool _isSubmitting = false;

  static const primaryBlue = Color(0xFF007BFF);

  static const List<String> _maritalStatuses = [
    'Unmarried',
    'Married',
    'Divorced',
    'Widowed',
  ];

  static const Map<String, List<String>> _indiaStatesDistricts = {
    'Andhra Pradesh': [
      'Visakhapatnam',
      'Vijayawada',
      'Guntur',
      'Nellore',
      'Tirupati',
    ],
    'Maharashtra': [
      'Mumbai',
      'Pune',
      'Nagpur',
      'Thane',
      'Nashik',
      'Aurangabad',
    ],
    'Karnataka': ['Bangalore', 'Mysore', 'Hubli', 'Mangalore', 'Belgaum'],
    'Tamil Nadu': [
      'Chennai',
      'Coimbatore',
      'Madurai',
      'Tiruchirappalli',
      'Salem',
    ],
    'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar'],
    'Rajasthan': ['Jaipur', 'Jodhpur', 'Kota', 'Bikaner', 'Udaipur'],
    'West Bengal': ['Kolkata', 'Howrah', 'Durgapur', 'Asansol', 'Siliguri'],
    'Madhya Pradesh': ['Indore', 'Bhopal', 'Jabalpur', 'Gwalior', 'Ujjain'],
    'Uttar Pradesh': [
      'Lucknow',
      'Kanpur',
      'Ghaziabad',
      'Agra',
      'Varanasi',
      'Noida',
    ],
    'Delhi': [
      'Central Delhi',
      'North Delhi',
      'South Delhi',
      'East Delhi',
      'West Delhi',
    ],
    'Punjab': ['Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda'],
    'Haryana': ['Gurgaon', 'Faridabad', 'Panipat', 'Ambala', 'Karnal'],
    'Bihar': ['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Purnia'],
    'Telangana': [
      'Hyderabad',
      'Warangal',
      'Nizamabad',
      'Karimnagar',
      'Khammam',
    ],
    'Kerala': [
      'Thiruvananthapuram',
      'Kochi',
      'Kozhikode',
      'Thrissur',
      'Kollam',
    ],
  };

  static const List<int> _noticePeriods = [7, 15, 30, 45, 60, 90, 180];

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

    // Add listeners for autocomplete - debounced to prevent excessive rebuilds
    _stateController.addListener(_onStateChanged);
    _districtController.addListener(_onDistrictChanged);

    // Load dropdown options from Firebase
    _loadDropdownOptions();
  }

  // Debounced text change handlers to prevent excessive rebuilds
  void _onStateChanged() {
    final query = _stateController.text.toLowerCase();
    if (query.isEmpty) {
      if (_showStateDropdown) {
        setState(() {
          _filteredStates = [];
          _showStateDropdown = false;
        });
      }
    } else {
      final filtered = _indiaStatesDistricts.keys
          .where((state) => state.toLowerCase().contains(query))
          .toList();

      if (filtered.length != _filteredStates.length || !_showStateDropdown) {
        setState(() {
          _filteredStates = filtered;
          _showStateDropdown = filtered.isNotEmpty;
        });
      }
    }
  }

  void _onDistrictChanged() {
    final query = _districtController.text.toLowerCase();
    final selectedState = _stateController.text.trim();

    if (query.isEmpty || !_indiaStatesDistricts.containsKey(selectedState)) {
      if (_showDistrictDropdown) {
        setState(() {
          _filteredDistricts = [];
          _showDistrictDropdown = false;
        });
      }
    } else {
      final filtered = _indiaStatesDistricts[selectedState]!
          .where((district) => district.toLowerCase().contains(query))
          .toList();

      if (filtered.length != _filteredDistricts.length ||
          !_showDistrictDropdown) {
        setState(() {
          _filteredDistricts = filtered;
          _showDistrictDropdown = filtered.isNotEmpty;
        });
      }
    }
  }

  /// Load dropdown options from Firebase - always fetch fresh data
  Future<void> _loadDropdownOptions() async {
    // Company types are no longer needed in step 3
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _stateController.dispose();
    _districtController.dispose();

    // Dispose ValueNotifiers
    _selectedMaritalStatus.dispose();
    _currentlyWorking.dispose();
    _selectedNoticePeriod.dispose();

    super.dispose();
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_selectedMaritalStatus.value == null) {
      _showErrorSnackBar('Please select marital status');
      return false;
    }

    if (_stateController.text.trim().isEmpty) {
      _showErrorSnackBar('Please select state');
      return false;
    }

    if (_districtController.text.trim().isEmpty) {
      _showErrorSnackBar('Please select district');
      return false;
    }

    return true;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _handleFinish() async {
    if (!_validateForm() || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final mobileNumber = await _getMobileNumberFromStep1();

      await FirebaseService.updateCandidateStep3Data(
        mobileNumber: mobileNumber,
        maritalStatus: _selectedMaritalStatus.value!,
        state: _stateController.text.trim(),
        district: _districtController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Registration completed successfully!'),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/candidate_dashboard', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _showErrorSnackBar('Error submitting data: $e');
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
      ),
      body: GestureDetector(
        onTap: () {
          // Close dropdowns when tapping outside
          FocusScope.of(context).unfocus();
          setState(() {
            _showStateDropdown = false;
            _showDistrictDropdown = false;
            _filteredStates = [];
            _filteredDistricts = [];
          });
        },
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primaryBlue.withValues(alpha: 0.02),
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
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildProgressStep('1', false, 'Basic Info'),
                          Expanded(child: _buildProgressLine(true)),
                          _buildProgressStep('2', false, 'Details'),
                          Expanded(child: _buildProgressLine(true)),
                          _buildProgressStep('3', true, 'Review'),
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
                              _buildMaritalStatusField(),
                              const SizedBox(height: 24),
                              _buildLocationFields(),
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
                            color: Colors.black.withValues(alpha: 0.05),
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
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [primaryBlue, Color(0xFF0056CC)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryBlue.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _handleFinish,
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
                                child: _isSubmitting
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
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Submit',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.check_circle_outline_rounded,
                                            size: 18,
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
      ), // Close GestureDetector
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
                      color: primaryBlue.withValues(alpha: 0.3),
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

  Widget _buildMaritalStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.family_restroom_outlined, size: 20, color: primaryBlue),
            const SizedBox(width: 8),
            const Text(
              'Marital Status',
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
        ValueListenableBuilder<String?>(
          valueListenable: _selectedMaritalStatus,
          builder: (context, selectedValue, child) {
            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: selectedValue != null
                      ? primaryBlue
                      : const Color(0xFFE5E7EB),
                  width: selectedValue != null ? 2 : 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: ButtonTheme(
                alignedDropdown: true,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedValue,
                    hint: const Text(
                      'Select marital status',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
                    ),
                    isExpanded: true,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF6B7280),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F2937),
                    ),
                    dropdownColor: Colors.white,
                    items: _maritalStatuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (value) {
                      _selectedMaritalStatus.value = value;
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLocationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 20, color: primaryBlue),
            const SizedBox(width: 8),
            const Text(
              'Location',
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
        // State field with autocomplete
        _buildAutocompleteField(
          controller: _stateController,
          hintText: 'Select state',
          filteredOptions: _filteredStates,
          showDropdown: _showStateDropdown,
          onOptionSelected: (option) {
            _stateController.text = option;
            _districtController.clear(); // Clear district when state changes

            // Immediately hide all dropdowns
            setState(() {
              _showStateDropdown = false;
              _showDistrictDropdown = false;
              _filteredStates = [];
              _filteredDistricts = [];
            });
          },
        ),
        const SizedBox(height: 16),
        // District field with autocomplete
        _buildAutocompleteField(
          controller: _districtController,
          hintText: 'Select district',
          filteredOptions: _filteredDistricts,
          showDropdown: _showDistrictDropdown,
          onOptionSelected: (option) {
            _districtController.text = option;

            // Immediately hide all dropdowns
            setState(() {
              _showDistrictDropdown = false;
              _showStateDropdown = false;
              _filteredDistricts = [];
              _filteredStates = [];
            });
          },
        ),
      ],
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String hintText,
    required List<String> filteredOptions,
    required bool showDropdown,
    required Function(String) onOptionSelected,
  }) {
    return Column(
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
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
              borderSide: const BorderSide(color: primaryBlue, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            suffixIcon: Icon(Icons.arrow_drop_down, color: primaryBlue),
          ),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
          onTap: () {
            // Show dropdown when field is tapped
            if (!showDropdown && controller.text.isEmpty) {
              setState(() {
                if (controller == _stateController) {
                  _filteredStates = _indiaStatesDistricts.keys.toList();
                  _showStateDropdown = true;
                  _showDistrictDropdown = false; // Close other dropdown
                } else if (controller == _districtController) {
                  final selectedState = _stateController.text.trim();
                  if (_indiaStatesDistricts.containsKey(selectedState)) {
                    _filteredDistricts = _indiaStatesDistricts[selectedState]!;
                    _showDistrictDropdown = true;
                    _showStateDropdown = false; // Close other dropdown
                  }
                }
              });
            }
          },
        ),
        if (showDropdown)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryBlue.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredOptions.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    // Immediately hide dropdown and update controller
                    onOptionSelected(filteredOptions[index]);

                    // Force focus removal to prevent dropdown from reopening
                    FocusScope.of(context).unfocus();

                    // Additional state update to ensure dropdown is hidden
                    Future.delayed(const Duration(milliseconds: 50), () {
                      if (mounted) {
                        setState(() {
                          _showStateDropdown = false;
                          _showDistrictDropdown = false;
                        });
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      filteredOptions[index],
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNoticePeriodField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule_outlined, size: 20, color: primaryBlue),
            const SizedBox(width: 8),
            const Text(
              'Notice Period (Days)',
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
        ValueListenableBuilder<int?>(
          valueListenable: _selectedNoticePeriod,
          builder: (context, selectedValue, child) {
            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: selectedValue != null
                      ? primaryBlue
                      : const Color(0xFFE5E7EB),
                  width: selectedValue != null ? 2 : 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: ButtonTheme(
                alignedDropdown: true,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedValue,
                    hint: const Text(
                      'Select notice period',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
                    ),
                    isExpanded: true,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF6B7280),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F2937),
                    ),
                    dropdownColor: Colors.white,
                    items: _noticePeriods.map((days) {
                      return DropdownMenuItem(
                        value: days,
                        child: Text('$days days'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      _selectedNoticePeriod.value = value;
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
