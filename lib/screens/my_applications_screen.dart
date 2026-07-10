import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/job_application_service.dart';
import '../models/job_application.dart';

class MyApplicationsScreen extends StatelessWidget {
  const MyApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Applications',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: JobApplicationService.getUserApplications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007BFF)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading applications',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.work_off,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Applications Yet',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start applying for jobs to see them here',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final applications = snapshot.data!.docs
              .map((doc) => JobApplication.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: applications.length,
            itemBuilder: (context, index) {
              final application = applications[index];
              return ApplicationCard(application: application);
            },
          );
        },
      ),
    );
  }
}

class ApplicationCard extends StatelessWidget {
  final JobApplication application;
  static const primaryBlue = Color(0xFF007BFF);

  const ApplicationCard({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with job title and status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.jobTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        application.companyName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                // Only show status chip if not pending
                if (application.status.toLowerCase() != 'pending')
                  _buildStatusChip(application.status),
              ],
            ),

            const SizedBox(height: 16),

            // Application date
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Applied ${_formatDate(application.appliedAt)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCompleteJobDetails(context, application),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text(
                  'View Complete Job Details',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange[50]!;
        textColor = Colors.orange[700]!;
        icon = Icons.schedule;
        break;
      case 'reviewed':
      case 'under review':
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        icon = Icons.visibility;
        break;
      case 'accepted':
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        icon = Icons.cancel;
        break;
      default:
        backgroundColor = Colors.grey[50]!;
        textColor = Colors.grey[700]!;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _showCompleteJobDetails(
    BuildContext context,
    JobApplication application,
  ) async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
        ),
      ),
    );

    try {
      // Fetch complete job details from jobs collection
      final jobDoc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(application.jobId)
          .get();

      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      if (jobDoc.exists && context.mounted) {
        final jobData = jobDoc.data() as Map<String, dynamic>;
        _showJobDetailsModal(context, application, jobData);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job details not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading job details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showJobDetailsModal(
    BuildContext context,
    JobApplication application,
    Map<String, dynamic> jobData,
  ) {
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
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Job Application Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800],
                          ),
                        ),
                        // Only show status chip if not pending
                        if (application.status.toLowerCase() != 'pending') ...[
                          const SizedBox(height: 4),
                          _buildStatusChip(application.status),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Job Title and Company
                    _buildDetailSection('Job Information', Icons.work_outline, [
                      _buildDetailRow(
                        'Job Title',
                        jobData['jobTitle'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Company',
                        jobData['companyName'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Job Category',
                        jobData['jobCategory'] ?? 'N/A',
                      ),
                      _buildDetailRow('Job Type', jobData['jobType'] ?? 'N/A'),
                      _buildDetailRow(
                        'Experience Required',
                        jobData['experienceRequired'] ?? 'N/A',
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Location and Salary
                    _buildDetailSection(
                      'Location & Compensation',
                      Icons.location_on_outlined,
                      [
                        _buildDetailRow(
                          'Location',
                          _getLocationDisplay(jobData),
                        ),
                        _buildDetailRow(
                          'Salary Range',
                          jobData['salaryRange'] ?? 'Not specified',
                        ),
                        _buildDetailRow(
                          'Work Mode',
                          jobData['workMode'] ?? 'N/A',
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Job Description
                    if (jobData['jobDescription'] != null &&
                        jobData['jobDescription'].toString().isNotEmpty)
                      _buildDetailSection(
                        'Job Description',
                        Icons.description_outlined,
                        [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Text(
                              jobData['jobDescription'],
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryBlue, size: 22),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method to get location display handling both old and new data formats
  String _getLocationDisplay(Map<String, dynamic> jobData) {
    // Try new format first (single location field)
    final location = jobData['location'];
    if (location != null && location.toString().trim().isNotEmpty) {
      return location.toString().trim();
    }

    // Try old format (district and state fields)
    final district = jobData['district'];
    final state = jobData['state'];
    if (district != null && state != null) {
      final districtStr = district.toString().trim();
      final stateStr = state.toString().trim();
      if (districtStr.isNotEmpty && stateStr.isNotEmpty) {
        return '$districtStr, $stateStr';
      }
    }

    // Try individual fields as fallback
    if (district != null && district.toString().trim().isNotEmpty) {
      return district.toString().trim();
    }
    if (state != null && state.toString().trim().isNotEmpty) {
      return state.toString().trim();
    }

    return 'Location not specified';
  }
}
