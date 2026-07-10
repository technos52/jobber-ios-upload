import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/dropdown_service.dart';
import '../widgets/searchable_dropdown.dart';
import '../dropdown_options/dropdown_options.dart';
import '../dropdown_options/qualification.dart';
import '../dropdown_options/job_category.dart';
import '../dropdown_options/job_type.dart';
import '../dropdown_options/designation.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const primaryBlue = Color(0xFF007BFF);

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isAppleUser {
    if (!Platform.isIOS) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    for (final info in user.providerData) {
      if (info.providerId == 'apple.com') {
        return true;
      }
    }
    return false;
  }

  // Controllers
  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _degreeSpecializationController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _designationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _jobCategoryController = TextEditingController();
  final _jobTypeController = TextEditingController();
  final _companyTypeController = TextEditingController();
  final _stateController = TextEditingController();
  final _districtController = TextEditingController();

  // Data
  String? _title;
  String? _gender;
  int? _age;
  int? _experienceYears;
  int? _experienceMonths;
  String? _maritalStatus;
  String? _companyType;
  String? _state;
  String? _district;
  bool? _currentlyWorking;
  int? _selectedNoticePeriod;
  String? _email;
  String? _documentId;
  String? _selectedQualification;
  String _degreeSpecialization = '';
  bool _showDegreeSpecialization = false;
  String? _selectedJobCategory;
  String? _selectedJobType;
  String? _selectedDesignation;

  // Dropdown options from Firebase
  List<String> _qualifications = [];
  List<String> _jobCategories = [];
  List<String> _jobTypes = [];
  List<String> _designations = [];
  List<String> _companyTypes = [];

  // State and district variables for modal selection
  List<String> _filteredStates = [];

  final List<String> _titles = ['Mr.', 'Mrs.', 'Ms.', 'Dr.'];
  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _maritalStatuses = [
    'Unmarried',
    'Married',
    'Divorced',
    'Widowed',
  ];

  static const List<int> _noticePeriods = [7, 15, 30, 45, 60, 90, 180];

  static const Map<String, List<String>> _indiaStatesDistricts = {
    'Andhra Pradesh': [
      'Visakhapatnam',
      'Vijayawada',
      'Guntur',
      'Nellore',
      'Tirupati',
    ],
    'Arunachal Pradesh': [
      'Itanagar',
      'Naharlagun',
      'Pasighat',
      'Tawang',
      'Ziro',
    ],
    'Assam': ['Guwahati', 'Silchar', 'Dibrugarh', 'Jorhat', 'Tezpur'],
    'Bihar': ['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Purnia'],
    'Chhattisgarh': ['Raipur', 'Bhilai', 'Korba', 'Bilaspur', 'Durg'],
    'Goa': ['Panaji', 'Margao', 'Vasco da Gama', 'Mapusa', 'Ponda'],
    'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar'],
    'Haryana': ['Gurgaon', 'Faridabad', 'Panipat', 'Ambala', 'Karnal'],
    'Himachal Pradesh': ['Shimla', 'Dharamshala', 'Solan', 'Mandi', 'Kullu'],
    'Jharkhand': ['Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro', 'Deoghar'],
    'Karnataka': ['Bangalore', 'Mysore', 'Hubli', 'Mangalore', 'Belgaum'],
    'Kerala': [
      'Thiruvananthapuram',
      'Kochi',
      'Kozhikode',
      'Thrissur',
      'Kollam',
    ],
    'Madhya Pradesh': ['Indore', 'Bhopal', 'Jabalpur', 'Gwalior', 'Ujjain'],
    'Maharashtra': [
      'Mumbai',
      'Pune',
      'Nagpur',
      'Thane',
      'Nashik',
      'Aurangabad',
    ],
    'Manipur': ['Imphal', 'Thoubal', 'Bishnupur', 'Churachandpur', 'Kakching'],
    'Meghalaya': ['Shillong', 'Tura', 'Jowai', 'Nongpoh', 'Baghmara'],
    'Mizoram': ['Aizawl', 'Lunglei', 'Saiha', 'Champhai', 'Kolasib'],
    'Nagaland': ['Kohima', 'Dimapur', 'Mokokchung', 'Tuensang', 'Wokha'],
    'Odisha': ['Bhubaneswar', 'Cuttack', 'Rourkela', 'Berhampur', 'Sambalpur'],
    'Punjab': ['Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda'],
    'Rajasthan': ['Jaipur', 'Jodhpur', 'Kota', 'Bikaner', 'Udaipur'],
    'Sikkim': ['Gangtok', 'Namchi', 'Gyalshing', 'Mangan', 'Rangpo'],
    'Tamil Nadu': [
      'Chennai',
      'Coimbatore',
      'Madurai',
      'Tiruchirappalli',
      'Salem',
    ],
    'Telangana': [
      'Hyderabad',
      'Warangal',
      'Nizamabad',
      'Karimnagar',
      'Khammam',
    ],
    'Tripura': ['Agartala', 'Dharmanagar', 'Udaipur', 'Kailashahar', 'Belonia'],
    'Uttar Pradesh': [
      'Lucknow',
      'Kanpur',
      'Ghaziabad',
      'Agra',
      'Varanasi',
      'Noida',
    ],
    'Uttarakhand': ['Dehradun', 'Haridwar', 'Roorkee', 'Haldwani', 'Rudrapur'],
    'West Bengal': ['Kolkata', 'Howrah', 'Durgapur', 'Asansol', 'Siliguri'],
    'Delhi': [
      'Central Delhi',
      'North Delhi',
      'South Delhi',
      'East Delhi',
      'West Delhi',
    ],
    'Jammu and Kashmir': [
      'Srinagar',
      'Jammu',
      'Anantnag',
      'Baramulla',
      'Udhampur',
    ],
    'Ladakh': ['Leh', 'Kargil', 'Nubra', 'Changthang', 'Zanskar'],
    'Andaman and Nicobar Islands': [
      'Port Blair',
      'Car Nicobar',
      'Mayabunder',
      'Rangat',
      'Diglipur',
    ],
    'Chandigarh': ['Chandigarh'],
    'Dadra and Nagar Haveli and Daman and Diu': ['Daman', 'Diu', 'Silvassa'],
    'Lakshadweep': ['Kavaratti', 'Agatti', 'Minicoy'],
    'Puducherry': ['Puducherry', 'Karaikal', 'Mahe', 'Yanam'],
  };

  @override
  void initState() {
    super.initState();
    _loadDropdownOptions();
    _loadUserData();
  }

  /// Load dropdown options - prioritize local options, fallback to Firebase
  Future<void> _loadDropdownOptions() async {
    try {
      print('🔍 Loading dropdown options (local + Firebase)...');

      // Load from centralized dropdown options first
      setState(() {
        _qualifications = QualificationOptions.values;
        _jobCategories = JobCategoryOptions.values;
        _jobTypes = JobTypeOptions.values;
        _designations = DesignationOptions.values;
      });

      print('✅ Loaded local dropdown options for edit profile');

      // Try to get additional options from Firebase (like company types)
      try {
        final options = await DropdownService.getAllDropdownOptions();
        if (mounted && options.isNotEmpty) {
          setState(() {
            // Only update company types from Firebase as others are handled locally
            if (options.containsKey('company_types')) {
              _companyTypes = options['company_types'] ?? [];
            }
          });
        }
      } catch (e) {
        print('⚠️ Firebase options not available for edit profile: $e');
      }

      // Ensure company types has fallback values
      if (_companyTypes.isEmpty) {
        _companyTypes = DropdownService.getDefaultOptions('company_types');
      }
    } catch (e) {
      print('❌ Error loading dropdown options in edit profile: $e');
      if (mounted) {
        setState(() {
          // Use centralized local options as fallback
          _qualifications = QualificationOptions.values;
          _jobCategories = JobCategoryOptions.values;
          _jobTypes = JobTypeOptions.values;
          _designations = DesignationOptions.values;
          _companyTypes = DropdownService.getDefaultOptions('company_types');
        });
      }
    }
  }

  void _showStateSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Select State',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search states...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    if (value.isEmpty) {
                      _filteredStates = _indiaStatesDistricts.keys.toList();
                    } else {
                      _filteredStates = _indiaStatesDistricts.keys
                          .where(
                            (state) => state.toLowerCase().contains(
                              value.toLowerCase(),
                            ),
                          )
                          .toList();
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            // States list
            Expanded(
              child: Builder(
                builder: (context) {
                  final states = _filteredStates.isNotEmpty
                      ? _filteredStates
                      : _indiaStatesDistricts.keys.toList();

                  return ListView.builder(
                    itemCount: states.length,
                    itemBuilder: (context, index) {
                      final state = states[index];
                      return ListTile(
                        leading: Icon(
                          Icons.location_on_outlined,
                          color: primaryBlue,
                        ),
                        title: Text(
                          state,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () {
                          print('🎯 Selected state: $state');
                          setState(() {
                            _stateController.text = state;
                            _districtController.clear();
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDistrictSelectionModal() {
    final selectedState = _stateController.text.trim();
    if (selectedState.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a state first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final districts = _indiaStatesDistricts[selectedState] ?? [];
    if (districts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No districts available for selected state'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Select District in $selectedState',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Districts list
            Expanded(
              child: ListView.builder(
                itemCount: districts.length,
                itemBuilder: (context, index) {
                  final district = districts[index];
                  return ListTile(
                    leading: Icon(
                      Icons.location_city_outlined,
                      color: primaryBlue,
                    ),
                    title: Text(
                      district,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      print('🎯 Selected district: $district');
                      setState(() {
                        _districtController.text = district;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Try to find by email first
        QuerySnapshot candidateQuery = await FirebaseFirestore.instance
            .collection('candidates')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        // If not found by email, try by mobile number (fallback)
        if (candidateQuery.docs.isEmpty) {
          candidateQuery = await FirebaseFirestore.instance
              .collection('candidates')
              .where('mobileNumber', isEqualTo: user.phoneNumber ?? '')
              .limit(1)
              .get();
        }

        if (candidateQuery.docs.isNotEmpty && mounted) {
          final data = candidateQuery.docs.first.data() as Map<String, dynamic>;
          _documentId = candidateQuery.docs.first.id;

          print('📄 Found candidate document: $_documentId');
          print('📊 Document data: $data');

          setState(() {
            _email = data['email'] as String?;

            // Remove title prefixes from full name for display
            String fullName = (data['fullName'] ?? '') as String;
            print('🔍 Original fullName from DB: "$fullName"');

            for (String titlePrefix in _titles) {
              if (fullName.startsWith('$titlePrefix ')) {
                fullName = fullName.substring(titlePrefix.length + 1);
                print('🏷️ Removed title prefix, remaining name: "$fullName"');
                break;
              }
            }
            _fullNameController.text = fullName;

            _mobileController.text = (data['mobileNumber'] ?? '') as String;
            _companyNameController.text = (data['companyName'] ?? '') as String;
            _stateController.text = (data['state'] ?? '') as String;
            _districtController.text = (data['district'] ?? '') as String;

            _title = data['title'] as String?;
            print('🏷️ Loaded title: "$_title"');
            print('📝 Name controller set to: "${_fullNameController.text}"');

            _gender = data['gender'] as String?;
            _age = data['age'] as int?;
            _experienceYears = data['experienceYears'] as int?;
            _experienceMonths = data['experienceMonths'] as int?;
            _maritalStatus = data['maritalStatus'] as String?;
            _companyType = data['companyType'] as String?;
            _currentlyWorking = data['currentlyWorking'] is bool
                ? data['currentlyWorking'] as bool?
                : data['currentlyWorking'] is String
                ? (data['currentlyWorking'] as String).toLowerCase() == 'true'
                : null;
            _selectedNoticePeriod = data['noticePeriod'] as int?;

            // Handle dropdown selections
            final qualificationData = data['qualification'] as String?;
            if (qualificationData != null) {
              // Check if qualification contains specialization in parentheses
              final regex = RegExp(r'^(.+?)\s*\((.+?)\)$');
              final match = regex.firstMatch(qualificationData);

              if (match != null) {
                // Qualification has specialization
                _selectedQualification = match.group(1)?.trim();
                _degreeSpecializationController.text =
                    match.group(2)?.trim() ?? '';
                _showDegreeSpecialization = true;
              } else {
                // Qualification without specialization
                _selectedQualification = qualificationData;
                _showDegreeSpecialization = false;
                _degreeSpecializationController.clear();
              }
            } else {
              _selectedQualification = null;
              _showDegreeSpecialization = false;
              _degreeSpecializationController.clear();
            }
            _selectedJobCategory = data['jobCategory'] as String?;
            _selectedJobType = data['jobType'] as String?;
            _selectedDesignation = data['designation'] as String?;

            _isLoading = false;
          });
        } else if (mounted) {
          print('⚠️ No candidate document found for user: ${user.email}');
          setState(() {
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_documentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Unable to find your profile to update'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      print('📝 Updating candidate document: $_documentId');

      // Construct full name with title if title is selected
      String fullNameToSave = _fullNameController.text.trim();
      if (_title != null && _title!.isNotEmpty) {
        fullNameToSave = '$_title $fullNameToSave';
      }

      print('💾 Saving profile data:');
      print('   Name field: "${_fullNameController.text}"');
      print('   Selected title: "$_title"');
      print('   Full name to save: "$fullNameToSave"');

      // Prepare qualification string with specialization if applicable
      String qualificationToSave = _selectedQualification ?? '';
      if (_showDegreeSpecialization &&
          _degreeSpecializationController.text.trim().isNotEmpty) {
        qualificationToSave =
            '${_selectedQualification!} (${_degreeSpecializationController.text.trim()})';
      }

      final updateData = {
        'fullName': fullNameToSave,
        'mobileNumber': _mobileController.text.trim(),
        'companyName': _companyNameController.text.trim(),
        'state': _stateController.text.trim(),
        'district': _districtController.text.trim(),
        'title': _title,
        'gender': _gender,
        'age': _age,
        'experienceYears': _experienceYears,
        'experienceMonths': _experienceMonths,
        'maritalStatus': _maritalStatus,
        'companyType': _companyType,
        'currentlyWorking': _currentlyWorking,
        'noticePeriod': _selectedNoticePeriod,
        'qualification': qualificationToSave,
        'jobCategory': _selectedJobCategory,
        'jobType': _selectedJobType,
        'designation': _selectedDesignation,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print('📊 Complete update data: $updateData');

      print('📊 Update data: $updateData');

      await FirebaseFirestore.instance
          .collection('candidates')
          .doc(_documentId)
          .update(updateData);

      print('✅ Profile updated successfully');

      if (mounted) {
        // Update UI state to reflect changes
        setState(() {
          // UI is already updated through the controllers and variables
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate profile was updated
      }
    } catch (e) {
      print('❌ Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _qualificationController.dispose();
    _degreeSpecializationController.dispose();
    _companyNameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _jobCategoryController.dispose();
    _jobTypeController.dispose();
    _companyTypeController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Edit Profile',
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
          // Unfocus text fields when tapping outside
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.opaque,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [primaryBlue, primaryBlue.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _email ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Personal Information
                      _buildSectionHeader('Personal Information'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _fullNameController,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        readOnly: _isAppleUser && _fullNameController.text.trim().isNotEmpty,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown(
                        label: 'Title',
                        value: _title,
                        items: _titles,
                        onChanged: _isAppleUser && _fullNameController.text.trim().isNotEmpty
                            ? null
                            : (value) => setState(() => _title = value),
                        icon: Icons.title,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown(
                        label: 'Gender',
                        value: _gender,
                        items: _genders,
                        onChanged: (value) => setState(() => _gender = value),
                        icon: Icons.wc,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _mobileController,
                        label: 'Mobile Number (Optional)',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            if (value.length != 10) {
                              return 'Mobile number must be 10 digits';
                            }
                            if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
                              return 'Invalid mobile number';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown(
                        label: 'Marital Status',
                        value: _maritalStatus,
                        items: _maritalStatuses,
                        onChanged: (value) =>
                            setState(() => _maritalStatus = value),
                        icon: Icons.favorite_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildAgeField(),

                      const SizedBox(height: 24),

                      // Professional Information
                      _buildSectionHeader('Professional Information'),
                      const SizedBox(height: 12),
                      _buildSearchableDropdown(
                        label: 'Qualification',
                        value: _selectedQualification,
                        items: _qualifications,
                        onChanged: (value) {
                          setState(() {
                            _selectedQualification = value;
                            // Show specialization field for any qualification selected
                            _showDegreeSpecialization =
                                value != null && value.isNotEmpty;
                            if (!_showDegreeSpecialization) {
                              _degreeSpecializationController.clear();
                            }
                          });
                        },
                        icon: Icons.school_outlined,
                      ),
                      if (_showDegreeSpecialization) ...[
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _degreeSpecializationController,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1F2937),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Specialization/Field of Study',
                              hintText:
                                  'e.g., Computer Science, Mechanical Engineering, Commerce',
                              labelStyle: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.subject_rounded,
                                color: primaryBlue,
                                size: 22,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildExperienceField(),
                      const SizedBox(height: 16),
                      _buildSearchableDropdown(
                        label: 'Department / Job Category',
                        value: _selectedJobCategory,
                        items: _jobCategories,
                        onChanged: (value) =>
                            setState(() => _selectedJobCategory = value),
                        icon: Icons.category_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildSearchableDropdown(
                        label: 'Job Type',
                        value: _selectedJobType,
                        items: _jobTypes,
                        onChanged: (value) =>
                            setState(() => _selectedJobType = value),
                        icon: Icons.work_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildSearchableDropdown(
                        label: 'Designation',
                        value: _selectedDesignation,
                        items: _designations,
                        onChanged: (value) =>
                            setState(() => _selectedDesignation = value),
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _companyNameController,
                        label: 'Company Name',
                        icon: Icons.business_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildSearchableDropdown(
                        label: 'Company Type',
                        value: _companyType,
                        items: _companyTypes,
                        onChanged: (value) =>
                            setState(() => _companyType = value),
                        icon: Icons.business_center_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildCurrentlyWorkingToggle(),
                      if (_currentlyWorking == true) ...[
                        const SizedBox(height: 16),
                        _buildNoticePeriodField(),
                      ],

                      const SizedBox(height: 24),

                      // Location Information
                      _buildSectionHeader('Location Information'),
                      const SizedBox(height: 12),
                      _buildStateField(),
                      const SizedBox(height: 16),
                      _buildDistrictField(),

                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [primaryBlue, Color(0xFF0056CC)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isSaving
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
                                    'Save Changes',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1F2937),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        readOnly: readOnly,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: readOnly ? Colors.grey.shade700 : const Color(0xFF1F2937),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(icon, color: readOnly ? Colors.grey : primaryBlue, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    required IconData icon,
  }) {
    final bool disabled = onChanged == null;
    return Container(
      decoration: BoxDecoration(
        color: disabled ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: disabled ? Colors.grey : primaryBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: disabled ? Colors.grey.shade700 : const Color(0xFF1F2937),
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchableDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: primaryBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: SearchableDropdown(
              value: value,
              items: items,
              hintText: 'Select or search $label',
              labelText: label,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(Icons.cake_outlined, color: primaryBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Age',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(50, (index) {
                    final age = index + 18;
                    final isSelected = _age == age;
                    return InkWell(
                      onTap: () => setState(() => _age = age),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryBlue
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$age',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(Icons.work_history_outlined, color: primaryBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Experience',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<int>(
                            value: _experienceYears,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: List.generate(31, (index) => index).map((
                              year,
                            ) {
                              return DropdownMenuItem<int>(
                                value: year,
                                child: Text('$year'),
                              );
                            }).toList(),
                            onChanged: (value) =>
                                setState(() => _experienceYears = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Months',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<int>(
                            value: _experienceMonths,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: List.generate(12, (index) => index).map((
                              month,
                            ) {
                              return DropdownMenuItem<int>(
                                value: month,
                                child: Text('$month'),
                              );
                            }).toList(),
                            onChanged: (value) =>
                                setState(() => _experienceMonths = value),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentlyWorkingToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(Icons.work_outline, color: primaryBlue, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Currently Working',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          Switch(
            value: _currentlyWorking ?? false,
            onChanged: (value) => setState(() => _currentlyWorking = value),
            activeColor: primaryBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildNoticePeriodField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, color: primaryBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notice Period',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _noticePeriods.map((days) {
                    final isSelected = _selectedNoticePeriod == days;
                    return InkWell(
                      onTap: () => setState(() => _selectedNoticePeriod = days),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryBlue
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$days days',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, color: primaryBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'State',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _stateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    hintText: 'Select state',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  onTap: () {
                    print('🖱️ State field tapped - showing modal');
                    _showStateSelectionModal();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(Icons.location_city_outlined, color: primaryBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'District',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _districtController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: _stateController.text.trim().isEmpty
                        ? 'Select state first'
                        : 'Select district',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    fillColor: _stateController.text.trim().isEmpty
                        ? Colors.grey.shade100
                        : Colors.white,
                    filled: true,
                  ),
                  onTap: () {
                    print('🖱️ District field tapped - showing modal');
                    _showDistrictSelectionModal();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
