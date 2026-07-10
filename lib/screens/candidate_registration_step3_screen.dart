import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/dropdown_service.dart';
import '../data/locations_data.dart';

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

  final _stateController = TextEditingController();
  final _districtController = TextEditingController();

  String? _selectedMaritalStatus;
  int? _selectedAnnualIncomeLakh;
  int? _selectedAnnualIncomeThousand;
  bool _currentlyWorking = false;
  int? _selectedNoticePeriod;
  bool _isSubmitting = false;

  // State and district dropdown variables
  bool _showStateDropdown = false;
  bool _showDistrictDropdown = false;
  List<String> _filteredStates = [];
  List<String> _filteredDistricts = [];

  static const primaryBlue = Color(0xFF007BFF);

  static const List<String> _maritalStatuses = [
    'Unmarried',
    'Married',
    'Divorced',
    'Widowed',
  ];



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

    // Add listeners for state and district autocomplete
    _stateController.addListener(_onStateChanged);
    _districtController.addListener(_onDistrictChanged);
  }

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
      final filtered = districtsByState.keys
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

    if (query.isEmpty || selectedState.isEmpty) {
      if (_showDistrictDropdown) {
        setState(() {
          _filteredDistricts = [];
          _showDistrictDropdown = false;
        });
      }
    } else {
      final stateDistricts = districtsByState[selectedState] ?? [];
      final filtered = stateDistricts
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

  @override
  void dispose() {
    _fadeController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_selectedAnnualIncomeLakh == null || _selectedAnnualIncomeThousand == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select annual income'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return false;
    }

    if (_selectedMaritalStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select marital status'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return false;
    }

    if (_stateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select state'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return false;
    }

    if (_districtController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select district'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return false;
    }

    if (_currentlyWorking && _selectedNoticePeriod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select notice period'),
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
        maritalStatus: _selectedMaritalStatus!,
        state: _stateController.text.trim(),
        district: _districtController.text.trim(),
        annualIncomeLakh: _selectedAnnualIncomeLakh,
        annualIncomeThousand: _selectedAnnualIncomeThousand,
        currentlyWorking: _currentlyWorking,
        noticePeriod: _currentlyWorking ? _selectedNoticePeriod! : 0,
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
        // Navigate to dashboard
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/candidate_dashboard', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting data: $e'),
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
                            _buildAnnualIncomeField(),
                            const SizedBox(height: 24),
                            _buildMaritalStatusField(),
                            const SizedBox(height: 24),
                            _buildStateField(),
                            const SizedBox(height: 24),
                            _buildDistrictField(),
                            const SizedBox(height: 24),
                            _buildCurrentlyWorkingToggle(),
                            if (_currentlyWorking) ...[
                              const SizedBox(height: 24),
                              _buildNoticePeriodField(),
                            ],
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
                                  color: primaryBlue.withOpacity(0.35),
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

  Widget _buildSimpleTextField(
    String label,
    IconData icon,
    TextEditingController controller,
    String hintText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: primaryBlue),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
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
          ),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }
  Widget _buildAnnualIncomeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.currency_rupee, size: 20, color: primaryBlue),
            const SizedBox(width: 8),
            const Text(
              'Annual Income',
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
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedAnnualIncomeLakh != null
                        ? primaryBlue
                        : const Color(0xFFE5E7EB),
                    width: _selectedAnnualIncomeLakh != null ? 2 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedAnnualIncomeLakh,
                    hint: const Text(
                      'Select',
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
                    items: List.generate(100, (index) => index + 1).map((val) {
                      return DropdownMenuItem(value: val, child: Text('$val'));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedAnnualIncomeLakh = value;
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Lakh',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedAnnualIncomeThousand != null
                        ? primaryBlue
                        : const Color(0xFFE5E7EB),
                    width: _selectedAnnualIncomeThousand != null ? 2 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedAnnualIncomeThousand,
                    hint: const Text(
                      'Select',
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
                    items: List.generate(100, (index) => index + 1).map((val) {
                      return DropdownMenuItem(value: val, child: Text('$val'));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedAnnualIncomeThousand = value;
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Thousand',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ],
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
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedMaritalStatus != null
                  ? primaryBlue
                  : const Color(0xFFE5E7EB),
              width: _selectedMaritalStatus != null ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: ButtonTheme(
            alignedDropdown: true,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedMaritalStatus,
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
                  return DropdownMenuItem(value: status, child: Text(status));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMaritalStatus = value;
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 20, color: primaryBlue),
            const SizedBox(width: 8),
            const Text(
              'State',
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
        Stack(
          children: [
            TextFormField(
              controller: _stateController,
              decoration: InputDecoration(
                hintText: 'Search or select state',
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
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please select a state';
                }
                return null;
              },
              onChanged: (value) {
                // Clear district when state changes
                if (_districtController.text.isNotEmpty) {
                  setState(() {
                    _districtController.clear();
                  });
                }
              },
            ),
            if (_showStateDropdown)
              Positioned(
                top: 56,
                left: 0,
                right: 0,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryBlue.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredStates.length,
                    itemBuilder: (context, index) {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _stateController.text = _filteredStates[index];
                            _showStateDropdown = false;
                            _districtController.clear();
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
                            _filteredStates[index],
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
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDistrictField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_city_outlined, size: 20, color: primaryBlue),
            const SizedBox(width: 8),
            const Text(
              'District',
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
        Stack(
          children: [
            TextFormField(
              controller: _districtController,
              enabled: _stateController.text.trim().isNotEmpty,
              decoration: InputDecoration(
                hintText: _stateController.text.trim().isEmpty
                    ? 'Select state first'
                    : 'Search or select district',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                ),
                filled: true,
                fillColor: _stateController.text.trim().isEmpty
                    ? Colors.grey.shade100
                    : Colors.white,
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
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFE5E7EB),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                suffixIcon: Icon(
                  Icons.arrow_drop_down,
                  color: _stateController.text.trim().isEmpty
                      ? Colors.grey
                      : primaryBlue,
                ),
              ),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _stateController.text.trim().isEmpty
                    ? Colors.grey
                    : const Color(0xFF1F2937),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please select a district';
                }
                return null;
              },
            ),
            if (_showDistrictDropdown &&
                _stateController.text.trim().isNotEmpty)
              Positioned(
                top: 56,
                left: 0,
                right: 0,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryBlue.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredDistricts.length,
                    itemBuilder: (context, index) {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _districtController.text =
                                _filteredDistricts[index];
                            _showDistrictDropdown = false;
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
                            _filteredDistricts[index],
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
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentlyWorkingToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.work_outline, size: 20, color: primaryBlue),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Currently Working',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          Switch(
            value: _currentlyWorking,
            onChanged: (value) {
              setState(() {
                _currentlyWorking = value;
              });
            },
            activeColor: primaryBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildNoticePeriodField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 20, color: primaryBlue),
            const SizedBox(width: 8),
            const Text(
              'Notice Period',
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _noticePeriods.map((days) {
            final isSelected = _selectedNoticePeriod == days;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedNoticePeriod = days;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primaryBlue : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? primaryBlue : const Color(0xFFE5E7EB),
                    width: isSelected ? 2 : 1.5,
                  ),
                ),
                child: Text(
                  '$days days',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
