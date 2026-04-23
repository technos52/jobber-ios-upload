import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'services/job_application_service.dart';
import 'services/dropdown_service.dart';
import 'dropdown_options/dropdown_options.dart';
import 'dropdown_options/qualification.dart';
import 'dropdown_options/job_category.dart';
import 'dropdown_options/job_type.dart';
import 'dropdown_options/designation.dart';
// import 'screens/edit_profile_screen.dart'; // Disabled profile editing
import 'screens/my_applications_screen.dart';
import 'screens/my_resume_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/about_us_screen.dart';
import 'screens/premium_upgrade_dialog.dart';
import 'services/video_ad_service.dart';

class SimpleCandidateDashboard extends StatefulWidget {
  const SimpleCandidateDashboard({super.key});

  @override
  State<SimpleCandidateDashboard> createState() =>
      _SimpleCandidateDashboardState();
}

class _SimpleCandidateDashboardState extends State<SimpleCandidateDashboard>
    with WidgetsBindingObserver {
  int _currentBottomNavIndex = 0;
  static const primaryBlue = Color(0xFF007BFF);

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allJobs = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  bool _isSearching = false;
  bool _isLoadingJobs = true;

  // Filter functionality - updated to use jobCategory and jobType
  Map<String, Set<String>> _activeFilters = {
    'jobType': {},
    'jobCategory': {}, // Changed from department to jobCategory
    'jobSearchFor': {},
    'designation': {},
    'location': {},
  };
  bool _hasActiveFilters = false;

  // Dynamic filter options from Firebase
  Map<String, List<String>> _filterOptions = {
    'jobType': [],
    'jobCategory': [], // Changed from department to jobCategory
    'jobSearchFor': [],
    'designation': [],
    'location': [],
  };

  // Job description expansion state
  Set<String> _expandedJobDescriptions = {};

  // Applied jobs tracking
  Set<String> _appliedJobIds = {};
  bool _isLoadingAppliedJobs = false;
  // Job category tabs functionality
  List<String> _jobCategories = [];
  String _selectedCategory = 'All Jobs';
  bool _isLoadingCategories = true;

  // Candidate profile data
  String _candidateName = '';
  String _candidateGender = '';
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCandidateProfile();
    _loadJobsFromFirebase();
    _loadJobCategories();
    _loadFilterOptions();
    _loadAppliedJobs();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when returning to this screen or switching tabs
    if (_currentBottomNavIndex == 0) {
      _refreshJobCategoriesIfNeeded();
      // Also refresh profile data to ensure welcome message is up to date
      _loadCandidateProfile();
    } else if (_currentBottomNavIndex == 1) {
      // Always refresh profile data when on profile tab
      _loadCandidateProfile();
    }
  }

  // Refresh job categories if they haven't been loaded recently
  void _refreshJobCategoriesIfNeeded() {
    final now = DateTime.now();
    if (_lastCategoryRefresh == null ||
        now.difference(_lastCategoryRefresh!).inMinutes > 5) {
      _loadJobCategories();
      _lastCategoryRefresh = now;
    }
  }

  DateTime? _lastCategoryRefresh;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh profile data when app comes to foreground
    if (state == AppLifecycleState.resumed && mounted) {
      debugPrint('🔄 App resumed, refreshing profile data...');
      _loadCandidateProfile();
    }
  }

  Future<void> _loadCandidateProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('🔍 Loading candidate profile for user: ${user.uid}');
        debugPrint('🔍 Firebase Auth displayName: ${user.displayName}');
        debugPrint('🔍 Firebase Auth email: ${user.email}');
        debugPrint('🔍 Firebase Auth phoneNumber: ${user.phoneNumber}');

        // Check if guest user
        if (user.isAnonymous) {
          debugPrint('👤 Guest user detected, skipping Firestore profile lookup');
          if (mounted) {
            setState(() {
              _candidateName = 'Guest User';
              _candidateGender = '';
              _isLoadingProfile = false;
            });
          }
          return;
        }

        // Get the actual document ID for this user's email
        final email = user.email;
        if (email == null) {
          debugPrint('❌ Guest-like user detected but not marked anonymous? Email is null.');
          if (mounted) {
            setState(() {
              _candidateName = 'User';
              _candidateGender = '';
              _isLoadingProfile = false;
            });
          }
          return;
        }

        final userId = await FirebaseService.getUserDocumentIdByEmail(email);
        if (userId == null) {
          debugPrint('❌ User document not found for email: ${user.email}');
          if (mounted) {
            setState(() {
              _candidateName = 'User';
              _candidateGender = '';
              _isLoadingProfile = false;
            });
          }
          return;
        }
        debugPrint('🔍 Using document ID for profile lookup: $userId');

        // Always fetch fresh data from Firebase (no cache)
        String candidateName = '';
        String candidateGender = '';

        // Try to get candidate data from Firestore (always fresh)
        try {
          Map<String, dynamic>? candidateData;

          // First try with the consistent userId (phoneNumber ?? uid)
          debugPrint('📄 Trying to load candidate from: candidates/$userId');
          final candidateDoc = await FirebaseFirestore.instance
              .collection('candidates')
              .doc(userId)
              .get(
                const GetOptions(source: Source.server),
              ); // Force server fetch

          if (candidateDoc.exists) {
            candidateData = candidateDoc.data();
            debugPrint('✅ Candidate data found by userId: $candidateData');
          } else {
            debugPrint('❌ No candidate document found at: candidates/$userId');

            // Fallback: try to get by email if available
            final email = user.email;
            if (email != null) {
              debugPrint('🔄 Trying fallback: search by email');
              candidateData = await FirebaseService.getCandidateByEmail(
                email,
              );
              debugPrint('📄 Candidate data by email: $candidateData');
            }
          }

          if (candidateData != null) {
            // Try multiple name fields
            final firestoreName =
                candidateData['fullName'] ??
                candidateData['name'] ??
                candidateData['firstName'] ??
                candidateData['displayName'] ??
                '';

            if (firestoreName.isNotEmpty) {
              candidateName = firestoreName;
              debugPrint('✅ Got name from Firestore: $candidateName');
            }

            // Get gender for title
            candidateGender = candidateData['gender']?.toString() ?? '';
            debugPrint('📊 Gender from Firestore: $candidateGender');
          } else {
            debugPrint('⚠️ Candidate document not found in Firestore');

            // Fallback to Firebase Auth displayName if available
            if (user.displayName != null && user.displayName!.isNotEmpty) {
              candidateName = user.displayName!;
              debugPrint('✅ Got name from Firebase Auth: $candidateName');
            }
          }
        } catch (firestoreError) {
          debugPrint('⚠️ Error loading from Firestore: $firestoreError');

          // Fallback to Firebase Auth displayName if available
          if (user.displayName != null && user.displayName!.isNotEmpty) {
            candidateName = user.displayName!;
            debugPrint('✅ Got name from Firebase Auth: $candidateName');
          }
        }

        // Final fallback: use email username if no name found
        if (candidateName.isEmpty && user.email != null) {
          candidateName = user.email!.split('@')[0];
          debugPrint('📧 Using email username as fallback: $candidateName');
        }

        if (mounted) {
          setState(() {
            _candidateName = candidateName.isNotEmpty ? candidateName : 'User';
            _candidateGender = candidateGender;
            _isLoadingProfile = false;
          });

          debugPrint(
            '✅ Final candidate profile: $_candidateName ($_candidateGender)',
          );
        }
      } else {
        debugPrint('❌ No authenticated user found');
        if (mounted) {
          setState(() {
            _candidateName = 'User';
            _candidateGender = '';
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading candidate profile: $e');
      if (mounted) {
        setState(() {
          _candidateName = 'User';
          _candidateGender = '';
          _isLoadingProfile = false;
        });
      }
    }
  }

  String _getWelcomeMessage() {
    if (_isLoadingProfile) {
      return 'Welcome\nLoading...';
    }

    if (_candidateName.isEmpty || _candidateName == 'User') {
      return 'Welcome\nUser';
    }

    // Extract name without title if it exists
    String cleanName = _candidateName;

    // Remove common titles from the beginning of the name (more comprehensive list)
    final titlePrefixes = [
      'Mr.',
      'Mrs.',
      'Miss.',
      'Ms.',
      'Dr.',
      'Prof.',
      'Mr',
      'Mrs',
      'Miss',
      'Ms',
      'Dr',
      'Prof',
    ];

    for (final prefix in titlePrefixes) {
      if (cleanName.startsWith('$prefix ')) {
        cleanName = cleanName.substring(prefix.length + 1).trim();
        debugPrint(
          '🧹 Removed title "$prefix" from name: "$_candidateName" -> "$cleanName"',
        );
        break;
      }
    }

    debugPrint('🧹 Final cleaned name: "$_candidateName" -> "$cleanName"');

    // Determine title based on gender with better matching
    String title = 'Mr/Mrs';
    final gender = _candidateGender.toLowerCase().trim();

    debugPrint('🎯 Determining title for gender: "$gender"');

    if (gender == 'male' || gender == 'm') {
      title = 'Mr';
    } else if (gender == 'female' || gender == 'f') {
      title = 'Mrs';
    } else if (gender == 'others' || gender == 'other') {
      title = 'Mr/Mrs';
    }

    final welcomeMessage = 'Welcome\n$title $cleanName';
    debugPrint('🎉 Generated welcome message: "$welcomeMessage"');

    return welcomeMessage;
  }

  Future<void> _loadJobsFromFirebase() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingJobs = true;
        });
      }

      debugPrint('Loading jobs from Firebase...');

      // Temporary: Query without orderBy to avoid index requirement
      // Will use client-side sorting until Firestore index is deployed
      final jobsQuery = await FirebaseFirestore.instance
          .collection('jobs')
          .where('approvalStatus', isEqualTo: 'approved')
          .get(const GetOptions(source: Source.server)); // Force server fetch

      debugPrint('Found ${jobsQuery.docs.length} approved jobs');

      final jobs = jobsQuery.docs.map((doc) {
        final data = doc.data();

        // Debug: Print the actual Firebase data structure for first few jobs
        if (jobsQuery.docs.indexOf(doc) < 3) {
          debugPrint(
            '📄 Job document ${doc.id} data keys: ${data.keys.toList()}',
          );
        }

        // Try multiple possible field names for job description
        String jobDescription = '';
        String foundField = '';

        // List of possible field names for job description
        final descriptionFields = [
          'jobDescription',
          'description',
          'job description',
          'job_description',
          'Description',
          'JobDescription',
          'jobDesc',
          'desc',
        ];

        for (final field in descriptionFields) {
          if (data.containsKey(field)) {
            final value = data[field]?.toString() ?? '';
            if (value.isNotEmpty && value != 'null') {
              jobDescription = value;
              foundField = field;
              break; // Use first non-empty field found
            }
          }
        }

        if (jobsQuery.docs.indexOf(doc) < 3) {
          if (jobDescription.isNotEmpty) {
            debugPrint(
              '✅ Job ${doc.id}: Found description in "$foundField" (${jobDescription.length} chars)',
            );
          } else {
            debugPrint('❌ Job ${doc.id}: No description found in any field');
            debugPrint(
              '   Available fields: ${data.keys.where((k) => k.toLowerCase().contains('desc')).toList()}',
            );
          }
        }

        return {
          'id': doc.id,
          'jobTitle': data['jobTitle'] ?? '',
          'companyName': data['companyName'] ?? '',
          'location': data['location'] ?? '',
          'salaryRange': data['salaryRange'] ?? '',
          'jobType': data['jobType'] ?? '',
          'jobCategory':
              data['jobCategory'] ??
              data['department'] ??
              '', // Use jobCategory, fallback to department for backward compatibility
          'jobSearchFor':
              data['candidateDepartment'] ?? '', // Map old field to new name
          'designation': data['designation'] ?? '',
          'experienceRequired': data['experienceRequired'] ?? '',
          'jobDescription': jobDescription, // Use the found description
          'qualification': data['qualification'] ?? '',
          'industryType': data['industryType'] ?? '',
          'postedDate': data['postedDate'],
          'approvedAt': data['approvedAt'], // Add approvedAt field
          'applications': data['applications'] ?? 0,
        };
      }).toList();

      // Client-side sorting to ensure latest approved jobs appear first
      // Using approvedAt (when job was approved) as primary sort field
      debugPrint(
        '🔄 Starting client-side sorting of ${jobs.length} jobs by approvedAt...',
      );

      jobs.sort((a, b) {
        // Use approvedAt as primary field, fallback to postedDate
        final aDate = a['approvedAt'] ?? a['postedDate'];
        final bDate = b['approvedAt'] ?? b['postedDate'];

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        try {
          DateTime dateA = aDate is Timestamp
              ? aDate.toDate()
              : DateTime.parse(aDate.toString());
          DateTime dateB = bDate is Timestamp
              ? bDate.toDate()
              : DateTime.parse(bDate.toString());

          final result = dateB.compareTo(
            dateA,
          ); // Descending order (newest approved first)
          return result;
        } catch (e) {
          debugPrint('❌ Error sorting dates: $e');
          debugPrint('   aDate: $aDate (${aDate.runtimeType})');
          debugPrint('   bDate: $bDate (${bDate.runtimeType})');
          return 0;
        }
      });

      // Debug: Print job order after sorting
      debugPrint('📅 Jobs after sorting by approvedAt (first 5):');
      for (int i = 0; i < jobs.length && i < 5; i++) {
        final job = jobs[i];
        final approvedAt = job['approvedAt'];
        final postedDate = job['postedDate'];

        String approvedStr = 'Not approved';
        String postedStr = 'No posted date';

        if (approvedAt != null) {
          try {
            if (approvedAt is Timestamp) {
              final date = approvedAt.toDate();
              approvedStr =
                  '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
            } else {
              approvedStr = approvedAt.toString();
            }
          } catch (e) {
            approvedStr = 'Invalid approved date: $approvedAt';
          }
        }

        if (postedDate != null) {
          try {
            if (postedDate is Timestamp) {
              final date = postedDate.toDate();
              postedStr =
                  '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
            } else {
              postedStr = postedDate.toString();
            }
          } catch (e) {
            postedStr = 'Invalid posted date: $postedDate';
          }
        }

        debugPrint(
          '${i + 1}. ${job['jobTitle']} - Approved: $approvedStr | Posted: $postedStr',
        );
      }

      debugPrint('Processed and sorted ${jobs.length} jobs for display');

      // Debug: Print some sample data
      if (jobs.isNotEmpty) {
        final sampleJob = jobs.first;
        debugPrint(
          'Sample job data: ${sampleJob['jobTitle']} at ${sampleJob['companyName']}',
        );
        debugPrint(
          'Job type: ${sampleJob['jobType']}, Department: ${sampleJob['department']}',
        );
      }

      if (mounted) {
        setState(() {
          _allJobs = jobs;
          _isLoadingJobs = false;
        });

        // Apply filters and search to ensure proper ordering
        _applyFiltersAndSearch();
      }

      debugPrint('Jobs loaded successfully');
    } catch (e) {
      debugPrint('Error loading jobs: $e');
      if (mounted) {
        setState(() {
          _isLoadingJobs = false;
        });

        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading jobs: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadJobsFromFirebase,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadAppliedJobs() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No authenticated user found for loading applied jobs');
        return;
      }

      if (mounted) {
        setState(() {
          _isLoadingAppliedJobs = true;
        });
      }

      debugPrint(
        '🔍 Loading applied jobs from candidates/{userId}/applications subcollection',
      );

      // Check if guest user
      if (user.isAnonymous) {
        debugPrint('👤 Guest user detected, skipping applied jobs lookup');
        if (mounted) {
          setState(() {
            _isLoadingAppliedJobs = false;
          });
        }
        return;
      }

      final email = user.email;
      if (email == null) {
        if (mounted) {
          setState(() {
            _isLoadingAppliedJobs = false;
          });
        }
        return;
      }

      // Get the actual document ID for this user's email
      final userId = await FirebaseService.getUserDocumentIdByEmail(email);
      if (userId == null) {
        debugPrint('❌ User document not found for email: ${user.email}');
        if (mounted) {
          setState(() {
            _isLoadingAppliedJobs = false;
          });
        }
        return;
      }

      debugPrint('👤 User email: ${user.email}');
      debugPrint('🔑 Using document ID: $userId');

      // Load applications from the new subcollection ONLY
      final appliedJobIds = <String>{};

      try {
        final applicationsSnapshot = await FirebaseFirestore.instance
            .collection('candidates')
            .doc(userId) // Use consistent userId
            .collection('applications')
            .get();

        for (final doc in applicationsSnapshot.docs) {
          final data = doc.data();
          final jobId = data['jobId']?.toString();
          if (jobId != null && jobId.isNotEmpty) {
            appliedJobIds.add(jobId);
          }
        }

        debugPrint(
          '✅ Found ${appliedJobIds.length} applied jobs in subcollection: $appliedJobIds',
        );
      } catch (e) {
        debugPrint('⚠️ Error loading from subcollection: $e');
        // No fallback - we want to use only the new subcollection system
      }

      if (mounted) {
        setState(() {
          _appliedJobIds = appliedJobIds;
          _isLoadingAppliedJobs = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading applied jobs: $e');
      if (mounted) {
        setState(() {
          _isLoadingAppliedJobs = false;
        });
      }
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      debugPrint('🔍 Loading filter options (local + Firebase)...');

      // Load from centralized dropdown options first
      setState(() {
        _filterOptions['jobType'] = JobTypeOptions.values;
        _filterOptions['jobCategory'] = JobCategoryOptions.values;
        _filterOptions['designation'] = DesignationOptions.values;
      });

      debugPrint('✅ Loaded local filter options:');
      debugPrint('- Job Types: ${_filterOptions['jobType']?.length}');
      debugPrint('- Job Categories: ${_filterOptions['jobCategory']?.length}');
      debugPrint('- Designations: ${_filterOptions['designation']?.length}');

      // Load additional options from Firebase (like location, jobSearchFor)
      final additionalFields = [
        'candidateDepartment', // Still load from Firebase with old field name
        'location',
      ];

      for (String field in additionalFields) {
        try {
          debugPrint('📋 Fetching $field from Firebase...');

          final doc = await FirebaseFirestore.instance
              .collection('dropdown_options')
              .doc(field)
              .get(const GetOptions(source: Source.server));

          final fieldOptions = <String>[];

          if (doc.exists) {
            final data = doc.data();
            if (data != null) {
              // Try to extract options from any field that looks like a list
              for (var key in data.keys) {
                final value = data[key];
                if (value is List) {
                  for (var item in value) {
                    String? optionValue;

                    if (item is String && item.isNotEmpty && item != 'null') {
                      optionValue = item;
                    } else if (item is Map<String, dynamic>) {
                      // Try common keys
                      for (var mapKey in ['0', '1', 'value', 'name', 'label']) {
                        if (item.containsKey(mapKey)) {
                          final val = item[mapKey]?.toString();
                          if (val != null && val.isNotEmpty && val != 'null') {
                            optionValue = val;
                            break;
                          }
                        }
                      }
                    }

                    if (optionValue != null) {
                      fieldOptions.add(optionValue);
                    }
                  }
                  break; // Found a list, stop looking
                }
              }
            }
          }

          // If no options found in Firebase, extract from job data
          if (fieldOptions.isEmpty) {
            debugPrint(
              '⚠️ No $field options from Firebase, extracting from jobs...',
            );
            final jobOptions =
                _allJobs
                    .map((job) => job[field]?.toString() ?? '')
                    .where((value) => value.isNotEmpty && value != 'null')
                    .toSet()
                    .toList()
                  ..sort();
            fieldOptions.addAll(jobOptions);
          }

          if (mounted) {
            setState(() {
              // Map candidateDepartment to jobSearchFor for UI consistency
              String filterKey = field == 'candidateDepartment'
                  ? 'jobSearchFor'
                  : field;
              _filterOptions[filterKey] = fieldOptions;
            });
          }

          debugPrint('📊 Loaded $field options: ${fieldOptions.length} items');
        } catch (e) {
          debugPrint('❌ Error loading $field options: $e');

          // Fallback to job data extraction
          if (mounted) {
            final jobOptions =
                _allJobs
                    .map((job) => job[field]?.toString() ?? '')
                    .where((value) => value.isNotEmpty && value != 'null')
                    .toSet()
                    .toList()
                  ..sort();

            String filterKey = field == 'candidateDepartment'
                ? 'jobSearchFor'
                : field;

            setState(() {
              _filterOptions[filterKey] = jobOptions;
            });

            debugPrint(
              '📊 Fallback $filterKey options: ${jobOptions.length} items',
            );
          }
        }
      }

      debugPrint('🎉 Filter options loading completed');
      debugPrint('📊 Final filter options:');
      _filterOptions.forEach((key, value) {
        debugPrint('- $key: ${value.length} items');
      });
    } catch (e) {
      debugPrint('❌ Error in _loadFilterOptions: $e');
    }
  }

  Future<void> _loadJobCategories() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingCategories = true;
        });
      }

      debugPrint(
        '🔍 Loading job categories from Firebase jobCategory dropdown...',
      );

      // Load from /dropdown_options/jobCategory (not jobType)
      final jobCategoryDoc = await FirebaseFirestore.instance
          .collection('dropdown_options')
          .doc('jobCategory')
          .get(const GetOptions(source: Source.server));

      final firebaseJobCategories = <String>[];

      if (jobCategoryDoc.exists) {
        final data = jobCategoryDoc.data();
        debugPrint('✅ jobCategory document exists: $data');

        if (data != null) {
          // Extract all values from the document, but exclude certain keys/values
          for (var key in data.keys) {
            final value = data[key];

            // Skip if the key or value looks like metadata
            if (key.toLowerCase() == 'jobcategory' ||
                key.toLowerCase() == 'job_category' ||
                key.toLowerCase() == 'category') {
              debugPrint('⏭️ Skipping metadata key: "$key"');
              continue;
            }

            if (value is String && value.isNotEmpty && value != 'null') {
              // Additional validation to exclude unwanted values
              final cleanValue = value.trim();
              if (cleanValue.toLowerCase() != 'jobcategory' &&
                  cleanValue.toLowerCase() != 'job category' &&
                  cleanValue.toLowerCase() != 'category' &&
                  cleanValue.length > 0) {
                firebaseJobCategories.add(cleanValue);
                debugPrint('✅ Added job category from key "$key": $cleanValue');
              } else {
                debugPrint('⏭️ Skipping unwanted value: "$cleanValue"');
              }
            } else if (value is List) {
              // Handle list values
              for (var item in value) {
                if (item is String && item.isNotEmpty && item != 'null') {
                  final cleanItem = item.trim();
                  if (cleanItem.toLowerCase() != 'jobcategory' &&
                      cleanItem.toLowerCase() != 'job category' &&
                      cleanItem.toLowerCase() != 'category' &&
                      cleanItem.length > 0) {
                    firebaseJobCategories.add(cleanItem);
                    debugPrint('✅ Added job category from list: $cleanItem');
                  }
                }
              }
            } else if (value is Map<String, dynamic>) {
              // Handle nested objects
              for (var nestedValue in value.values) {
                if (nestedValue is String &&
                    nestedValue.isNotEmpty &&
                    nestedValue != 'null') {
                  final cleanNestedValue = nestedValue.trim();
                  if (cleanNestedValue.toLowerCase() != 'jobcategory' &&
                      cleanNestedValue.toLowerCase() != 'job category' &&
                      cleanNestedValue.toLowerCase() != 'category' &&
                      cleanNestedValue.length > 0) {
                    firebaseJobCategories.add(cleanNestedValue);
                    debugPrint(
                      '✅ Added job category from nested object: $cleanNestedValue',
                    );
                  }
                }
              }
            } else {
              debugPrint(
                '⏭️ Skipping non-string value for key "$key": $value (${value.runtimeType})',
              );
            }
          }
        }
      }

      // Remove duplicates and sort
      final uniqueJobCategories = firebaseJobCategories.toSet().toList()
        ..sort();

      debugPrint('🔍 Raw job categories found: $firebaseJobCategories');
      debugPrint(
        '🎯 Unique job categories after filtering: $uniqueJobCategories',
      );

      if (uniqueJobCategories.isNotEmpty) {
        debugPrint('🎯 Using Firebase job categories: $uniqueJobCategories');

        if (mounted) {
          setState(() {
            _jobCategories = ['All Jobs', ...uniqueJobCategories];
            _isLoadingCategories = false;
          });
        }

        debugPrint(
          '🎉 Job categories loaded from Firebase jobCategory: $_jobCategories',
        );
        return;
      }

      // Fallback: If no jobCategory data found, extract from actual jobs
      debugPrint(
        '⚠️ No jobCategory data found in Firebase, extracting from jobs...',
      );

      // Extract categories from actual job data
      final jobBasedCategories = <String>{};
      for (final job in _allJobs) {
        final jobCategory = job['jobCategory']?.toString();
        final department = job['department']?.toString();

        if (jobCategory != null &&
            jobCategory.isNotEmpty &&
            jobCategory != 'null') {
          jobBasedCategories.add(jobCategory);
        }
        if (department != null &&
            department.isNotEmpty &&
            department != 'null') {
          jobBasedCategories.add(department);
        }
      }

      final jobBasedCategoriesList = jobBasedCategories.toList()..sort();
      debugPrint('📊 Categories extracted from jobs: $jobBasedCategoriesList');

      if (mounted) {
        setState(() {
          if (jobBasedCategoriesList.isNotEmpty) {
            _jobCategories = ['All Jobs', ...jobBasedCategoriesList];
          } else {
            _jobCategories = ['All Jobs'];
          }
          _isLoadingCategories = false;
        });
      }

      debugPrint('🎉 Job categories loaded (from jobs): $_jobCategories');
    } catch (e) {
      debugPrint('❌ Error loading job categories: $e');

      // Error fallback: extract from jobs
      final jobBasedCategories = <String>{};
      for (final job in _allJobs) {
        final jobCategory = job['jobCategory']?.toString();
        final department = job['department']?.toString();

        if (jobCategory != null &&
            jobCategory.isNotEmpty &&
            jobCategory != 'null') {
          jobBasedCategories.add(jobCategory);
        }
        if (department != null &&
            department.isNotEmpty &&
            department != 'null') {
          jobBasedCategories.add(department);
        }
      }

      final jobBasedCategoriesList = jobBasedCategories.toList()..sort();

      if (mounted) {
        setState(() {
          if (jobBasedCategoriesList.isNotEmpty) {
            _jobCategories = ['All Jobs', ...jobBasedCategoriesList];
          } else {
            _jobCategories = ['All Jobs'];
          }
          _isLoadingCategories = false;
        });
      }

      debugPrint('🎉 Job categories loaded (error fallback): $_jobCategories');
    }
  }

  void _onCategorySelected(String category) {
    if (mounted) {
      setState(() {
        _selectedCategory = category;
      });
      _applyFiltersAndSearch();
    }
  }

  // Add refresh function for job categories and jobs
  Future<void> _refreshData() async {
    debugPrint('🔄 Refreshing job categories, jobs, and applied jobs data...');

    if (mounted) {
      setState(() {
        _isLoadingCategories = true;
        _isLoadingJobs = true;
      });
    }

    // Refresh job categories, jobs, and applied jobs in parallel
    await Future.wait([
      _loadJobCategories(),
      _loadJobsFromFirebase(),
      _loadAppliedJobs(),
    ]);

    debugPrint('✅ Data refresh completed');
  }

  void _onSearchChanged() {
    _applyFiltersAndSearch();
  }

  void _applyFiltersAndSearch() {
    if (!mounted) return;

    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _isSearching =
          query.isNotEmpty ||
          _hasActiveFilters ||
          _selectedCategory != 'All Jobs';

      // Start with the sorted jobs (maintain original order)
      List<Map<String, dynamic>> results = List.from(_allJobs);

      // Apply category filter first (preserve order)
      if (_selectedCategory != 'All Jobs') {
        results = results.where((job) {
          // Check both jobCategory and jobType fields for comprehensive matching
          final jobCategory = job['jobCategory']?.toString() ?? '';
          final jobType = job['jobType']?.toString() ?? '';
          final jobSearchFor = job['jobSearchFor']?.toString() ?? '';
          final designation = job['designation']?.toString() ?? '';

          // Enhanced matching logic to ensure jobs appear in correct tabs
          // This ensures that if a job has any field matching the selected category,
          // it will appear in that category tab
          bool matchesCategory = false;

          // Direct field matches
          if (jobCategory == _selectedCategory ||
              jobType == _selectedCategory ||
              jobSearchFor == _selectedCategory ||
              designation == _selectedCategory) {
            matchesCategory = true;
          }

          // Fuzzy matching for common variations
          final categoryLower = _selectedCategory.toLowerCase();
          final jobCategoryLower = jobCategory.toLowerCase();
          final jobTypeLower = jobType.toLowerCase();
          final jobSearchForLower = jobSearchFor.toLowerCase();
          final designationLower = designation.toLowerCase();

          // Handle common category variations
          if (!matchesCategory) {
            // School Jobs variations
            if (categoryLower.contains('school')) {
              matchesCategory =
                  jobCategoryLower.contains('school') ||
                  jobTypeLower.contains('school') ||
                  jobSearchForLower.contains('school') ||
                  jobCategoryLower.contains('education') ||
                  jobTypeLower.contains('education') ||
                  jobSearchForLower.contains('education');
            }
            // Hospital Jobs variations
            else if (categoryLower.contains('hospital')) {
              matchesCategory =
                  jobCategoryLower.contains('hospital') ||
                  jobTypeLower.contains('hospital') ||
                  jobSearchForLower.contains('hospital') ||
                  jobCategoryLower.contains('medical') ||
                  jobTypeLower.contains('medical') ||
                  jobSearchForLower.contains('medical') ||
                  jobCategoryLower.contains('healthcare') ||
                  jobTypeLower.contains('healthcare') ||
                  jobSearchForLower.contains('healthcare');
            }
            // Bank/NBFC Jobs variations
            else if (categoryLower.contains('bank') ||
                categoryLower.contains('nbfc')) {
              matchesCategory =
                  jobCategoryLower.contains('bank') ||
                  jobTypeLower.contains('bank') ||
                  jobSearchForLower.contains('bank') ||
                  jobCategoryLower.contains('nbfc') ||
                  jobTypeLower.contains('nbfc') ||
                  jobSearchForLower.contains('nbfc') ||
                  jobCategoryLower.contains('finance') ||
                  jobTypeLower.contains('finance') ||
                  jobSearchForLower.contains('finance');
            }
            // Government Jobs variations
            else if (categoryLower.contains('government')) {
              matchesCategory =
                  jobCategoryLower.contains('government') ||
                  jobTypeLower.contains('government') ||
                  jobSearchForLower.contains('government') ||
                  jobCategoryLower.contains('public') ||
                  jobTypeLower.contains('public') ||
                  jobSearchForLower.contains('public');
            }
            // Company Jobs variations
            else if (categoryLower.contains('company')) {
              matchesCategory =
                  jobCategoryLower.contains('company') ||
                  jobTypeLower.contains('company') ||
                  jobSearchForLower.contains('company') ||
                  jobCategoryLower.contains('private') ||
                  jobTypeLower.contains('private') ||
                  jobSearchForLower.contains('private') ||
                  jobCategoryLower.contains('corporate') ||
                  jobTypeLower.contains('corporate') ||
                  jobSearchForLower.contains('corporate');
            }
          }

          return matchesCategory;
        }).toList();
      }

      // Apply active filters
      if (_hasActiveFilters) {
        for (String filterKey in _activeFilters.keys) {
          final activeValues = _activeFilters[filterKey]!;
          if (activeValues.isNotEmpty) {
            results = results.where((job) {
              final jobValue = job[filterKey]?.toString() ?? '';
              return activeValues.contains(jobValue);
            }).toList();
          }
        }
      }

      // Apply search query
      if (query.isNotEmpty) {
        results = results.where((job) {
          final jobTitle = job['jobTitle']?.toString().toLowerCase() ?? '';
          final companyName =
              job['companyName']?.toString().toLowerCase() ?? '';
          final location = job['location']?.toString().toLowerCase() ?? '';
          final jobDescription =
              job['jobDescription']?.toString().toLowerCase() ?? '';
          final jobType = job['jobType']?.toString().toLowerCase() ?? '';
          final jobCategory =
              job['jobCategory']?.toString().toLowerCase() ?? '';
          final designation =
              job['designation']?.toString().toLowerCase() ?? '';

          return jobTitle.contains(query) ||
              companyName.contains(query) ||
              location.contains(query) ||
              jobDescription.contains(query) ||
              jobType.contains(query) ||
              jobCategory.contains(query) ||
              designation.contains(query);
        }).toList();
      }

      // Ensure filtered results maintain chronological order (latest approved first)
      debugPrint(
        '🔄 Re-sorting ${results.length} filtered jobs by approvedAt to maintain latest-first order',
      );
      results.sort((a, b) {
        // Use approvedAt as primary field, fallback to postedDate
        final aDate = a['approvedAt'] ?? a['postedDate'];
        final bDate = b['approvedAt'] ?? b['postedDate'];

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        try {
          DateTime dateA = aDate is Timestamp
              ? aDate.toDate()
              : DateTime.parse(aDate.toString());
          DateTime dateB = bDate is Timestamp
              ? bDate.toDate()
              : DateTime.parse(bDate.toString());

          return dateB.compareTo(
            dateA,
          ); // Descending order (newest approved first)
        } catch (e) {
          return 0;
        }
      });

      _filteredJobs = results;

      // Debug: Print first few filtered jobs
      if (results.isNotEmpty) {
        debugPrint('📋 Filtered jobs by approvedAt (first 3):');
        for (int i = 0; i < results.length && i < 3; i++) {
          final job = results[i];
          final approvedAt = job['approvedAt'];
          final postedDate = job['postedDate'];

          String approvedStr = 'Not approved';
          String postedStr = 'No posted date';

          if (approvedAt != null) {
            try {
              if (approvedAt is Timestamp) {
                final date = approvedAt.toDate();
                approvedStr =
                    '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
              } else {
                approvedStr = approvedAt.toString();
              }
            } catch (e) {
              approvedStr = 'Invalid approved date: $approvedAt';
            }
          }

          if (postedDate != null) {
            try {
              if (postedDate is Timestamp) {
                final date = postedDate.toDate();
                postedStr =
                    '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
              } else {
                postedStr = postedDate.toString();
              }
            } catch (e) {
              postedStr = 'Invalid posted date: $postedDate';
            }
          }

          debugPrint(
            '${i + 1}. ${job['jobTitle']} - Approved: $approvedStr | Posted: $postedStr',
          );
        }
      }
    });
  }

  void _clearAllFilters() {
    setState(() {
      for (String key in _activeFilters.keys) {
        _activeFilters[key]!.clear();
      }
      _hasActiveFilters = false;
    });
    _applyFiltersAndSearch();
  }

  Set<String> _getFilterOptions(String filterKey) {
    final options = _filterOptions[filterKey] ?? [];
    return options.toSet();
  }

  Widget _buildHomePage() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: primaryBlue,
      child: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar with Filter Button
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search jobs, companies, locations...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: Colors.grey.shade400,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _applyFiltersAndSearch();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Filter Button
                    Container(
                      decoration: BoxDecoration(
                        color: _hasActiveFilters
                            ? primaryBlue.withOpacity(0.1)
                            : const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _hasActiveFilters
                              ? primaryBlue
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: IconButton(
                        onPressed: _showFilterBottomSheet,
                        icon: Icon(
                          Icons.tune,
                          size: 20,
                          color: _hasActiveFilters
                              ? primaryBlue
                              : Colors.grey.shade600,
                        ),
                        tooltip: _hasActiveFilters
                            ? 'Filters Applied'
                            : 'Filter',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Job Categories Tabs
          if (_jobCategories.isNotEmpty) ...[
            Container(
              height: 50,
              color: Colors.white,
              child: _isLoadingCategories
                  ? const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryBlue,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _jobCategories.length,
                      itemBuilder: (context, index) {
                        final category = _jobCategories[index];
                        final isSelected = _selectedCategory == category;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              category,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade700,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) => _onCategorySelected(category),
                            selectedColor: primaryBlue,
                            backgroundColor: Colors.grey.shade100,
                            side: BorderSide(
                              color: isSelected
                                  ? primaryBlue
                                  : Colors.grey.shade300,
                            ),
                            checkmarkColor: Colors.white,
                            elevation: isSelected ? 2 : 0,
                            pressElevation: 4,
                          ),
                        );
                      },
                    ),
            ),
            Container(height: 1, color: Colors.grey.shade200),
          ],

          // Jobs List
          Expanded(
            child: _isLoadingJobs
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryBlue,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading jobs...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  )
                : _filteredJobs.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 8,
                      bottom: 100, // Space for bottom navigation
                    ),
                    itemCount: _filteredJobs.length,
                    itemBuilder: (context, index) {
                      final job = _filteredJobs[index];
                      return _buildJobCard(job, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSearching ? Icons.search_off : Icons.work_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching ? 'No jobs found' : 'No jobs available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isSearching
                  ? 'Try adjusting your search or filters'
                  : 'Check back later for new opportunities',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            if (_isSearching) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  _clearAllFilters();
                  setState(() {
                    _selectedCategory = 'All Jobs';
                  });
                  _applyFiltersAndSearch();
                },
                child: const Text('Clear all filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, int index) {
    final isApplied = _appliedJobIds.contains(job['id']);
    final isExpanded = _expandedJobDescriptions.contains(job['id']);

    return Card(
      key: ValueKey(
        'job_card_${job['id']}_${isApplied ? 'applied' : 'not_applied'}_${isExpanded ? 'expanded' : 'collapsed'}',
      ),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(
            color: isApplied ? Colors.green.shade200 : Colors.grey.shade100,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Job Title, Company and Applied Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job['jobTitle'] ?? 'Job Title Not Available',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.business,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                job['companyName'] ?? 'Company Not Specified',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (isApplied)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Applied',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Key Information Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // First Row: Location and Salary
                    Row(
                      children: [
                        Expanded(
                          child: _buildEnhancedInfoItem(
                            Icons.location_on,
                            'Location',
                            job['location'] ?? 'Not Specified',
                            Colors.red.shade600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildEnhancedInfoItem(
                            Icons.currency_rupee,
                            'Salary',
                            job['salaryRange']?.isNotEmpty == true
                                ? job['salaryRange']
                                : 'Not Disclosed',
                            Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Second Row: Job Type and Experience
                    Row(
                      children: [
                        Expanded(
                          child: _buildEnhancedInfoItem(
                            Icons.work,
                            'Job Type',
                            job['jobType']?.isNotEmpty == true
                                ? job['jobType']
                                : 'Not Specified',
                            primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildEnhancedInfoItem(
                            Icons.timeline,
                            'Experience',
                            job['experienceRequired']?.isNotEmpty == true
                                ? job['experienceRequired']
                                : 'Not Specified',
                            Colors.orange.shade600,
                          ),
                        ),
                      ],
                    ),

                    // Third Row: Department and Qualification (if available)
                    if ((job['jobCategory']?.isNotEmpty == true) ||
                        (job['qualification']?.isNotEmpty == true)) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (job['jobCategory']?.isNotEmpty == true)
                            Expanded(
                              child: _buildEnhancedInfoItem(
                                Icons.category,
                                'Category',
                                job['jobCategory'],
                                Colors.purple.shade600,
                              ),
                            ),
                          if (job['jobCategory']?.isNotEmpty == true &&
                              job['qualification']?.isNotEmpty == true)
                            const SizedBox(width: 16),
                          if (job['qualification']?.isNotEmpty == true)
                            Expanded(
                              child: _buildEnhancedInfoItem(
                                Icons.school,
                                'Qualification',
                                job['qualification'],
                                Colors.indigo.shade600,
                              ),
                            ),
                        ],
                      ),
                    ],

                    // Fourth Row: Designation and Industry (if available)
                    if ((job['designation']?.isNotEmpty == true) ||
                        (job['industryType']?.isNotEmpty == true)) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (job['designation']?.isNotEmpty == true)
                            Expanded(
                              child: _buildEnhancedInfoItem(
                                Icons.badge,
                                'Designation',
                                job['designation'],
                                Colors.teal.shade600,
                              ),
                            ),
                          if (job['designation']?.isNotEmpty == true &&
                              job['industryType']?.isNotEmpty == true)
                            const SizedBox(width: 16),
                          if (job['industryType']?.isNotEmpty == true)
                            Expanded(
                              child: _buildEnhancedInfoItem(
                                Icons.business_center,
                                'Industry',
                                job['industryType'],
                                Colors.brown.shade600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Job Description Section
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedJobDescriptions.remove(job['id']);
                          } else {
                            _expandedJobDescriptions.add(job['id']);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.description,
                                  size: 18,
                                  color: primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Job Description',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 24,
                              color: primaryBlue,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (job['jobDescription']?.isNotEmpty == true) ...[
                      if (isExpanded) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            job['jobDescription'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            job['jobDescription'].length > 120
                                ? '${job['jobDescription'].substring(0, 120)}...'
                                : job['jobDescription'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          'Job description not provided by the employer.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Video Ad Label (only show if not applied)
              if (!isApplied)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF007BFF).withOpacity(0.1),
                        const Color(0xFF007BFF).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF007BFF).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007BFF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.play_circle_filled,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Free apply available after watching a short video.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF007BFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: isApplied ? null : () => _applyForJob(job),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isApplied
                            ? Colors.grey.shade300
                            : primaryBlue,
                        foregroundColor: isApplied
                            ? Colors.grey.shade600
                            : Colors.white,
                        elevation: isApplied ? 0 : 3,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isApplied ? Icons.check : Icons.send, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            isApplied ? 'Applied' : 'Apply Now',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () => _showJobDetailsModal(job),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primaryBlue, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: primaryBlue,
                            ),
                          ),
                        ],
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

  Widget _buildInfoItem(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color ?? Colors.grey.shade600,
              fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedInfoItem(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildProfilePage() {
    // DEBUG: Log when profile page is built
    debugPrint('🔍 _buildProfilePage called');
    debugPrint('🔍 Should show profile view page like the design');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Profile Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.business,
                    size: 40,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(height: 16),

                // Company/User Name
                Text(
                  _candidateName.isNotEmpty ? _candidateName : 'User',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Email
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? '',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Verified Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      SizedBox(width: 6),
                      Text(
                        'Verified',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Menu Items
          // Edit Profile disabled
          // _buildProfileMenuItem(
          //   icon: Icons.person_outline,
          //   title: 'Edit Profile',
          //   subtitle: 'Update your personal information',
          //   onTap: () {
          //     debugPrint('🔍 Edit Profile tapped');
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => const EditProfileScreen(),
          //       ),
          //     );
          //   },
          // ),

          // const SizedBox(height: 12),
          _buildProfileMenuItem(
            icon: Icons.work_outline,
            title: 'My Applications',
            subtitle: 'View your job applications',
            onTap: () {
              debugPrint('🔍 My Applications tapped');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyApplicationsScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          _buildProfileMenuItem(
            icon: Icons.description_outlined,
            title: 'My Resume',
            subtitle: 'Manage your resume and CV',
            onTap: () {
              debugPrint('🔍 My Resume tapped');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyResumeScreen()),
              );
            },
          ),

          const SizedBox(height: 12),

          _buildProfileMenuItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help and support',
            onTap: () {
              debugPrint('🔍 Help & Support tapped');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpSupportScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          _buildProfileMenuItem(
            icon: Icons.info_outline,
            title: 'About Us',
            subtitle: 'Learn more about our company',
            onTap: () {
              debugPrint('🔍 About Us tapped');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutUsScreen()),
              );
            },
          ),

          const SizedBox(height: 100), // Extra padding for bottom navigation
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;

        return Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 12,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryBlue, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showBadge) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildProfileMenuItemOld({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryBlue, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showBadge) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSimpleMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive ? Colors.red : Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDestructive ? Colors.red : Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Jobs',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Row(
                        children: [
                          if (_hasActiveFilters)
                            TextButton(
                              onPressed: () {
                                _clearAllFilters();
                                setModalState(() {});
                              },
                              child: const Text(
                                'Clear All',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Filter Content
                Expanded(
                  child: _isLoadingJobs
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  primaryBlue,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading filter options...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _allJobs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.work_off,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No jobs available',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Filters will be available when jobs are loaded',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFilterSection(
                                'Job Type',
                                'jobType',
                                _getFilterOptions('jobType'),
                                setModalState,
                              ),
                              const SizedBox(height: 24),
                              _buildFilterSection(
                                'Job Category',
                                'jobCategory',
                                _getFilterOptions('jobCategory'),
                                setModalState,
                              ),
                              const SizedBox(height: 24),
                              _buildFilterSection(
                                'Job Search For',
                                'jobSearchFor',
                                _getFilterOptions('jobSearchFor'),
                                setModalState,
                              ),
                              const SizedBox(height: 24),
                              _buildFilterSection(
                                'Designation',
                                'designation',
                                _getFilterOptions('designation'),
                                setModalState,
                              ),
                              const SizedBox(height: 24),
                              _buildFilterSection(
                                'Location',
                                'location',
                                _getFilterOptions('location'),
                                setModalState,
                              ),
                            ],
                          ),
                        ),
                ),

                // Apply Button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoadingJobs || _allJobs.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context);
                              _applyFiltersAndSearch();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isLoadingJobs
                            ? 'Loading...'
                            : _allJobs.isEmpty
                            ? 'No jobs to filter'
                            : 'Apply Filters',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterSection(
    String title,
    String filterKey,
    Set<String> options,
    StateSetter setModalState,
  ) {
    // Don't show section if no options available
    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            Text(
              '${options.length} options',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = _activeFilters[filterKey]!.contains(option);
            return FilterChip(
              label: Text(
                option,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? primaryBlue : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setModalState(() {
                  if (selected) {
                    _activeFilters[filterKey]!.add(option);
                  } else {
                    _activeFilters[filterKey]!.remove(option);
                  }

                  // Update hasActiveFilters flag
                  _hasActiveFilters = _activeFilters.values.any(
                    (filterSet) => filterSet.isNotEmpty,
                  );
                });
              },
              selectedColor: primaryBlue.withOpacity(0.2),
              checkmarkColor: primaryBlue,
              side: BorderSide(
                color: isSelected ? primaryBlue : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1,
              ),
              elevation: isSelected ? 2 : 0,
              pressElevation: 4,
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showJobDetailsModal(Map<String, dynamic> job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Job Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Job details content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Job title and company
                    Text(
                      job['jobTitle'] ?? 'No Title',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      job['companyName'] ?? 'No Company',
                      style: const TextStyle(
                        fontSize: 18,
                        color: primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Job info grid
                    _buildJobDetailRow('Location', job['location']),
                    _buildJobDetailRow('Job Type', job['jobType']),
                    _buildJobDetailRow('Job Category', job['jobCategory']),
                    _buildJobDetailRow('Designation', job['designation']),
                    _buildJobDetailRow(
                      'Experience Required',
                      job['experienceRequired'],
                    ),
                    _buildJobDetailRow('Qualification', job['qualification']),
                    _buildJobDetailRow('Salary Range', job['salaryRange']),
                    _buildJobDetailRow('Industry Type', job['industryType']),

                    if (job['jobDescription'] != null &&
                        job['jobDescription'].isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Job Description',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          job['jobDescription'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Apply button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _appliedJobIds.contains(job['id'])
                      ? null
                      : () {
                          Navigator.pop(context);
                          _applyForJob(job);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _appliedJobIds.contains(job['id'])
                        ? Colors.grey.shade300
                        : primaryBlue,
                    foregroundColor: _appliedJobIds.contains(job['id'])
                        ? Colors.grey.shade600
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _appliedJobIds.contains(job['id'])
                        ? 'Already Applied'
                        : 'Apply Now',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyForJob(Map<String, dynamic> job) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to apply for jobs'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show initial message about video ad
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Free apply available after watching a short video.'),
          backgroundColor: Color(0xFF007BFF),
          duration: Duration(seconds: 2),
        ),
      );

      // Wait a moment for the message to be visible
      await Future.delayed(const Duration(milliseconds: 500));

      // Show video ad
      final adCompleted = await VideoAdService.showVideoAd(context);

      if (!adCompleted) {
        // User closed ad early - show warning
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Application Not Submitted'),
              content: const Text('The job will not be applied.'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Ad completed successfully - proceed with application
      debugPrint('🚀 Starting job application process...');
      debugPrint('📋 Job ID: ${job['id']}');
      debugPrint('👤 Candidate Email: ${user.email}');
      debugPrint('🎯 Storage: candidates/{userId}/applications subcollection');

      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
            ),
          ),
        );
      }

      // Use our new JobApplicationService to apply for the job
      final applicationId = await JobApplicationService.applyForJob(
        jobId: job['id'],
        jobTitle: job['jobTitle'],
        companyName: job['companyName'],
        employerId: job['employerId'] ?? '',
        additionalData: {
          'location': job['location'],
          'department': job['jobCategory'] ?? job['department'],
          'designation': job['designation'],
          'jobType': job['jobType'],
          'salary': job['salaryRange'],
          'jobDescription': job['jobDescription'],
          'experienceRequired': job['experienceRequired'],
          'candidateEmail': user.email,
          'candidateName': _candidateName,
          'applicationSource': 'mobile_app',
          'deviceInfo': 'flutter_mobile',
          'industryType': job['industryType'],
          'jobCategory': job['jobCategory'],
        },
      );

      if (applicationId != null) {
        debugPrint('✅ Application stored with ID: $applicationId');
        debugPrint(
          '📍 Location: candidates/${user.uid}/applications/$applicationId',
        );

        // Update local state
        if (mounted) {
          setState(() {
            _appliedJobIds.add(job['id']);
          });
        }

        // Hide loading
        if (mounted) {
          Navigator.pop(context);
        }

        // Show success message with ad completion bonus
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Success!')),
                ],
              ),
              content: const Text(
                'Job applied successfully. Apply more jobs to watch more ads.',
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        // Hide loading
        if (mounted) {
          Navigator.pop(context);
        }

        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to apply for job. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error in job application: $e');

      // Hide loading if it's showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying for job: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // REMOVED: Old helper methods that are no longer needed
  // The JobApplicationService now handles all application logic
  // Applications should ONLY be stored in job_applications collection

  // REMOVED: All helper methods for candidate analytics
  // These methods were creating documents in candidates collection
  // Applications should ONLY be stored in job_applications collection

  void _logout() async {
    try {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
    }
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentBottomNavIndex == index;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Expanded(
      child: InkWell(
        onTap: () {
          // DEBUG: Add logging to track navigation
          debugPrint('🔍 Bottom nav tapped: $label (index: $index)');
          debugPrint('🔍 Current index: $_currentBottomNavIndex');

          if (mounted) {
            final previousIndex = _currentBottomNavIndex;

            // DEBUG: Log state change
            debugPrint('🔄 Changing from index $previousIndex to $index');

            setState(() {
              _currentBottomNavIndex = index;
            });

            // DEBUG: Confirm state change
            debugPrint(
              '✅ State updated: _currentBottomNavIndex = $_currentBottomNavIndex',
            );

            // Refresh data when switching tabs
            if (previousIndex != index) {
              if (index == 0) {
                debugPrint('🏠 Switching to home tab');
                _refreshJobCategoriesIfNeeded();
                _loadCandidateProfile();
              } else if (index == 1) {
                debugPrint(
                  '👤 Switching to profile tab - should show profile overview',
                );
                _loadCandidateProfile();
              }
            }
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
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
                size: isSmallScreen ? 22 : 26,
                color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
              ),
              SizedBox(height: isSmallScreen ? 2 : 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 10 : 12,
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryBlue, Color(0xFF0056CC)],
            ),
          ),
        ),
        title: Container(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All Job Open',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 18 : 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                width: double.infinity,
                child: Text(
                  _getWelcomeMessage(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 11 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.visible,
                  maxLines: 2,
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _showLogoutConfirmationDialog();
            },
            icon: const Icon(Icons.logout, color: Colors.white, size: 24),
            tooltip: 'Logout',
          ),
        ],
        toolbarHeight: isSmallScreen ? 80 : 90,
      ),
      body: Stack(
        children: [
          // Main content with proper bottom padding for navigation
          Positioned.fill(
            child: Builder(
              builder: (context) {
                // DEBUG: Log which page is being shown
                debugPrint(
                  '🔍 Building main content for index: $_currentBottomNavIndex',
                );

                if (_currentBottomNavIndex == 0) {
                  debugPrint('🏠 Showing home page');
                  return _buildHomePage();
                } else {
                  debugPrint('👤 Showing profile page (overview, not edit)');
                  return _buildProfilePage();
                }
              },
            ),
          ),

          // Bottom navigation - always fixed at bottom
          Positioned(
            left: isSmallScreen ? 20 : 40,
            right: isSmallScreen ? 20 : 40,
            bottom: 20,
            child: Container(
              height: isSmallScreen ? 60 : 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(isSmallScreen ? 30 : 35),
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
                    icon: Icons.home_rounded,
                    label: 'Home',
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
    );
  }

  void _showPremiumUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => const PremiumUpgradeDialog(),
    );
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _logout(); // Perform logout
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}
