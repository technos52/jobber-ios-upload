import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'edit_profile_screen.dart';
import 'my_applications_screen.dart';
import 'my_resume_screen.dart';
import 'help_support_screen.dart';
import 'about_us_screen.dart';
import 'premium_upgrade_dialog.dart';
import 'welcome_screen.dart';

class CandidateDashboardScreen extends StatefulWidget {
  const CandidateDashboardScreen({super.key});

  @override
  State<CandidateDashboardScreen> createState() =>
      _CandidateDashboardScreenState();
}

class _CandidateDashboardScreenState extends State<CandidateDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;

  String _userName = 'User';
  int _currentBottomNavIndex = 0;

  static const primaryBlue = Color(0xFF007BFF);

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Company Jobs', 'icon': Icons.business},
    {'name': 'Bank/NBFC Jobs', 'icon': Icons.account_balance},
    {'name': 'School Jobs', 'icon': Icons.school},
    {'name': 'Hospital Jobs', 'icon': Icons.local_hospital},
    {'name': 'Hotel/Bar Jobs', 'icon': Icons.hotel},
    {'name': 'Govt Jobs Info', 'icon': Icons.account_balance_wallet},
    {'name': 'Mall/Shopkeeper Jobs', 'icon': Icons.shopping_bag},
  ];

  // Sample job data
  final List<Map<String, dynamic>> _sampleJobs = [
    {
      'id': '1',
      'title': 'Software Developer',
      'companyName': 'Tech Solutions Inc',
      'location': 'Mumbai, Maharashtra',
      'salary': '₹8-12 LPA',
      'jobCategory': 'company',
      'postedDate': '2 days ago',
      'description': 'Looking for experienced Flutter developers...',
      'requirements': 'Flutter, Dart, Firebase experience required',
    },
    {
      'id': '2',
      'title': 'Bank Manager',
      'companyName': 'State Bank of India',
      'location': 'Delhi, India',
      'salary': '₹6-10 LPA',
      'jobCategory': 'banking',
      'postedDate': '1 day ago',
      'description': 'Managing branch operations and customer relations...',
      'requirements': 'MBA in Finance, 5+ years banking experience',
    },
    {
      'id': '3',
      'title': 'Primary Teacher',
      'companyName': 'Delhi Public School',
      'location': 'Bangalore, Karnataka',
      'salary': '₹4-6 LPA',
      'jobCategory': 'education',
      'postedDate': '3 days ago',
      'description': 'Teaching primary school students...',
      'requirements': 'B.Ed degree, experience with children',
    },
    {
      'id': '4',
      'title': 'Staff Nurse',
      'companyName': 'Apollo Hospital',
      'location': 'Chennai, Tamil Nadu',
      'salary': '₹3-5 LPA',
      'jobCategory': 'healthcare',
      'postedDate': '1 day ago',
      'description': 'Providing patient care and medical assistance...',
      'requirements': 'Nursing degree, valid license',
    },
    {
      'id': '5',
      'title': 'Hotel Manager',
      'companyName': 'Taj Hotels',
      'location': 'Goa, India',
      'salary': '₹5-8 LPA',
      'jobCategory': 'hospitality',
      'postedDate': '4 days ago',
      'description': 'Managing hotel operations and guest services...',
      'requirements': 'Hotel management degree, leadership skills',
    },
    {
      'id': '6',
      'title': 'Government Officer',
      'companyName': 'Ministry of Finance',
      'location': 'New Delhi, India',
      'salary': '₹7-12 LPA',
      'jobCategory': 'government',
      'postedDate': '5 days ago',
      'description': 'Administrative duties in government department...',
      'requirements': 'Graduate degree, competitive exam cleared',
    },
    {
      'id': '7',
      'title': 'Store Manager',
      'companyName': 'Reliance Retail',
      'location': 'Pune, Maharashtra',
      'salary': '₹4-7 LPA',
      'jobCategory': 'retail',
      'postedDate': '2 days ago',
      'description': 'Managing retail store operations...',
      'requirements': 'Retail experience, management skills',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final candidateDoc = await FirebaseFirestore.instance
            .collection('candidates')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (candidateDoc.docs.isNotEmpty) {
          final data = candidateDoc.docs.first.data();
          if (mounted) {
            setState(() {
              _userName = data['fullName'] ?? 'User';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildProfileMenu() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF9FAFB),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryBlue, Color(0xFF0056CC)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? '',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          _buildProfileMenuItem(
            icon: Icons.workspace_premium_rounded,
            title: 'Upgrade to Premium',
            onTap: () async {
              await showDialog(
                context: context,
                builder: (context) => const PremiumUpgradeDialog(),
              );
            },
          ),
          _buildProfileMenuItem(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
            },
          ),
          _buildProfileMenuItem(
            icon: Icons.work_outline_rounded,
            title: 'My Applications',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyApplicationsScreen(),
                ),
              );
            },
          ),
          _buildProfileMenuItem(
            icon: Icons.description_outlined,
            title: 'My Resume',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyResumeScreen()),
              );
            },
          ),
          _buildProfileMenuItem(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpSupportScreen(),
                ),
              );
            },
          ),
          _buildProfileMenuItem(
            icon: Icons.info_outline_rounded,
            title: 'About Us',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutUsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (iconColor ?? primaryBlue).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor ?? primaryBlue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor ?? const Color(0xFF1F2937),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFF9CA3AF),
                size: 24,
              ),
            ],
          ),
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
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentBottomNavIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    return Column(
      children: [
        // Tab Bar
        Container(
          color: Colors.white,
          alignment: Alignment.centerLeft,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: primaryBlue,
            indicatorWeight: 3,
            labelColor: primaryBlue,
            unselectedLabelColor: const Color(0xFF6B7280),
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: _categories.map((category) {
              return Tab(
                icon: Icon(category['icon'], size: 22),
                text: category['name'],
              );
            }).toList(),
          ),
        ),
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _categories.map((category) {
              return _buildJobsList(category['name']);
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default back button behavior
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Show message when back button is pressed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'You are on the main screen. Use the logout button to exit.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: primaryBlue,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: Scaffold(
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
          surfaceTintColor: Colors.transparent,
          elevation: 4,
          shadowColor: primaryBlue.withValues(alpha: 0.2),
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AlljobOpen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'Welcome, $_userName ${_currentBottomNavIndex == 1 ? "(Profile)" : ""}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            if (_currentBottomNavIndex == 0)
              IconButton(
                tooltip: 'Upgrade to Premium',
                icon: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                ),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => const PremiumUpgradeDialog(),
                  );
                },
              )
            else
              IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
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
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryBlue,
                          ),
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
            _currentBottomNavIndex == 0
                ? _buildHomePage()
                : Container(
                    padding: const EdgeInsets.only(bottom: 110),
                    child: _buildProfileMenu(),
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
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
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
      ),
    );
  }

  Widget _buildJobsList(String categoryName) {
    // Map category names to job categories
    final categoryMapping = {
      'Company Jobs': 'company',
      'Bank/NBFC Jobs': 'banking',
      'School Jobs': 'education',
      'Hospital Jobs': 'healthcare',
      'Hotel/Bar Jobs': 'hospitality',
      'Govt Jobs Info': 'government',
      'Mall/Shopkeeper Jobs': 'retail',
    };

    final categoryKey = categoryMapping[categoryName];

    // Filter jobs by category
    List<Map<String, dynamic>> filteredJobs = _sampleJobs;
    if (categoryKey != null) {
      filteredJobs = _sampleJobs.where((job) {
        return job['jobCategory'] == categoryKey;
      }).toList();
    }

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase().trim();
    if (searchQuery.isNotEmpty) {
      filteredJobs = filteredJobs.where((job) {
        final title = (job['title'] ?? '').toString().toLowerCase();
        return title.contains(searchQuery);
      }).toList();
    }

    if (filteredJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No jobs found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or check other categories',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredJobs.length,
      itemBuilder: (context, index) {
        final job = filteredJobs[index];
        return _buildJobCard(job);
      },
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showJobDetailsDialog(job),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with company and date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      job['companyName'] ?? 'Company',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      job['postedDate'] ?? 'Recently',
                      style: TextStyle(
                        fontSize: 11,
                        color: primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Job title
              Text(
                job['title'] ?? 'Job Title',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),

              // Job details
              Row(
                children: [
                  if (job['salary'] != null) ...[
                    Icon(
                      Icons.currency_rupee,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      job['salary'].toString(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job['location'] ?? 'Location',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Apply button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _applyForJob(job),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Apply Now',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJobDetailsDialog(Map<String, dynamic> job) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          job['title'] ?? 'Job Title',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Company info
                  Text(
                    job['companyName'] ?? 'Company',
                    style: TextStyle(
                      fontSize: 16,
                      color: primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Location and salary
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        job['location'] ?? 'Location',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      if (job['salary'] != null) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.currency_rupee,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          job['salary'].toString(),
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  const Text(
                    'Job Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job['description'] ?? 'No description available.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Requirements
                  const Text(
                    'Requirements',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job['requirements'] ?? 'No specific requirements listed.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _applyForJob(job);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply Now',
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
          ),
        ),
      ),
    );
  }

  void _applyForJob(Map<String, dynamic> job) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied for ${job['title']} at ${job['companyName']}'),
        backgroundColor: primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
