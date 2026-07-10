import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_resume_screen.dart';

class MyResumeScreen extends StatefulWidget {
  const MyResumeScreen({super.key});

  @override
  State<MyResumeScreen> createState() => _MyResumeScreenState();
}

class _MyResumeScreenState extends State<MyResumeScreen> {
  static const primaryBlue = Color(0xFF007BFF);
  bool _isLoading = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
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
          setState(() {
            _userData = candidateDoc.docs.first.data();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
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
          'My Resume',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        // Edit button hidden as requested
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.edit_outlined, color: primaryBlue),
        //     tooltip: 'Edit Resume',
        //     onPressed: () {
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(
        //           builder: (context) => const EditResumeScreen(),
        //         ),
        //       ).then((_) {
        //         // Refresh data when coming back from edit screen
        //         _loadUserData();
        //       });
        //     },
        //   ),
        //   const SizedBox(width: 8),
        // ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
            )
          : _userData == null
          ? const Center(child: Text('No data available'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryBlue,
                          primaryBlue.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userData!['fullName'] ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _userData!['designation'] ?? 'Job Seeker',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Contact Information
                  _buildSection(
                    'Contact Information',
                    Icons.contact_page_outlined,
                    [
                      _buildInfoRow(
                        'Email',
                        _userData!['email'] ?? 'N/A',
                        Icons.email_outlined,
                      ),
                      _buildInfoRow(
                        'Mobile',
                        _userData!['mobileNumber'] ?? 'N/A',
                        Icons.phone_outlined,
                      ),
                      if (_userData!['state'] != null)
                        _buildInfoRow(
                          'Location',
                          '${_userData!['district']}, ${_userData!['state']}',
                          Icons.location_on_outlined,
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Personal Details
                  _buildSection('Personal Details', Icons.person_outline, [
                    if (_userData!['title'] != null)
                      _buildInfoRow(
                        'Title',
                        _userData!['title'],
                        Icons.badge_outlined,
                      ),
                    if (_userData!['gender'] != null)
                      _buildInfoRow('Gender', _userData!['gender'], Icons.wc),
                    if (_userData!['age'] != null)
                      _buildInfoRow(
                        'Age',
                        '${_userData!['age']} years',
                        Icons.cake_outlined,
                      ),
                    if (_userData!['maritalStatus'] != null)
                      _buildInfoRow(
                        'Marital Status',
                        _userData!['maritalStatus'],
                        Icons.favorite_outline,
                      ),
                  ]),

                  const SizedBox(height: 20),

                  // Professional Details
                  _buildSection('Professional Details', Icons.work_outline, [
                    if (_userData!['qualification'] != null)
                      _buildInfoRow(
                        'Qualification',
                        _userData!['qualification'],
                        Icons.school_outlined,
                      ),
                    if (_userData!['companyName'] != null)
                      _buildInfoRow(
                        'Company',
                        _userData!['companyName'],
                        Icons.business_outlined,
                      ),
                    if (_userData!['department'] != null)
                      _buildInfoRow(
                        'Department',
                        _userData!['department'],
                        Icons.category_outlined,
                      ),
                    if (_userData!['experienceYears'] != null ||
                        _userData!['experienceMonths'] != null)
                      _buildInfoRow(
                        'Experience',
                        '${_userData!['experienceYears'] ?? 0} years ${_userData!['experienceMonths'] ?? 0} months',
                        Icons.timeline_outlined,
                      ),
                    if (_userData!['currentlyWorking'] != null)
                      _buildInfoRow(
                        'Currently Working',
                        _getBooleanValue(_userData!['currentlyWorking'])
                            ? 'Yes'
                            : 'No',
                        Icons.work_history_outlined,
                      ),
                    if (_userData!['noticePeriod'] != null &&
                        _getBooleanValue(_userData!['currentlyWorking']) ==
                            true)
                      _buildInfoRow(
                        'Notice Period',
                        '${_userData!['noticePeriod']} days',
                        Icons.event_outlined,
                      ),
                  ]),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryBlue, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to safely convert String/boolean values to boolean
  bool _getBooleanValue(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true' ||
          value == '1' ||
          value.toLowerCase() == 'yes';
    }
    return false;
  }
}
